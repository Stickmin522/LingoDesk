//! Display rows follow the supplied web client's append-only caption model.
//! Final/export segments remain separate from speculative streaming text.
use super::{Segment, View, string};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn flat_stream_keeps_translation_across_empty_and_source_corrections() {
        let mut v = View::idle();
        transcript_preview(&mut v, &json!({"text":"あなたは何歳"}), 1);
        translation_preview(
            &mut v,
            &json!({"sourceText":"あなたは何歳","text":"你是几岁"}),
            1,
        );
        let id = v.captions[0].segment.id.clone();
        transcript_preview(&mut v, &json!({"text":"あなたは何歳ですか"}), 1);
        transcript_preview(&mut v, &json!({"text":""}), 1);
        translation_preview(&mut v, &json!({"text":""}), 1);
        assert_eq!(v.captions.len(), 1);
        assert_eq!(v.captions[0].segment.id, id);
        assert_eq!(v.captions[0].segment.translation, "你是几岁");
        translation_preview(
            &mut v,
            &json!({"sourceText":"あなたは何歳ですか","text":"你多大了？"}),
            1,
        );
        assert_eq!(v.captions[0].segment.translation, "你多大了？");
    }
    #[test]
    fn paragraph_and_tail_remain_separate_and_aggregate_cannot_overwrite() {
        let mut v = View::idle();
        transcript_preview(
            &mut v,
            &json!({"paragraphs":[{"pieces":[{"text":"今日は晴れです。"}],"translation":"今天是晴天。"}],"tail":"明日は","tailTranslation":"明天"}),
            1,
        );
        assert_eq!(v.captions.len(), 2);
        translation_preview(
            &mut v,
            &json!({"sourceText":"今日は晴れです。明日は","text":"错误的合并译文"}),
            1,
        );
        assert_eq!(v.captions[0].segment.translation, "今天是晴天。");
        assert_eq!(v.captions[1].segment.translation, "明天");
        let id = v.captions[1].segment.id.clone();
        transcript_preview(
            &mut v,
            &json!({"paragraphs":[{"pieces":[{"text":"今日は晴れです。"}]}],"tail":"明日は雨です。","tailTranslation":"明天会下雨。"}),
            1,
        );
        assert_eq!(v.captions[1].segment.id, id);
        assert_eq!(v.captions[1].segment.translation, "明天会下雨。");
        assert_eq!(v.captions[0].segment.translation, "今天是晴天。");
    }
    #[test]
    fn late_final_updates_original_row_and_repeated_speech_appends() {
        let mut v = View::idle();
        transcript_preview(&mut v, &json!({"text":"こんにちは"}), 1);
        translation_preview(&mut v, &json!({"sourceText":"こんにちは","text":"你好"}), 1);
        let mut s = Segment {
            id: "1:first".into(),
            text: "こんにちは".into(),
            start_ms: Some(6000),
            ..Segment::default()
        };
        final_caption(&mut v, &s, "transcript.final", 1);
        assert_eq!(v.captions[0].segment.translation, "你好");
        transcript_preview(&mut v, &json!({"text":"こんにちは"}), 1);
        let next = Segment {
            id: "1:second".into(),
            text: "こんにちは".into(),
            start_ms: Some(1000),
            ..Segment::default()
        };
        final_caption(&mut v, &next, "transcript.final", 1);
        s.translation = "您好。".into();
        final_caption(&mut v, &s, "translation.final", 1);
        assert_eq!(v.captions.len(), 2);
        assert_eq!(v.captions[0].segment_id.as_deref(), Some("1:first"));
        assert_eq!(v.captions[0].segment.translation, "您好。");
        assert_eq!(v.captions[1].segment_id.as_deref(), Some("1:second"));
    }
    #[test]
    fn resume_run_never_reuses_an_unfinished_old_caption() {
        let mut v = View::idle();
        transcript_preview(&mut v, &json!({"text":"same text"}), 1);
        transcript_preview(&mut v, &json!({"text":"same text"}), 2);
        assert_eq!(v.captions.len(), 2);
        assert_ne!(v.captions[0].segment.id, v.captions[1].segment.id);
    }
    #[test]
    fn merged_final_keeps_existing_sentence_boundaries() {
        let mut v = View::idle();
        transcript_preview(
            &mut v,
            &json!({"paragraphs":[{"pieces":[{"text":"一つです。"}],"translation":"这是第一句。"},{"pieces":[{"text":"二つです。"}],"translation":"这是第二句。"}]}),
            1,
        );
        let s = Segment {
            id: "1:combined".into(),
            text: "一つです。二つです。".into(),
            translation: "这是第一句。这是第二句。".into(),
            ..Segment::default()
        };
        final_caption(&mut v, &s, "translation.final", 1);
        assert_eq!(v.captions.len(), 2);
        assert_eq!(v.captions[0].segment.text, "一つです。");
        assert_eq!(v.captions[1].segment.translation, "这是第二句。");
        assert!(
            v.captions
                .iter()
                .all(|r| r.segment_id.as_deref() == Some("1:combined"))
        );
    }
}

