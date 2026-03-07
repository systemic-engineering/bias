use crate::action::{self, Action, DecisionActions};
use crate::decision::{self, Decision};
use crate::encoder::Encoder;
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
    if let Err(missing) = validate_exhaustive(&decisions, &actions) {
        return Err(ObserverError::MissingActions(missing));
    }
    let observer = Observer {
        sha: String::new(),
        id: id.to_string(),
        decisions,
        actions,
    };
    let sha = hash(&observer);
    Ok(Observer {
        sha: sha.0,
        ..observer
    })
}

/// Build a new observer with SHA computed by a custom encoder.
/// Validates exhaustiveness: every decision variant must have actions.
pub fn new_with(
    _encoder: &dyn Encoder,
    _id: &str,
    _decisions: Vec<Decision>,
    _actions: Vec<DecisionActions>,
) -> Result<Observer, ObserverError> {
    todo!()
}

/// Apply an observer to an observable, producing decisions.
pub fn observe<F>(observer: &Observer, observable: &Observable, decide: F) -> Vec<Decision>
where
    F: Fn(&Observable) -> Vec<Decision>,
{
    let _ = observer;
    decide(observable)
}

/// Look up the actions for a specific decision variant.
pub fn actions_for<'a>(observer: &'a Observer, variant: &str) -> Option<&'a [Action]> {
    observer
        .actions
        .iter()
        .find(|da| da.variant == variant)
        .map(|da| da.actions.as_slice())
}

/// Extract all decision variant names from an observer.
pub fn decision_variants(observer: &Observer) -> Vec<&str> {
    observer
        .decisions
        .iter()
        .map(|d| d.variant.as_str())
        .collect()
}

/// Extract all action targets across all decisions.
pub fn action_targets(observer: &Observer) -> Vec<&str> {
    observer
        .actions
        .iter()
        .flat_map(|da| da.actions.iter().map(|a| a.target.as_str()))
        .collect()
}

/// Check whether an observer is exhaustive.
pub fn is_exhaustive(observer: &Observer) -> bool {
    validate_exhaustive(&observer.decisions, &observer.actions).is_ok()
        && validate_no_orphans(&observer.decisions, &observer.actions).is_ok()
}

/// Serialize an Observer to canonical form.
/// Format: Observer(id, decisions[D1 | D2], actions[DA1 | DA2])
pub fn serialize(obs: &Observer) -> String {
    let decisions: Vec<String> = obs.decisions.iter().map(decision::serialize).collect();
    let actions: Vec<String> = obs
        .actions
        .iter()
        .map(action::serialize_decision_actions)
        .collect();
    format!(
        "Observer({}, decisions[{}], actions[{}])",
        obs.id,
        decisions.join(" | "),
        actions.join(" | ")
    )
}

/// Compute the content hash for an Observer.
pub fn hash(obs: &Observer) -> Sha {
    sha::hash(&serialize(obs))
}

fn validate_exhaustive(
    decisions: &[Decision],
    actions: &[DecisionActions],
) -> Result<(), Vec<String>> {
    let action_variants: Vec<&str> = actions.iter().map(|da| da.variant.as_str()).collect();
    let missing: Vec<String> = decisions
        .iter()
        .filter(|d| !action_variants.contains(&d.variant.as_str()))
        .map(|d| d.variant.clone())
        .collect();
    if missing.is_empty() {
        Ok(())
    } else {
        Err(missing)
    }
}

fn validate_no_orphans(
    decisions: &[Decision],
    actions: &[DecisionActions],
) -> Result<(), Vec<String>> {
    let decision_variants: Vec<&str> = decisions.iter().map(|d| d.variant.as_str()).collect();
    let orphans: Vec<String> = actions
        .iter()
        .filter(|da| !decision_variants.contains(&da.variant.as_str()))
        .map(|da| da.variant.clone())
        .collect();
    if orphans.is_empty() {
        Ok(())
    } else {
        Err(orphans)
    }
}
