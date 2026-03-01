/// Bias: Observe, Decide, Act.
///
/// A decision tree where observation passes through subjectivity.
/// Every observer has bias — weight-shifting, legacy patterns, filters.
/// Bias makes it typed, exhaustive, diffable. You can't fix what you
/// can't see, and you can't see what you won't name.
///
/// ```
/// observable
/// +-- observer-A
/// |   +-- decision-1
/// |   |   +-- action-a
/// |   |   +-- action-b
/// |   +-- decision-2
/// |       +-- action-c
/// +-- observer-B
///     +-- decision-3
///         +-- action-d
/// ```
///
/// Every level is content-addressable (has a SHA-256 hash).
/// The tree is diffable at every level.
///
/// Decision is transformation: weight-shifting, legacy patterns, filters, bias.
/// The decision function IS the observer's subjectivity made structural.
///
/// Actions are exhaustive pattern match: the upper ceiling for actions is
/// the totality of the type resulting from decision. No catch-all.
/// Every variant has a branch.

import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Observable
// ---------------------------------------------------------------------------

/// A content-addressed observation. Wraps a SHA identifying what was observed.
/// The observable is the root of every tree — the thing being looked at.
pub type Observable {
  Observable(sha: String, kind: String, source: String)
}

// ---------------------------------------------------------------------------
// Decision
// ---------------------------------------------------------------------------

/// A typed variant produced by an observer's decision function.
/// The decision is what the observer SEES in the observable — observation
/// filtered through subjectivity. Each variant is a distinct interpretation.
///
/// `variant` names the decided type (e.g. "Critical", "Ignore", "Escalate").
/// `payload` carries key-value data specific to that variant.
/// `sha` is the content hash of variant + payload for diffability.
pub type Decision {
  Decision(
    sha: String,
    variant: String,
    payload: List(#(String, String)),
  )
}

// ---------------------------------------------------------------------------
// Action
// ---------------------------------------------------------------------------

/// An action dispatched in response to a specific decision variant.
/// Actions are the exhaustive pattern match on the decision space —
/// every decision variant maps to at least one action. No catch-all.
///
/// `target` names the action kind (e.g. "Alert", "Deploy", "Notify").
/// `config` carries the action parameters.
/// `sha` is the content hash for diffability.
pub type Action {
  Action(
    sha: String,
    target: String,
    config: List(#(String, String)),
  )
}

// ---------------------------------------------------------------------------
// Observer
// ---------------------------------------------------------------------------

/// An entity that observes and decides. Has a decision function that
/// transforms an observable into decisions. The decision function IS
/// the observer's subjectivity made structural.
///
/// `id` names this observer.
/// `decisions` is the set of decisions this observer can produce.
/// `actions` maps each decision variant to its exhaustive action list.
/// `sha` is the content hash of the observer's full decision tree.
pub type Observer {
  Observer(
    sha: String,
    id: String,
    decisions: List(Decision),
    actions: List(DecisionActions),
  )
}

/// Maps a decision variant to its exhaustive list of actions.
/// The `variant` must match a Decision variant in the parent Observer.
/// The `actions` list covers every branch — no catch-all allowed.
pub type DecisionActions {
  DecisionActions(variant: String, actions: List(Action))
}

// ---------------------------------------------------------------------------
// Tree
// ---------------------------------------------------------------------------

/// The full tree: observable -> List(Observer) -> per-observer decisions
/// -> per-decision actions.
///
/// Content-addressable at the root level. The tree SHA is computed from
/// the observable SHA and all observer SHAs — a change anywhere in the
/// tree produces a different root hash.
pub type Tree {
  Tree(sha: String, observable: Observable, observers: List(Observer))
}

// ---------------------------------------------------------------------------
// Serialization — deterministic canonical form for hashing
// ---------------------------------------------------------------------------

/// Serialize an Observable to canonical form.
pub fn serialize_observable(obs: Observable) -> String {
  "Observable("
  <> obs.kind
  <> ", "
  <> obs.source
  <> ", "
  <> obs.sha
  <> ")"
}

/// Serialize a Decision to canonical form.
pub fn serialize_decision(dec: Decision) -> String {
  "Decision("
  <> dec.variant
  <> ", payload["
  <> string.join(list.map(dec.payload, serialize_pair), ", ")
  <> "])"
}

/// Serialize an Action to canonical form.
pub fn serialize_action(act: Action) -> String {
  "Action("
  <> act.target
  <> ", config["
  <> string.join(list.map(act.config, serialize_pair), ", ")
  <> "])"
}

/// Serialize a DecisionActions to canonical form.
pub fn serialize_decision_actions(da: DecisionActions) -> String {
  "DecisionActions("
  <> da.variant
  <> ", actions["
  <> string.join(list.map(da.actions, serialize_action), ", ")
  <> "])"
}

/// Serialize an Observer to canonical form.
pub fn serialize_observer(obs: Observer) -> String {
  "Observer("
  <> obs.id
  <> ", decisions["
  <> string.join(list.map(obs.decisions, serialize_decision), " | ")
  <> "], actions["
  <> string.join(list.map(obs.actions, serialize_decision_actions), " | ")
  <> "])"
}

/// Serialize a Tree to canonical form.
pub fn serialize_tree(tree: Tree) -> String {
  "Tree("
  <> serialize_observable(tree.observable)
  <> ", observers["
  <> string.join(list.map(tree.observers, serialize_observer), " | ")
  <> "])"
}

/// Serialize a key-value pair.
fn serialize_pair(pair: #(String, String)) -> String {
  let #(key, value) = pair
  key <> "=" <> value
}

// ---------------------------------------------------------------------------
// Hashing — content-addressable identity at every level
// ---------------------------------------------------------------------------

/// SHA-256 hash of the canonical serialization.
pub fn hash(data: String) -> String {
  sha256(data)
}

/// Compute the content hash for an Observable.
pub fn hash_observable(obs: Observable) -> String {
  obs
  |> serialize_observable
  |> sha256
}

/// Compute the content hash for a Decision.
pub fn hash_decision(dec: Decision) -> String {
  dec
  |> serialize_decision
  |> sha256
}

/// Compute the content hash for an Action.
pub fn hash_action(act: Action) -> String {
  act
  |> serialize_action
  |> sha256
}

/// Compute the content hash for an Observer.
pub fn hash_observer(obs: Observer) -> String {
  obs
  |> serialize_observer
  |> sha256
}

/// Compute the content hash for a Tree.
pub fn hash_tree(tree: Tree) -> String {
  tree
  |> serialize_tree
  |> sha256
}

@external(erlang, "bias_ffi", "sha256")
fn sha256(data: String) -> String
