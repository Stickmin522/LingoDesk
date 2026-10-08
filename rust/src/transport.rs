//! Network reconnection never owns the lifetime of local recording.
use super::*;
use std::collections::VecDeque;

fn connect_job(c: Config) -> Receiver<Result<Socket, String>> {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        if let Err(mpsc::SendError(Ok(mut socket))) = tx.send(open(&c)) {
            // The user stopped/paused while HTTP or TLS was still connecting.
            let _ = socket.send(Message::Text("{\"type\":\"session.stop\"}".into()));
            let _ = socket.close(None);
        }
    });
    rx
}

pub(super) fn run(
    c: Config,
    ctrl: Receiver<Control>,
    frames: Receiver<Frame>,
    view: Arc<Mutex<View>>,
    wave: Arc<Mutex<Wave>>,
) {
    let mut timeline = Timeline::default();
    let mut socket: Option<Socket> = None;
    let mut connecting: Option<Receiver<Result<Socket, String>>> = None;
    let mut backlog = VecDeque::new();
    let mut next_attempt = Instant::now();
    let mut retry = 0u32;
    let mut paused = false;
    let mut last_save = Instant::now();
    loop {
        if let Ok(command) = ctrl.try_recv() {
            match command {
                Control::Pause => {
                    phase(&view, "pausing");
                    connecting = None;
                    while let Ok(frame) = frames.try_recv() {
                        backlog.push_back(frame);
                    }
                    if let Some(s) = socket.as_mut() {
                        while let Some(frame) = backlog.pop_front() {
                            let _ = s.send(Message::Binary(frame.bytes.into()));
                        }
                    }
                    backlog.clear();
                    finish_stream(&mut socket, &view, &mut timeline);
                    paused = true;
                    phase(&view, "paused");
                    let _ = save(&view, &c.directory);
                }
                Control::Resume => {
                    paused = false;
                    retry = 0;
                    next_attempt = Instant::now();
                    backlog.clear();
                    mutate(&view, |v| {
                        v.phase = "recording".into();
                        v.connection = "connecting".into();
                        v.error.clear();
                    });
                }
                Control::Stop => {
                    phase(&view, "stopping");
                    drop(connecting.take());
                    while let Ok(frame) = frames.try_recv() {
                        backlog.push_back(frame);
                    }
                    if let Some(s) = socket.as_mut() {
                        while let Some(frame) = backlog.pop_front() {
                            let _ = s.send(Message::Binary(frame.bytes.into()));
                        }
                    }
                    finish_stream(&mut socket, &view, &mut timeline);
                    break;
                }
            }
        }
        if !paused {
            for _ in 0..100 {
                match frames.try_recv() {
                    Ok(frame) => backlog.push_back(frame),
                    Err(_) => break,
                }
            }
            while backlog.len() > 100 {
                backlog.pop_front();
                mutate(&view, |v| v.dropped_frames += 1);
            }
            if socket.is_none() && connecting.is_none() && Instant::now() >= next_attempt {
                mutate(&view, |v| {
                    v.connection = if retry == 0 {
                        "connecting"
                    } else {
                        "reconnecting"
                    }
                    .into()
                });
                connecting = Some(connect_job(c.clone()));
            }
            let result = connecting.as_ref().and_then(|rx| rx.try_recv().ok());
            if let Some(result) = result {
                connecting = None;
                match result {
                    Ok(s) => {
                        timeline.run += 1;
                        timeline.offset = backlog
                            .front()
                            .map(|f: &Frame| f.start_ms)
                            .unwrap_or_else(|| view.lock().map(|v| v.duration_ms).unwrap_or(0));
                        socket = Some(s);
                        retry = 0;
                        mutate(&view, |v| {
                            v.connection = "connected".into();
                            v.structured_preview = false;
                            v.error.clear();
                        });
                    }
                    Err(e) => {
                        retry = retry.saturating_add(1);
                        next_attempt =
                            Instant::now() + Duration::from_secs((2u64.pow(retry.min(4))).min(30));
                        mutate(&view, |v| {
                            v.connection = "reconnecting".into();
                            v.warning = format!(
                                "{e}。本机录音继续，正在自动重连；连接中断期间字幕可能缺失。"
                            );
                        });
                    }
                }
            }
            let mut lost = None;
            if let Some(s) = socket.as_mut() {
                for _ in 0..20 {
                    let Some(frame) = backlog.pop_front() else {
                        break;
                    };
                    if let Err(e) = s.send(Message::Binary(frame.bytes.into())) {
                        if matches!(e, tungstenite::Error::WriteBufferFull(_)) {
                            mutate(&view, |v| {
                                v.dropped_frames += 1;
                                v.warning = "网络拥塞，字幕可能缺失；本机录音继续保存".into();
                            });
                        } else if !matches!(&e,tungstenite::Error::Io(e) if e.kind()==std::io::ErrorKind::WouldBlock)
                        {
                            lost = Some("实时上传中断".to_owned());
                            break;
                        }
                    }
                }
                let _ = s.flush();
                if lost.is_none() {
                    match drain(s, &view, &mut timeline) {
                        Ok(true) => lost = Some("实时节点结束了连接".into()),
                        Err(e) => lost = Some(e),
                        _ => {}
                    }
                }
            }
            if let Some(reason) = lost {
                socket = None;
                next_attempt = Instant::now() + Duration::from_secs(1);
                retry = 1;
                mutate(&view, |v| {
                    v.connection = "reconnecting".into();
                    v.warning = format!("{reason}。本机录音继续，正在自动重连。");
                });
            }
        }
        if last_save.elapsed() > Duration::from_secs(3) {
            if let Err(e) = save(&view, &c.directory) {
                mutate(&view, |v| v.warning = e)
            }
            last_save = Instant::now();
        }
        thread::sleep(Duration::from_millis(5));
    }
    if let Ok(mut w) = wave.lock() {
        if let Err(e) = w.header() {
            mutate(&view, |v| v.error = e)
        }
    }
    mutate(&view, |v| {
        v.phase = "ended".into();
        v.connection = "closed".into();
    });
    if let Err(e) = save(&view, &c.directory) {
        mutate(&view, |v| v.error = e)
    }
    if let Ok(v) = view.lock() {
        if let Ok(mut last) = LAST.lock() {
            *last = v.clone();
        }
    }
}
