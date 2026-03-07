use crate::decision::Decision;
use crate::encoder::Encoder;
use crate::observer::Observer;
use crate::sha::{self, Sha};

/// An action dispatched in response to a specific decision variant.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Action {
    pub sha: String,
    pub target: String,
    pub config: Vec<(String, String)>,
}

/// Maps a decision variant to its exhaustive list of actions.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DecisionActions {
    pub variant: String,
    pub actions: Vec<Action>,
}

/// Build a new Action with computed content hash.
pub fn new(target: &str, config: Vec<(String, String)>) -> Action {
    let act = Action {
        sha: String::new(),
        target: target.to_string(),
        config,
    };
    let sha = hash(&act);
    Action { sha: sha.0, ..act }
}

/// Build a new Action with SHA computed by a custom encoder.
pub fn new_with(encoder: &dyn Encoder, target: &str, config: Vec<(String, String)>) -> Action {
    let act = Action {
        sha: String::new(),
        target: target.to_string(),
        config,
    };
    let sha = encoder.hash_action(&act);
    Action { sha: sha.0, ..act }
}

/// Build a DecisionActions mapping.
pub fn for_variant(variant: &str, actions: Vec<Action>) -> DecisionActions {
    DecisionActions {
        variant: variant.to_string(),
        actions,
    }
}

/// Dispatch: given an observer and a decision, return the actions that should fire.
pub fn dispatch<'a>(observer: &'a Observer, decision: &Decision) -> Option<&'a [Action]> {
    observer
        .actions
        .iter()
        .find(|da| da.variant == decision.variant)
        .map(|da| da.actions.as_slice())
}

/// Dispatch all: given an observer and decisions, return all actions in decision order.
pub fn dispatch_all<'a>(observer: &'a Observer, decisions: &[Decision]) -> Vec<&'a Action> {
    decisions
        .iter()
        .flat_map(|dec| {
            dispatch(observer, dec)
                .map(|actions| actions.iter().collect::<Vec<_>>())
                .unwrap_or_default()
        })
        .collect()
}

/// Extract a specific config value from an action by key.
pub fn get_config<'a>(action: &'a Action, key: &str) -> Option<&'a str> {
    action
        .config
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.as_str())
}

/// Check whether two actions are content-identical (same SHA).
pub fn identical(a: &Action, b: &Action) -> bool {
    a.sha == b.sha
}

/// Count total actions across all decision mappings in an observer.
pub fn total_actions(observer: &Observer) -> usize {
    observer.actions.iter().map(|da| da.actions.len()).sum()
}

/// Serialize an Action to canonical form.
/// Format: Action(target, config[k1=v1, k2=v2])
pub fn serialize_action(act: &Action) -> String {
    let pairs: Vec<String> = act
        .config
        .iter()
        .map(|(k, v)| format!("{}={}", k, v))
        .collect();
    format!("Action({}, config[{}])", act.target, pairs.join(", "))
}

/// Serialize a DecisionActions to canonical form.
/// Format: DecisionActions(variant, actions[Action(...), Action(...)])
pub fn serialize_decision_actions(da: &DecisionActions) -> String {
    let actions: Vec<String> = da.actions.iter().map(serialize_action).collect();
    format!(
        "DecisionActions({}, actions[{}])",
        da.variant,
        actions.join(", ")
    )
}

/// Compute the content hash for an Action.
pub fn hash(act: &Action) -> Sha {
    sha::hash(&serialize_action(act))
}
