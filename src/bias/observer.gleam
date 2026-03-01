/// Observer: operations for building and validating observers.
///
/// An observer is the decision-making entity in the tree.
/// It takes an observable and produces decisions — typed variants
/// that represent what the observer SEES. The decision function
/// is the observer's subjectivity made structural.
///
/// Key invariant: every decision variant in an observer must have
/// a corresponding entry in the observer's actions map. This is
/// the exhaustiveness guarantee — no decision goes unhandled.

import bias.{
  type Action, type Decision, type DecisionActions, type Observable,
  type Observer,
}
import gleam/list

/// Build a new observer with computed content hash.
/// Validates exhaustiveness: every decision variant must have actions.
/// Returns Error if any decision variant lacks an action mapping.
pub fn new(
  id: String,
  decisions: List(Decision),
  actions: List(DecisionActions),
) -> Result(Observer, ObserverError) {
  case validate_exhaustive(decisions, actions) {
    Error(missing) -> Error(MissingActions(missing))
    Ok(_) -> {
      let observer =
        bias.Observer(sha: "", id: id, decisions: decisions, actions: actions)
      let sha = bias.hash_observer(observer)
      Ok(bias.Observer(..observer, sha: sha))
    }
  }
}

/// Errors that can occur when building an observer.
pub type ObserverError {
  /// Decision variants that have no corresponding action mapping.
  MissingActions(variants: List(String))
  /// Action mappings that reference non-existent decision variants.
  OrphanActions(variants: List(String))
}

/// Apply an observer to an observable, producing decisions.
/// This is the core operation: observation filtered through subjectivity.
///
/// The `decide` function is the observer's decision logic — it takes
/// the observable and returns the list of decisions the observer makes.
/// The caller provides this function; the observer provides the structure.
pub fn observe(
  observer: Observer,
  observable: Observable,
  decide: fn(Observable) -> List(Decision),
) -> List(Decision) {
  let _ = observer
  decide(observable)
}

/// Look up the actions for a specific decision variant.
/// Returns the action list if found, Error(Nil) if the variant
/// has no action mapping (which should not happen in a valid observer).
pub fn actions_for(
  observer: Observer,
  variant: String,
) -> Result(List(Action), Nil) {
  observer.actions
  |> list.find(fn(da) { da.variant == variant })
  |> result_map_actions
}

/// Extract all decision variant names from an observer.
pub fn decision_variants(observer: Observer) -> List(String) {
  list.map(observer.decisions, fn(d) { d.variant })
}

/// Extract all action variant names (targets) across all decisions.
pub fn action_targets(observer: Observer) -> List(String) {
  observer.actions
  |> list.flat_map(fn(da) { list.map(da.actions, fn(a) { a.target }) })
}

/// Check whether an observer is exhaustive: every decision variant
/// has a corresponding action mapping, and no orphan action mappings exist.
pub fn is_exhaustive(observer: Observer) -> Bool {
  case validate_exhaustive(observer.decisions, observer.actions) {
    Ok(_) ->
      case validate_no_orphans(observer.decisions, observer.actions) {
        Ok(_) -> True
        Error(_) -> False
      }
    Error(_) -> False
  }
}

/// Validate that every decision variant has a corresponding action mapping.
fn validate_exhaustive(
  decisions: List(Decision),
  actions: List(DecisionActions),
) -> Result(Nil, List(String)) {
  let action_variants = list.map(actions, fn(da) { da.variant })
  let missing =
    decisions
    |> list.filter(fn(d) { !list.contains(action_variants, d.variant) })
    |> list.map(fn(d) { d.variant })
  case missing {
    [] -> Ok(Nil)
    _ -> Error(missing)
  }
}

/// Validate that no action mappings reference non-existent decision variants.
fn validate_no_orphans(
  decisions: List(Decision),
  actions: List(DecisionActions),
) -> Result(Nil, List(String)) {
  let decision_variant_names = list.map(decisions, fn(d) { d.variant })
  let orphans =
    actions
    |> list.filter(fn(da) {
      !list.contains(decision_variant_names, da.variant)
    })
    |> list.map(fn(da) { da.variant })
  case orphans {
    [] -> Ok(Nil)
    _ -> Error(orphans)
  }
}

fn result_map_actions(
  result: Result(DecisionActions, Nil),
) -> Result(List(Action), Nil) {
  case result {
    Ok(da) -> Ok(da.actions)
    Error(Nil) -> Error(Nil)
  }
}
