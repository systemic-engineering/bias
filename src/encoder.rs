use crate::action::{Action, DecisionActions};
use crate::decision::Decision;
use crate::observable::Observable;
use crate::observer::Observer;
use crate::sha::{self, Sha};
use crate::tree::Tree;

/// Pluggable serialization for bias types.
/// Different encoders produce different canonical forms,
/// and therefore different content-addressed hashes.
/// The encoding is part of the identity.
pub trait Encoder {
    fn serialize_observable(&self, obs: &Observable) -> String;
    fn serialize_decision(&self, dec: &Decision) -> String;
    fn serialize_action(&self, act: &Action) -> String;
    fn serialize_decision_actions(&self, da: &DecisionActions) -> String;
    fn serialize_observer(&self, obs: &Observer) -> String;
    fn serialize_tree(&self, tree: &Tree) -> String;

    fn hash_observable(&self, obs: &Observable) -> Sha {
        sha::hash(&self.serialize_observable(obs))
    }
    fn hash_decision(&self, dec: &Decision) -> Sha {
        sha::hash(&self.serialize_decision(dec))
    }
    fn hash_action(&self, act: &Action) -> Sha {
        sha::hash(&self.serialize_action(act))
    }
    fn hash_observer(&self, obs: &Observer) -> Sha {
        sha::hash(&self.serialize_observer(obs))
    }
    fn hash_tree(&self, tree: &Tree) -> Sha {
        sha::hash(&self.serialize_tree(tree))
    }
}

/// Backward-compatible default. Delegates to existing serialize functions.
pub struct DefaultEncoder;

impl Encoder for DefaultEncoder {
    fn serialize_observable(&self, obs: &Observable) -> String {
        crate::observable::serialize(obs)
    }
    fn serialize_decision(&self, dec: &Decision) -> String {
        crate::decision::serialize(dec)
    }
    fn serialize_action(&self, act: &Action) -> String {
        crate::action::serialize_action(act)
    }
    fn serialize_decision_actions(&self, da: &DecisionActions) -> String {
        crate::action::serialize_decision_actions(da)
    }
    fn serialize_observer(&self, obs: &Observer) -> String {
        crate::observer::serialize(obs)
    }
    fn serialize_tree(&self, tree: &Tree) -> String {
        crate::tree::serialize(tree)
    }
}
