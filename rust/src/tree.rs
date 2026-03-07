use crate::observable::{self, Observable};
use crate::observer::{self, Observer};
use crate::sha::{self, Sha};

/// The full tree: observable -> List(Observer) -> per-observer decisions
/// -> per-decision actions.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Tree {
    pub sha: String,
    pub observable: Observable,
    pub observers: Vec<Observer>,
}

/// Serialize a Tree to canonical form.
/// Format: Tree(Observable(...), observers[Observer(...) | Observer(...)])
pub fn serialize(tree: &Tree) -> String {
    let observers: Vec<String> = tree.observers.iter().map(observer::serialize).collect();
    format!(
        "Tree({}, observers[{}])",
        observable::serialize(&tree.observable),
        observers.join(" | ")
    )
}

/// Compute the content hash for a Tree.
pub fn hash(tree: &Tree) -> Sha {
    sha::hash(&serialize(tree))
}
