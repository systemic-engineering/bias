use crate::sha::{self, Sha};

/// A content-addressed observation. Wraps a SHA identifying what was observed.
/// The observable is the root of every tree — the thing being looked at.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Observable {
    pub sha: String,
    pub kind: String,
    pub source: String,
}

impl Observable {
    pub fn new(sha: &str, kind: &str, source: &str) -> Self {
        Observable {
            sha: sha.to_string(),
            kind: kind.to_string(),
            source: source.to_string(),
        }
    }
}

/// Serialize an Observable to canonical form.
/// Format: Observable(kind, source, sha)
pub fn serialize(obs: &Observable) -> String {
    todo!("implement Observable serialization")
}

/// Compute the content hash for an Observable.
pub fn hash(obs: &Observable) -> Sha {
    todo!("implement Observable hashing")
}
