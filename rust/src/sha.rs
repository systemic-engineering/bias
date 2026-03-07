use sha2::{Digest, Sha256};

/// Content-addressed hash.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Sha(pub String);

/// Raw SHA-256 hash of a string.
pub fn hash(data: &str) -> Sha {
    todo!("implement SHA-256 hashing")
}
