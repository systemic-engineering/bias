use crate::action::{self, Action, DecisionActions};
use crate::decision::{self, Decision};
use crate::observable::Observable;
use crate::sha::{self, Sha};

/// An entity that observes and decides. The decision function IS
/// the observer's subjectivity made structural.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Observer {
    pub sha: String,
    pub id: String,
    pub decisions: Vec<Decision>,
    pub actions: Vec<DecisionActions>,
}

/// Errors that can occur when building an observer.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ObserverError {
    /// Decision variants that have no corresponding action mapping.
    MissingActions(Vec<String>),
    /// Action mappings that reference non-existent decision variants.
    OrphanActions(Vec<String>),
}

/// Build a new observer with computed content hash.
/// Validates exhaustiveness: every decision variant must have actions.
pub fn new(
    id: &str,
    decisions: Vec<Decision>,
    actions: Vec<DecisionActions>,
) -> Result<Observer, ObserverError> {
    todo!("implement Observer construction with exhaustiveness validation")
}

/// Apply an observer to an observable, producing decisions.
pub fn observe<F>(observer: &Observer, observable: &Observable, decide: F) -> Vec<Decision>
where
    F: Fn(&Observable) -> Vec<Decision>,
{
    todo!("implement observe")
}

/// Look up the actions for a specific decision variant.
pub fn actions_for<'a>(observer: &'a Observer, variant: &str) -> Option<&'a [Action]> {
    todo!("implement actions_for")
}

/// Extract all decision variant names from an observer.
pub fn decision_variants(observer: &Observer) -> Vec<&str> {
    todo!("implement decision_variants")
}

/// Extract all action targets across all decisions.
pub fn action_targets(observer: &Observer) -> Vec<&str> {
    todo!("implement action_targets")
}

/// Check whether an observer is exhaustive.
pub fn is_exhaustive(observer: &Observer) -> bool {
    todo!("implement is_exhaustive")
}

/// Serialize an Observer to canonical form.
/// Format: Observer(id, decisions[D1 | D2], actions[DA1 | DA2])
pub fn serialize(obs: &Observer) -> String {
    todo!("implement Observer serialization")
}

/// Compute the content hash for an Observer.
pub fn hash(obs: &Observer) -> Sha {
    todo!("implement Observer hashing")
}
