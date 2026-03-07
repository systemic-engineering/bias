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
    todo!("implement Decision construction with hash")
}

/// Build a Decision with no payload.
pub fn variant(name: &str) -> Decision {
    todo!("implement Decision variant shorthand")
}

/// Extract the variant name from a decision.
pub fn variant_name(dec: &Decision) -> &str {
    todo!("implement variant_name")
}

/// Extract a specific payload value by key.
pub fn get_payload<'a>(dec: &'a Decision, key: &str) -> Option<&'a str> {
    todo!("implement get_payload")
}

/// Check whether two decisions have the same variant (regardless of payload).
pub fn same_variant(a: &Decision, b: &Decision) -> bool {
    todo!("implement same_variant")
}

/// Check whether two decisions are content-identical (same SHA).
pub fn identical(a: &Decision, b: &Decision) -> bool {
    todo!("implement identical")
}

/// Collect all unique variant names from a list of decisions.
pub fn variant_names(decisions: &[Decision]) -> Vec<String> {
    todo!("implement variant_names")
}

/// Group decisions by variant name.
pub fn group_by_variant(decisions: &[Decision]) -> Vec<(String, Vec<&Decision>)> {
    todo!("implement group_by_variant")
}

/// Serialize a Decision to canonical form.
/// Format: Decision(variant, payload[k1=v1, k2=v2])
pub fn serialize(dec: &Decision) -> String {
    todo!("implement Decision serialization")
}

/// Compute the content hash for a Decision.
pub fn hash(dec: &Decision) -> Sha {
    todo!("implement Decision hashing")
}
