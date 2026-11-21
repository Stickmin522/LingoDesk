use super::{View, string};
use serde_json::Value;
use std::collections::HashMap;

fn scoped(id: &str, run: u64) -> String {
    let id = id.trim();
    if id.is_empty() {
        return String::new();
    }
    // Some events send an index, while others send a label such as "speaker0".
    let lower = id.to_ascii_lowercase();
    let number = lower
        .strip_prefix("speaker")
        .map(|suffix| suffix.trim_start_matches([' ', '_', '-']))
        .unwrap_or(&lower)
        .parse::<u64>();
    match number {
        Ok(number) => format!("{run}.{number}"),
        Err(_) => format!("{run}.{id}"),
    }
}

pub(super) fn from_event(event: &Value, run: u64) -> String {
    let id = from_value(&event["speaker"], run);
    if id.is_empty() {
        from_value(&event["speakerId"], run)
    } else {
        id
    }
}

pub(super) fn from_value(value: &Value, run: u64) -> String {
    scoped(&string(value.get("id").unwrap_or(value)), run)
}

pub(super) fn remember(view: &mut View, id: &str) {
    if !id.is_empty() && !view.speaker_order.iter().any(|known| known == id) {
        view.speaker_order.push(id.to_owned());
    }
}

pub(super) fn compatible(a: &str, b: &str) -> bool {
    a.is_empty() || b.is_empty() || a == b
}

fn legacy_key(id: &str, run: u64) -> String {
    if let Some((prefix, speaker)) = id.split_once('.')
        && let Ok(run) = prefix.parse::<u64>()
    {
        return scoped(speaker, run);
    }
    scoped(id, run)
}

/// Keep the service IDs in saved session data for matching. Expose only local
/// numbers in snapshots, history, and exports.
pub(super) fn number_for_display(view: &mut View) {
    let mut numbers: HashMap<_, _> = std::mem::take(&mut view.speaker_order)
        .into_iter()
        .enumerate()
        .map(|(index, id)| (id, index + 1))
        .collect();

    let mut label = |id: &mut String, run| {
        let key = legacy_key(id, run);
        if key.is_empty() {
            id.clear();
        } else {
            let next = numbers.len() + 1;
            *id = numbers.entry(key).or_insert(next).to_string();
        }
    };
    for row in &mut view.captions {
        label(&mut row.segment.speaker, row.run);
    }
    for segment in &mut view.segments {
        let run = segment
            .id
            .split_once(':')
            .and_then(|(prefix, _)| prefix.parse::<u64>().ok())
            .unwrap_or_default();
        label(&mut segment.speaker, run);
    }
}
