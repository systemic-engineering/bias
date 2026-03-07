use crate::sha::{self, Sha};

/// A typed variant produced by an observer's decision function.
/// The decision is what the observer SEES in the observable — observation
/// filtered through subjectivity.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Decision {
    pub sha: String,
    pub variant: String,
    pub payload: Vec<(String, String)>,
}

/// Build a new Decision with computed content hash.
pub fn new(variant: &str, payload: Vec<(String, String)>) -> Decision {
    let dec = Decision {
        sha: String::new(),
        variant: variant.to_string(),
        payload,
    };
    let sha = hash(&dec);
    Decision { sha: sha.0, ..dec }
}

/// Build a Decision with no payload.
pub fn variant(name: &str) -> Decision {
    new(name, vec![])
}

/// Extract the variant name from a decision.
pub fn variant_name(dec: &Decision) -> &str {
    &dec.variant
}

/// Extract a specific payload value by key.
pub fn get_payload<'a>(dec: &'a Decision, key: &str) -> Option<&'a str> {
    dec.payload
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.as_str())
}

/// Check whether two decisions have the same variant (regardless of payload).
pub fn same_variant(a: &Decision, b: &Decision) -> bool {
    a.variant == b.variant
}

/// Check whether two decisions are content-identical (same SHA).
pub fn identical(a: &Decision, b: &Decision) -> bool {
    a.sha == b.sha
}

/// Collect all unique variant names from a list of decisions.
pub fn variant_names(decisions: &[Decision]) -> Vec<String> {
    let mut names = Vec::new();
    for d in decisions {
        if !names.contains(&d.variant) {
            names.push(d.variant.clone());
        }
    }
    names
}

/// Group decisions by variant name.
pub fn group_by_variant(decisions: &[Decision]) -> Vec<(String, Vec<&Decision>)> {
    let names = variant_names(decisions);
    names
        .into_iter()
        .map(|v| {
            let matching: Vec<&Decision> = decisions.iter().filter(|d| d.variant == v).collect();
            (v, matching)
        })
        .collect()
}

/// Serialize a Decision to canonical form.
/// Format: Decision(variant, payload[k1=v1, k2=v2])
pub fn serialize(dec: &Decision) -> String {
    let pairs: Vec<String> = dec
        .payload
        .iter()
        .map(|(k, v)| format!("{}={}", k, v))
        .collect();
    format!("Decision({}, payload[{}])", dec.variant, pairs.join(", "))
}

/// Compute the content hash for a Decision.
pub fn hash(dec: &Decision) -> Sha {
    sha::hash(&serialize(dec))
}
