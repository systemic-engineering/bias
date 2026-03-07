/// Action: operations for building and dispatching actions.
///
/// Actions are the exhaustive pattern match on the decision space.
/// The upper ceiling for actions is the totality of the type resulting
/// from decision. No catch-all. Every variant has a branch.
///
/// Actions are structurally bound to their decision variant.
/// You cannot have an unhandled decision.

import bias.{
  type Action, type Decision, type DecisionActions, type Observer,
}
import gleam/list

/// Build a new Action with computed content hash.
pub fn new(
  target: String,
  config: List(#(String, String)),
) -> Action {
  let act = bias.Action(sha: "", target: target, config: config)
  let sha = bias.hash_action(act)
  bias.Action(..act, sha: sha)
}

/// Build a DecisionActions mapping — links a decision variant
/// to its exhaustive list of actions.
pub fn for_variant(
  variant: String,
  actions: List(Action),
) -> DecisionActions {
  bias.DecisionActions(variant: variant, actions: actions)
}

/// Dispatch: given an observer and a decision, return the actions
/// that should fire. Returns Error(Nil) if the variant has no mapping
/// (which indicates a broken tree — should not happen in a valid observer).
pub fn dispatch(
  observer: Observer,
  decision: Decision,
) -> Result(List(Action), Nil) {
  observer.actions
  |> list.find(fn(da) { da.variant == decision.variant })
  |> result_map_actions
}

/// Dispatch all: given an observer and a list of decisions,
/// return all actions that should fire, in decision order.
/// Skips any decisions that have no action mapping (logs nothing —
/// caller is responsible for validation).
pub fn dispatch_all(
  observer: Observer,
  decisions: List(Decision),
) -> List(Action) {
  list.flat_map(decisions, fn(dec) {
    case dispatch(observer, dec) {
      Ok(actions) -> actions
      Error(_) -> []
    }
  })
}

/// Extract a specific config value from an action by key.
pub fn get_config(
  action: Action,
  key: String,
) -> Result(String, Nil) {
  action.config
  |> list.find(fn(pair) {
    let #(k, _) = pair
    k == key
  })
  |> result_map_value
}

/// Check whether two actions are content-identical (same SHA).
pub fn identical(a: Action, b: Action) -> Bool {
  a.sha == b.sha
}

/// Count total actions across all decision mappings in an observer.
pub fn total_actions(observer: Observer) -> Int {
  observer.actions
  |> list.map(fn(da) { list.length(da.actions) })
  |> list.fold(0, fn(acc, n) { acc + n })
}

fn result_map_actions(
  result: Result(DecisionActions, Nil),
) -> Result(List(Action), Nil) {
  case result {
    Ok(da) -> Ok(da.actions)
    Error(Nil) -> Error(Nil)
  }
}

fn result_map_value(
  result: Result(#(String, String), Nil),
) -> Result(String, Nil) {
  case result {
    Ok(#(_, v)) -> Ok(v)
    Error(Nil) -> Error(Nil)
  }
}
