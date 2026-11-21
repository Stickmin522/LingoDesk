//! A session becomes a history record only when the user saves it.
use super::*;

pub(super) fn directory(history: &str) -> PathBuf {
    Path::new(history).join(".drafts")
}

// Called with ENGINE locked and only when no current session owns these files.
pub(super) fn clean_orphans(history: &str) -> Result<(), String> {
    match fs::remove_dir_all(directory(history)) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(_) => Err("删除失败".into()),
    }
}

pub(super) fn read(id: &str) -> Result<Option<View>, String> {
    let engine = ENGINE.lock().map_err(|_| "状态异常")?;
    let Some(engine) = engine.as_ref() else {
        return Ok(None);
    };
    let view = engine.view.lock().map_err(|_| "字幕状态读取失败")?;
    Ok((view.id == id && view.pending_save).then(|| view.clone()))
}

pub(super) fn commit(req: &Value) -> Result<Value, String> {
    let id = req["id"]
        .as_str()
        .filter(|id| valid_id(id))
        .ok_or("无效记录 ID")?;
    let history = req["directory"].as_str().ok_or("缺少目录")?;
    let engine = ENGINE.lock().map_err(|_| "状态异常")?;
    let engine = engine.as_ref().ok_or("记录不存在")?;
    let _writer = FILE_WRITE_LOCK.lock().map_err(|_| "记录保存状态异常")?;
    let mut view = engine.view.lock().map_err(|_| "字幕状态读取失败")?;
    if view.id != id {
        return Err("记录不存在".into());
    }
    if view.phase != "ended" {
        return Err("请先停止录音".into());
    }
    if view.pending_save {
        save_to_history(&mut view, history)?;
    }
    Ok(json!(caption_edits::render(&view)))
}

fn save_to_history(view: &mut View, history: &str) -> Result<(), String> {
    let filename = format!("{}.wav", view.id);
    let staged = directory(history).join(&filename);
    let destination = Path::new(history).join(&filename);
    let mut saved = view.clone();
    saved.pending_save = false;
    saved.audio_path = destination.to_string_lossy().into();
    // Both paths are in the same app directory. Keep the staged file available
    // until the history entry is written so a failed save can be retried.
    fs::hard_link(&staged, &destination).map_err(|_| "保存录音失败")?;
    if let Err(error) = write_record(&saved, history) {
        let _ = fs::remove_file(destination);
        return Err(error);
    }
    *view = saved;
    let _ = fs::remove_file(staged);
    Ok(())
}

pub(super) fn discard(req: &Value) -> Result<Value, String> {
    let id = req["id"].as_str();
    let mut engine = ENGINE.lock().map_err(|_| "状态异常")?;
    let discard = if let Some(current) = engine.as_ref() {
        let view = current.view.lock().map_err(|_| "字幕状态读取失败")?;
        view.pending_save
            && req["cleanupOnly"] != true
            && ["ended", "stopping"].contains(&view.phase.as_str())
            && id.is_none_or(|id| id == view.id)
    } else {
        false
    };
    if discard {
        // The worker may still own the WAV during finalization. Its last Wave
        // reference removes the temporary file without touching saved recordings.
        *engine = None;
        if let Ok(mut last) = LAST.lock() {
            *last = View::idle();
        }
    } else if engine.is_none() && id.is_none() {
        if let Some(history) = req["directory"].as_str() {
            clean_orphans(history)?;
        }
    }
    Ok(json!({"ok":true, "discarded":discard}))
}

#[cfg(test)]
mod tests {
    use super::*;

    struct History(PathBuf);
    impl History {
        fn new() -> Self {
            let path = std::env::temp_dir().join(text_translation::new_key());
            fs::create_dir_all(path.join(".drafts")).unwrap();
            Self(path)
        }
        fn path(&self) -> &str {
            self.0.to_str().unwrap()
        }
    }
    impl Drop for History {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn only_explicit_save_publishes_audio_metadata_and_edited_captions() {
        let history = History::new();
        let staged = directory(history.path()).join("371.wav");
        let mut wave = Wave::create(staged.clone(), true).unwrap();
        wave.write(&[42, 0]).unwrap();
        wave.header().unwrap();
        let mut view = View {
            id: "371".into(),
            title: "My recording".into(),
            phase: "ended".into(),
            pending_save: true,
            audio_path: staged.to_string_lossy().into(),
            segments: vec![Segment {
                text: "原文".into(),
                translation: "Translation".into(),
                ..Segment::default()
            }],
            ..View::default()
        };
        // The same write entry point serves rename, digest and caption edits.
        write_record(&view, history.path()).unwrap();
        assert!(load(history.path(), "371").is_err());
        assert!(!history.0.join("371.wav").exists());
        // A failed metadata write must leave the staged WAV and pending view retryable.
        fs::create_dir(history.0.join("371.json")).unwrap();
        assert!(save_to_history(&mut view, history.path()).is_err());
        assert!(view.pending_save && staged.is_file());
        assert!(!history.0.join("371.wav").exists());
        fs::remove_dir(history.0.join("371.json")).unwrap();
        save_to_history(&mut view, history.path()).unwrap();
        drop(wave);
        let saved = load(history.path(), "371").unwrap();
        assert!(!saved.pending_save);
        assert_eq!(saved.title, "My recording");
        assert_eq!(saved.segments[0].translation, "Translation");
        assert_eq!(&fs::read(&saved.audio_path).unwrap()[44..], &[42, 0]);
        assert!(!staged.exists());
    }

    #[test]
    fn discarding_wave_and_cold_start_cleanup_leave_existing_history_untouched() {
        let history = History::new();
        let saved_audio = history.0.join("105.wav");
        fs::write(&saved_audio, b"saved audio").unwrap();
        let staged = directory(history.path()).join("106.wav");
        let wave = Wave::create(staged.clone(), true).unwrap();
        drop(wave);
        assert!(!staged.exists());
        // A force-stop skips destructors. The next launch prunes any orphaned drafts.
        fs::write(&staged, b"orphaned audio").unwrap();
        clean_orphans(history.path()).unwrap();
        assert!(!staged.exists());
        assert_eq!(fs::read(&saved_audio).unwrap(), b"saved audio");
    }

    #[test]
    fn live_txt_includes_visible_provisional_caption_without_duplicating_final_text() {
        let segment = Segment {
            text: "First sentence".into(),
            translation: "第一句".into(),
            ..Segment::default()
        };
        let tail = Segment {
            text: "Unfinished sentence".into(),
            translation: "正在翻译".into(),
            ..Segment::default()
        };
        let view = View {
            pending_save: true,
            phase: "recording".into(),
            segments: vec![segment.clone()],
            captions: vec![
                captions::Caption {
                    segment,
                    ..captions::Caption::default()
                },
                captions::Caption {
                    segment: tail,
                    provisional: true,
                    ..captions::Caption::default()
                },
            ],
            ..View::default()
        };
        let result = transcript(&view);
        assert_eq!(result.matches("First sentence").count(), 1);
        assert!(result.contains("Unfinished sentence\n正在翻译"));
    }
}
