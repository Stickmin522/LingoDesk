use serde_json::Value;
use std::sync::LazyLock;

static LANGUAGES: LazyLock<Vec<String>> = LazyLock::new(|| {
    let catalog: Value = serde_json::from_str(include_str!("../../app/assets/languages.json"))
        .expect("valid bundled language catalog");
    catalog
        .as_array()
        .unwrap()
        .iter()
        .map(|entry| entry["code"].as_str().unwrap().to_owned())
        .collect()
});

pub fn parse_pair(pair: &str) -> Result<[&str; 2], String> {
    let parts: Vec<_> = pair.split('-').collect();
    if parts.len() != 2
        || !parts
            .iter()
            .all(|code| LANGUAGES.iter().any(|known| known == code))
    {
        return Err("不支持的语言".into());
    }
    if parts[0] == parts[1] {
        return Err("两种语言不能相同".into());
    }
    Ok([parts[0], parts[1]])
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn every_service_language_pairs_in_both_orders() {
        assert_eq!(LANGUAGES.len(), 60);
        for first in LANGUAGES.iter() {
            for second in LANGUAGES.iter() {
                let pair = format!("{first}-{second}");
                if first == second {
                    assert!(parse_pair(&pair).is_err());
                } else {
                    assert_eq!(
                        parse_pair(&pair).unwrap(),
                        [first.as_str(), second.as_str()]
                    );
                }
            }
        }
    }
    #[test]
    fn rejects_unknown_duplicate_and_malformed_pairs() {
        for pair in ["en-en", "zh-zh", "xx-zh", "en", "en-zh-ja", "", "EN-zh"] {
            assert!(parse_pair(pair).is_err(), "{pair}");
        }
        assert_eq!(parse_pair("ja-zh").unwrap(), ["ja", "zh"]);
    }
}