#[derive(Clone, Serialize, Deserialize, Default, Debug)]
#[serde(default, rename_all = "camelCase")]
pub struct Caption {
    #[serde(flatten)]
    pub segment: Segment,
    pub segment_id: Option<String>,
    pub provisional: bool,
    pub in_preview: bool,
    pub preview_text: String,
    pub preview_role: String,
    pub source_final: bool,
    pub translation_final: bool,
    pub run: u64,
}
#[derive(Clone)]
struct Preview {
    text: String,
    translation: String,
    speaker: String,
    role: String,
    caption_id: Option<String>,
}
fn normalize(s: &str) -> String {
    s.chars()
        .filter(|c| c.is_alphanumeric())
        .flat_map(char::to_lowercase)
        .collect()
}
fn similarity(a: &str, b: &str) -> f64 {
    let x: Vec<_> = normalize(a).chars().collect();
    let y: Vec<_> = normalize(b).chars().collect();
    if x.is_empty() || y.is_empty() {
        return 0.0;
    }
    if x == y {
        return 2.0;
    }
    let prefix = x.iter().zip(&y).take_while(|(a, b)| a == b).count();
    let len = x.len().min(y.len());
    if prefix < len.min(2) {
        0.0
    } else {
        prefix as f64 / len as f64
    }
}
fn source(row: &Caption) -> &str {
    if row.preview_text.is_empty() {
        &row.segment.text
    } else {
        &row.preview_text
    }
}
fn split_existing(value: &str, previous: &[String], sentence_breaks: bool) -> Option<Vec<String>> {
    if value.is_empty() || previous.len() < 2 {
        return None;
    }
    let normalized = normalize(value);
    let first = normalize(&previous[0]);
    if !first.is_empty()
        && previous.iter().all(|s| !normalize(s).is_empty())
        && normalized.starts_with(&first)
    {
        let mut offsets = vec![0];
        let mut search = first.len();
        for part in &previous[1..] {
            let anchor = normalize(part);
            let Some(offset) = normalized.get(search..).and_then(|s| s.find(&anchor)) else {
                break;
            };
            offsets.push(search + offset);
            search += offset + anchor.len();
        }
        if offsets.len() == previous.len() {
            let mut positions = Vec::new();
            for (byte, c) in value.char_indices() {
                for _ in 0..normalize(&c.to_string()).len() {
                    positions.push(byte);
                }
            }
            return Some(
                offsets
                    .iter()
                    .enumerate()
                    .map(|(i, &offset)| {
                        let start = positions[offset];
                        let end = offsets
                            .get(i + 1)
                            .map(|&n| positions[n])
                            .unwrap_or(value.len());
                        value[start..end].trim().to_owned()
                    })
                    .collect(),
            );
        }
    }
    if sentence_breaks {
        let mut parts = Vec::new();
        let mut start = 0;
        for (i, c) in value.char_indices() {
            if ".!?。！？".contains(c) {
                let end = i + c.len_utf8();
                let part = value[start..end].trim();
                if !part.is_empty() {
                    parts.push(part.to_owned());
                }
                start = end;
            }
        }
        if !value[start..].trim().is_empty() {
            parts.push(value[start..].trim().to_owned());
        }
        if parts.len() == previous.len() {
            return Some(parts);
        }
    }
    None
}
fn merged(
    value: &str,
    rows: &[Caption],
    sentence_breaks: bool,
) -> Option<(Vec<Caption>, Vec<String>)> {
    for start in 0..rows.len().saturating_sub(1) {
        let anchor = normalize(source(&rows[start]));
        if anchor.is_empty() || !normalize(value).starts_with(&anchor) {
            continue;
        }
        let mut found = None;
        for end in start + 2..=rows.len() {
            let group = &rows[start..end];
            let Some(parts) = split_existing(
                value,
                &group
                    .iter()
                    .map(|r| source(r).to_owned())
                    .collect::<Vec<_>>(),
                sentence_breaks,
            ) else {
                break;
            };
            found = Some((group.to_vec(), parts));
        }
        if found.is_some() {
            return found;
        }
    }
    None
}
fn with_preview(v: &mut View) {
    v.preview = v
        .captions
        .iter()
        .filter(|r| r.provisional)
        .map(|r| r.segment.text.as_str())
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("\n");
    v.preview_translation = v
        .captions
        .iter()
        .filter(|r| r.provisional)
        .map(|r| r.segment.translation.as_str())
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("\n");
}
fn new_row(v: &mut View, run: u64) -> Caption {
    v.next_caption_id += 1;
    Caption {
        segment: Segment {
            id: format!("caption-{}", v.next_caption_id),
            ..Segment::default()
        },
        run,
        ..Caption::default()
    }
}
pub fn transcript_preview(v: &mut View, msg: &Value, run: u64) {
    let previous: Vec<_> = v
        .captions
        .iter()
        .filter(|r| r.run == run && (r.in_preview || r.segment_id.is_none()))
        .cloned()
        .collect();
    let mut incoming = Vec::new();
    if let Some(paragraphs) = msg["paragraphs"].as_array() {
        for p in paragraphs {
            let text = p["pieces"]
                .as_array()
                .map(|xs| xs.iter().map(|x| string(&x["text"])).collect::<String>())
                .unwrap_or_default();
            let translation = string(&p["translation"]);
            if !text.is_empty() || !translation.is_empty() {
                incoming.push(Preview {
                    text,
                    translation,
                    speaker: string(&p["speaker"]),
                    role: "paragraph".into(),
                    caption_id: None,
                });
            }
        }
    }
    let tail = string(&msg["tail"]);
    let translated = string(&msg["tailTranslation"]);
    if !tail.is_empty() || !translated.is_empty() {
        incoming.push(Preview {
            text: tail,
            translation: translated,
            speaker: String::new(),
            role: "tail".into(),
            caption_id: None,
        });
    }
    if incoming.is_empty() && !msg["paragraphs"].is_array() {
        let text = if string(&msg["text"]).is_empty() {
            string(&msg["pending"])
        } else {
            string(&msg["text"])
        };
        if !text.is_empty() {
            incoming.push(Preview {
                text,
                translation: String::new(),
                speaker: string(&msg["speaker"]),
                role: "flat".into(),
                caption_id: None,
            });
        }
    }
    v.structured_preview |= msg["paragraphs"].is_array() || msg.get("tailTranslation").is_some();
    let mut expanded = Vec::new();
    for p in &incoming {
        if let Some((group, parts)) = merged(&p.text, &previous, incoming.len() < previous.len()) {
            let translations = split_existing(
                &p.translation,
                &group
                    .iter()
                    .map(|r| r.segment.translation.clone())
                    .collect::<Vec<_>>(),
                true,
            );
            for (i, row) in group.iter().enumerate() {
                expanded.push(Preview {
                    text: parts[i].clone(),
                    translation: translations
                        .as_ref()
                        .map(|t| t[i].clone())
                        .unwrap_or_default(),
                    speaker: if row.segment.speaker.is_empty() {
                        p.speaker.clone()
                    } else {
                        row.segment.speaker.clone()
                    },
                    role: if i + 1 == group.len() {
                        p.role.clone()
                    } else {
                        row.preview_role.clone()
                    },
                    caption_id: Some(row.segment.id.clone()),
                });
            }
        } else {
            expanded.push(p.clone());
        }
    }
    incoming = expanded;
    for r in &mut v.captions {
        r.in_preview = false;
    }
    if incoming.is_empty() {
        return;
    }
    let mut available: std::collections::HashSet<_> =
        previous.iter().map(|r| r.segment.id.clone()).collect();
    let mut cursor = 0;
    for (position, p) in incoming.iter().enumerate() {
        let compatible = |r: &Caption| {
            available.contains(&r.segment.id)
                && (p.speaker.is_empty()
                    || r.segment.speaker.is_empty()
                    || p.speaker == r.segment.speaker)
                && (r.segment_id.is_none()
                    || (p.role != "flat" && similarity(source(r), &p.text) == 2.0))
        };
        let mut matched = p
            .caption_id
            .as_ref()
            .and_then(|id| previous.iter().find(|r| &r.segment.id == id));
        if matched.is_none() && p.role == "tail" {
            matched = previous[cursor..]
                .iter()
                .rev()
                .find(|r| r.preview_role == "tail" && compatible(r));
        }
        let positional = previous.get(position);
        if matched.is_none() {
            let exact = previous[cursor..]
                .iter()
                .find(|r| compatible(r) && similarity(source(r), &p.text) == 2.0);
            if exact.is_some() && positional.is_none_or(|r| similarity(source(r), &p.text) < 0.5) {
                matched = exact;
            }
        }
        if matched.is_none() && previous.len() == incoming.len() && position >= cursor {
            if let Some(row) = positional {
                if compatible(row)
                    && row.preview_role == p.role
                    && (similarity(source(row), &p.text) >= 0.5 || previous.len() == 1)
                {
                    matched = Some(row);
                }
            }
        }
        if matched.is_none() {
            let mut best = 0.0;
            for row in &previous[cursor..] {
                if !compatible(row) {
                    continue;
                }
                let score = similarity(source(row), &p.text);
                if score > best {
                    best = score;
                    matched = Some(row);
                }
            }
            if best < 0.5 {
                matched = None;
            }
        }
        if matched.is_none() && previous.len() == incoming.len() && position >= cursor {
            if let Some(row) = positional {
                if row.segment_id.is_none()
                    && available.contains(&row.segment.id)
                    && (similarity(source(row), &p.text) >= 0.5 || previous.len() == 1)
                    && (p.speaker.is_empty()
                        || row.segment.speaker.is_empty()
                        || p.speaker == row.segment.speaker)
                {
                    matched = Some(row);
                }
            }
        }
        if let Some(old) = matched {
            let id = old.segment.id.clone();
            let row = v.captions.iter_mut().find(|r| r.segment.id == id).unwrap();
            row.in_preview = true;
            row.preview_text = p.text.clone();
            row.preview_role = p.role.clone();
            if !row.source_final && !p.text.is_empty() {
                row.segment.text = p.text.clone();
            }
            if !row.translation_final && !p.translation.is_empty() {
                row.segment.translation = p.translation.clone();
            }
            if row.segment.speaker.is_empty() {
                row.segment.speaker = p.speaker.clone();
            }
            available.remove(&id);
            cursor = cursor.max(previous.iter().position(|r| r.segment.id == id).unwrap() + 1);
        } else {
            let mut row = new_row(v, run);
            row.segment.text = p.text.clone();
            row.segment.translation = p.translation.clone();
            row.segment.speaker = p.speaker.clone();
            row.preview_text = p.text.clone();
            row.preview_role = p.role.clone();
            row.provisional = true;
            row.in_preview = true;
            v.captions.push(row);
            cursor = previous.len();
        }
    }
    with_preview(v);
}
pub fn translation_preview(v: &mut View, msg: &Value, run: u64) {
    let text = string(&msg["text"]);
    if v.structured_preview || text.is_empty() {
        return;
    }
    let src = string(&msg["sourceText"]);
    let current: Vec<_> = v
        .captions
        .iter()
        .filter(|r| r.run == run)
        .cloned()
        .collect();
    if let Some((group, _)) = merged(&src, &current, false) {
        if let Some(parts) = split_existing(
            &text,
            &group
                .iter()
                .map(|r| r.segment.translation.clone())
                .collect::<Vec<_>>(),
            true,
        ) {
            for (i, old) in group.iter().enumerate() {
                if let Some(r) = v
                    .captions
                    .iter_mut()
                    .find(|r| r.segment.id == old.segment.id)
                {
                    if !r.translation_final {
                        r.segment.translation = parts[i].clone();
                    }
                }
            }
            with_preview(v);
        }
        return;
    }
    let mut best = 0.0;
    let mut id = None;
    if !src.is_empty() {
        for r in v
            .captions
            .iter()
            .filter(|r| r.run == run && !r.translation_final)
        {
            let score = similarity(&r.segment.text, &src);
            if score >= 0.5 && score >= best {
                best = score;
                id = Some(r.segment.id.clone());
            }
        }
    }
    if id.is_none() {
        let pending = v
            .captions
            .iter()
            .filter(|r| r.run == run && r.provisional && r.in_preview)
            .count();
        if !src.is_empty() && pending > 0 {
            return;
        }
        if pending == 0 {
            transcript_preview(v, &serde_json::json!({"text":src}), run);
        }
        id = v
            .captions
            .iter()
            .rev()
            .find(|r| r.run == run && r.provisional && r.in_preview)
            .map(|r| r.segment.id.clone());
    }
    if let Some(r) = id.and_then(|id| v.captions.iter_mut().find(|r| r.segment.id == id)) {
        if r.segment.text.is_empty() {
            r.segment.text = src;
        }
        r.segment.translation = text;
    }
    with_preview(v);
}
pub fn final_caption(v: &mut View, s: &Segment, kind: &str, run: u64) {
    let candidates: Vec<_> = v
        .captions
        .iter()
        .filter(|r| {
            r.run == run && (r.segment_id.is_none() || r.segment_id.as_deref() == Some(&s.id))
        })
        .cloned()
        .collect();
    let existing: Vec<_> = candidates
        .iter()
        .filter(|r| r.segment_id.as_deref() == Some(&s.id))
        .cloned()
        .collect();
    let merged = merged(&s.text, &candidates, false);
    let group = merged.as_ref().map(|x| x.0.clone()).or_else(|| {
        if existing.len() > 1 {
            Some(existing.clone())
        } else {
            None
        }
    });
    if let Some(group) = group {
        let sources = merged.map(|x| x.1).or_else(|| {
            split_existing(
                &s.text,
                &group
                    .iter()
                    .map(|r| source(r).to_owned())
                    .collect::<Vec<_>>(),
                true,
            )
        });
        let translated = split_existing(
            &s.translation,
            &group
                .iter()
                .map(|r| r.segment.translation.clone())
                .collect::<Vec<_>>(),
            true,
        );
        for (i, old) in group.iter().enumerate() {
            if let Some(row) = v
                .captions
                .iter_mut()
                .find(|r| r.segment.id == old.segment.id)
            {
                let old_source = row.segment.text.clone();
                let old_translation = row.segment.translation.clone();
                let id = row.segment.id.clone();
                row.segment = s.clone();
                row.segment.id = id;
                row.segment.text = sources.as_ref().map(|p| p[i].clone()).unwrap_or(old_source);
                row.preview_text = row.segment.text.clone();
                row.segment.translation = translated
                    .as_ref()
                    .map(|p| p[i].clone())
                    .unwrap_or(old_translation);
                row.segment_id = Some(s.id.clone());
                row.provisional = false;
                row.source_final |= kind == "transcript.final";
                row.translation_final |= translated.is_some() && kind == "translation.final";
            }
        }
        with_preview(v);
        return;
    }
    let mut id = existing.first().map(|r| r.segment.id.clone());
    if id.is_none() {
        let pending: Vec<_> = candidates
            .iter()
            .filter(|r| r.segment_id.is_none())
            .collect();
        let mut best = 0.0;
        for r in &pending {
            let score =
                similarity(&r.segment.text, &s.text).max(similarity(&r.preview_text, &s.text));
            if score > best {
                best = score;
                id = Some(r.segment.id.clone());
            }
        }
        if best < 0.5 {
            id = if kind == "transcript.final" {
                pending.first().map(|r| r.segment.id.clone())
            } else {
                None
            };
        }
    }
    if id.is_none() {
        let row = new_row(v, run);
        id = Some(row.segment.id.clone());
        v.captions.push(row);
    }
    let row = v
        .captions
        .iter_mut()
        .find(|r| Some(&r.segment.id) == id.as_ref())
        .unwrap();
    let local_id = row.segment.id.clone();
    let old_text = row.segment.text.clone();
    let old_translation = row.segment.translation.clone();
    row.segment = s.clone();
    row.segment.id = local_id;
    if row.segment.text.is_empty() {
        row.segment.text = old_text;
    }
    if row.segment.translation.is_empty() {
        row.segment.translation = old_translation;
    }
    row.segment_id = Some(s.id.clone());
    row.provisional = false;
    row.source_final |= kind == "transcript.final";
    row.translation_final |= kind == "translation.final";
    with_preview(v);
}
