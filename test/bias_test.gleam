/// Bias tests: Observe, Decide, Act.
///
/// TDD bottom-up: construct trees by hand,
/// verify they hash correctly, validate exhaustiveness,
/// and test the dispatch pipeline.

import bias
import bias/action
import bias/decision
import bias/observer
import gleam/list
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Observable: content-addressed observations
// ---------------------------------------------------------------------------

pub fn observable_constructs_test() {
  let obs = bias.Observable(sha: "abc123", kind: "git.commit", source: "repo")
  assert obs.sha == "abc123"
  assert obs.kind == "git.commit"
  assert obs.source == "repo"
}

pub fn observable_hash_is_sha256_test() {
  let obs = bias.Observable(sha: "abc123", kind: "git.commit", source: "repo")
  let h = bias.hash_observable(obs)
  assert string.length(h) == 64
}

pub fn observable_identical_hash_equal_test() {
  let a = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let b = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  assert bias.hash_observable(a) == bias.hash_observable(b)
}

pub fn observable_different_sha_hash_different_test() {
  let a = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let b = bias.Observable(sha: "def", kind: "git.commit", source: "repo")
  assert bias.hash_observable(a) != bias.hash_observable(b)
}

pub fn observable_different_kind_hash_different_test() {
  let a = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let b = bias.Observable(sha: "abc", kind: "github.pr", source: "repo")
  assert bias.hash_observable(a) != bias.hash_observable(b)
}

// ---------------------------------------------------------------------------
// Decision: typed transformation results
// ---------------------------------------------------------------------------

pub fn decision_new_with_payload_test() {
  let dec = decision.new("Critical", [#("severity", "high")])
  assert dec.variant == "Critical"
  assert dec.payload == [#("severity", "high")]
  assert string.length(dec.sha) == 64
}

pub fn decision_variant_shorthand_test() {
  let dec = decision.variant("Ignore")
  assert dec.variant == "Ignore"
  assert dec.payload == []
  assert string.length(dec.sha) == 64
}

pub fn decision_identical_hash_equal_test() {
  let a = decision.new("Critical", [#("severity", "high")])
  let b = decision.new("Critical", [#("severity", "high")])
  assert decision.identical(a, b)
}

pub fn decision_different_variant_hash_different_test() {
  let a = decision.variant("Critical")
  let b = decision.variant("Ignore")
  assert !decision.identical(a, b)
}

pub fn decision_different_payload_hash_different_test() {
  let a = decision.new("Critical", [#("severity", "high")])
  let b = decision.new("Critical", [#("severity", "low")])
  assert !decision.identical(a, b)
}

pub fn decision_same_variant_test() {
  let a = decision.new("Critical", [#("severity", "high")])
  let b = decision.new("Critical", [#("severity", "low")])
  assert decision.same_variant(a, b)
}

pub fn decision_get_payload_found_test() {
  let dec = decision.new("Alert", [#("channel", "email"), #("priority", "1")])
  assert decision.get_payload(dec, "channel") == Ok("email")
  assert decision.get_payload(dec, "priority") == Ok("1")
}

pub fn decision_get_payload_not_found_test() {
  let dec = decision.variant("Ignore")
  assert decision.get_payload(dec, "anything") == Error(Nil)
}

pub fn decision_variant_names_test() {
  let decs = [
    decision.variant("Critical"),
    decision.variant("Warning"),
    decision.variant("Ignore"),
  ]
  let names = decision.variant_names(decs)
  assert names == ["Critical", "Warning", "Ignore"]
}

pub fn decision_variant_names_deduplicates_test() {
  let decs = [
    decision.new("Critical", [#("a", "1")]),
    decision.new("Critical", [#("a", "2")]),
    decision.variant("Ignore"),
  ]
  let names = decision.variant_names(decs)
  assert names == ["Critical", "Ignore"]
}

pub fn decision_group_by_variant_test() {
  let d1 = decision.new("Critical", [#("id", "1")])
  let d2 = decision.new("Critical", [#("id", "2")])
  let d3 = decision.variant("Ignore")
  let groups = decision.group_by_variant([d1, d2, d3])
  assert list.length(groups) == 2
  let assert [#("Critical", crits), #("Ignore", ignores)] = groups
  assert list.length(crits) == 2
  assert list.length(ignores) == 1
}

// ---------------------------------------------------------------------------
// Action: exhaustive dispatch
// ---------------------------------------------------------------------------

pub fn action_new_test() {
  let act = action.new("Alert", [#("channel", "ntfy")])
  assert act.target == "Alert"
  assert act.config == [#("channel", "ntfy")]
  assert string.length(act.sha) == 64
}

pub fn action_identical_hash_equal_test() {
  let a = action.new("Alert", [#("channel", "ntfy")])
  let b = action.new("Alert", [#("channel", "ntfy")])
  assert action.identical(a, b)
}

pub fn action_different_target_hash_different_test() {
  let a = action.new("Alert", [#("channel", "ntfy")])
  let b = action.new("Deploy", [#("channel", "ntfy")])
  assert !action.identical(a, b)
}

pub fn action_get_config_test() {
  let act = action.new("Alert", [#("channel", "ntfy"), #("priority", "high")])
  assert action.get_config(act, "channel") == Ok("ntfy")
  assert action.get_config(act, "priority") == Ok("high")
  assert action.get_config(act, "missing") == Error(Nil)
}

pub fn action_for_variant_test() {
  let act1 = action.new("Alert", [#("channel", "ntfy")])
  let act2 = action.new("Email", [#("to", "ops@example.com")])
  let da = action.for_variant("Critical", [act1, act2])
  assert da.variant == "Critical"
  assert list.length(da.actions) == 2
}

// ---------------------------------------------------------------------------
// Observer: decision-making entity with exhaustiveness
// ---------------------------------------------------------------------------

/// Helper: build a valid observer with two decisions and exhaustive actions.
fn sample_observer() -> bias.Observer {
  let critical = decision.variant("Critical")
  let ignore = decision.variant("Ignore")

  let alert = action.new("Alert", [#("channel", "ntfy")])
  let log = action.new("Log", [#("level", "info")])

  let actions = [
    action.for_variant("Critical", [alert]),
    action.for_variant("Ignore", [log]),
  ]

  let assert Ok(obs) = observer.new("security-scanner", [critical, ignore], actions)
  obs
}

pub fn observer_new_valid_test() {
  let obs = sample_observer()
  assert obs.id == "security-scanner"
  assert list.length(obs.decisions) == 2
  assert list.length(obs.actions) == 2
  assert string.length(obs.sha) == 64
}

pub fn observer_new_missing_actions_fails_test() {
  let critical = decision.variant("Critical")
  let ignore = decision.variant("Ignore")

  // Only provide actions for Critical, not Ignore
  let alert = action.new("Alert", [#("channel", "ntfy")])
  let actions = [action.for_variant("Critical", [alert])]

  let result = observer.new("incomplete", [critical, ignore], actions)
  let assert Error(observer.MissingActions(missing)) = result
  assert missing == ["Ignore"]
}

pub fn observer_is_exhaustive_test() {
  let obs = sample_observer()
  assert observer.is_exhaustive(obs)
}

pub fn observer_decision_variants_test() {
  let obs = sample_observer()
  let variants = observer.decision_variants(obs)
  assert variants == ["Critical", "Ignore"]
}

pub fn observer_action_targets_test() {
  let obs = sample_observer()
  let targets = observer.action_targets(obs)
  assert targets == ["Alert", "Log"]
}

pub fn observer_actions_for_found_test() {
  let obs = sample_observer()
  let assert Ok(actions) = observer.actions_for(obs, "Critical")
  assert list.length(actions) == 1
  let assert [alert] = actions
  assert alert.target == "Alert"
}

pub fn observer_actions_for_not_found_test() {
  let obs = sample_observer()
  assert observer.actions_for(obs, "NonExistent") == Error(Nil)
}

pub fn observer_identical_hash_equal_test() {
  let a = sample_observer()
  let b = sample_observer()
  assert a.sha == b.sha
}

// ---------------------------------------------------------------------------
// Action dispatch
// ---------------------------------------------------------------------------

pub fn dispatch_single_decision_test() {
  let obs = sample_observer()
  let critical = decision.variant("Critical")
  let assert Ok(actions) = action.dispatch(obs, critical)
  assert list.length(actions) == 1
  let assert [alert] = actions
  assert alert.target == "Alert"
}

pub fn dispatch_returns_error_for_unknown_variant_test() {
  let obs = sample_observer()
  let unknown = decision.variant("Unknown")
  assert action.dispatch(obs, unknown) == Error(Nil)
}

pub fn dispatch_all_test() {
  let obs = sample_observer()
  let decisions = [
    decision.variant("Critical"),
    decision.variant("Ignore"),
  ]
  let actions = action.dispatch_all(obs, decisions)
  assert list.length(actions) == 2
  let targets = list.map(actions, fn(a) { a.target })
  assert targets == ["Alert", "Log"]
}

pub fn total_actions_test() {
  let obs = sample_observer()
  assert action.total_actions(obs) == 2
}

// ---------------------------------------------------------------------------
// Tree: full tree
// ---------------------------------------------------------------------------

pub fn tree_constructs_test() {
  let observable = bias.Observable(sha: "commit-abc", kind: "git.commit", source: "gestalt")
  let obs = sample_observer()
  let tree = bias.Tree(sha: "", observable: observable, observers: [obs])
  assert tree.observable.kind == "git.commit"
  assert list.length(tree.observers) == 1
}

pub fn tree_hash_is_sha256_test() {
  let observable = bias.Observable(sha: "commit-abc", kind: "git.commit", source: "gestalt")
  let obs = sample_observer()
  let tree = bias.Tree(sha: "", observable: observable, observers: [obs])
  let h = bias.hash_tree(tree)
  assert string.length(h) == 64
}

pub fn tree_identical_hash_equal_test() {
  let observable = bias.Observable(sha: "commit-abc", kind: "git.commit", source: "gestalt")
  let obs = sample_observer()
  let tree_a = bias.Tree(sha: "", observable: observable, observers: [obs])
  let tree_b = bias.Tree(sha: "", observable: observable, observers: [obs])
  assert bias.hash_tree(tree_a) == bias.hash_tree(tree_b)
}

pub fn tree_different_observable_hash_different_test() {
  let obs = sample_observer()
  let tree_a = bias.Tree(
    sha: "",
    observable: bias.Observable(sha: "aaa", kind: "git.commit", source: "repo"),
    observers: [obs],
  )
  let tree_b = bias.Tree(
    sha: "",
    observable: bias.Observable(sha: "bbb", kind: "git.commit", source: "repo"),
    observers: [obs],
  )
  assert bias.hash_tree(tree_a) != bias.hash_tree(tree_b)
}

pub fn tree_different_observers_hash_different_test() {
  let observable = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")

  // Observer 1: Critical + Ignore
  let obs1 = sample_observer()

  // Observer 2: different decisions
  let pass = decision.variant("Pass")
  let fail = decision.variant("Fail")
  let noop = action.new("Noop", [])
  let retry = action.new("Retry", [])
  let assert Ok(obs2) = observer.new(
    "health-check",
    [pass, fail],
    [action.for_variant("Pass", [noop]), action.for_variant("Fail", [retry])],
  )

  let tree_a = bias.Tree(sha: "", observable: observable, observers: [obs1])
  let tree_b = bias.Tree(sha: "", observable: observable, observers: [obs2])
  assert bias.hash_tree(tree_a) != bias.hash_tree(tree_b)
}

// ---------------------------------------------------------------------------
// Serialization: deterministic canonical form
// ---------------------------------------------------------------------------

pub fn observable_serializes_deterministically_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let s1 = bias.serialize_observable(obs)
  let s2 = bias.serialize_observable(obs)
  assert s1 == s2
  assert s1 == "Observable(git.commit, repo, abc)"
}

pub fn decision_serializes_deterministically_test() {
  let dec = decision.new("Critical", [#("severity", "high")])
  let s1 = bias.serialize_decision(dec)
  let s2 = bias.serialize_decision(dec)
  assert s1 == s2
}

pub fn action_serializes_deterministically_test() {
  let act = action.new("Alert", [#("channel", "ntfy")])
  let s1 = bias.serialize_action(act)
  let s2 = bias.serialize_action(act)
  assert s1 == s2
  assert s1 == "Action(Alert, config[channel=ntfy])"
}

// ---------------------------------------------------------------------------
// Integration: full pipeline
// ---------------------------------------------------------------------------

/// End-to-end: observable -> observer -> decide -> dispatch -> actions.
/// This is the complete loop.
pub fn full_pipeline_test() {
  // 1. Observable: a git commit
  let observable = bias.Observable(
    sha: "a1b2c3",
    kind: "git.commit",
    source: "gestalt",
  )

  // 2. Observer with decisions and exhaustive actions
  let obs = sample_observer()

  // 3. Decide: the observer looks at the observable and decides "Critical"
  let decisions = observer.observe(obs, observable, fn(_obs) {
    [decision.variant("Critical")]
  })

  // 4. Dispatch: get the actions for the decisions
  let actions = action.dispatch_all(obs, decisions)

  // 5. Verify: one action fires — Alert
  assert list.length(actions) == 1
  let assert [alert] = actions
  assert alert.target == "Alert"
  assert action.get_config(alert, "channel") == Ok("ntfy")
}

/// Multi-observer tree: two observers see the same observable differently.
pub fn multi_observer_pipeline_test() {
  let observable = bias.Observable(
    sha: "commit-xyz",
    kind: "git.commit",
    source: "gestalt",
  )

  // Observer 1: security scanner
  let scanner = sample_observer()

  // Observer 2: health checker
  let pass = decision.variant("Pass")
  let fail = decision.variant("Fail")
  let noop = action.new("Noop", [])
  let retry = action.new("Retry", [#("attempts", "3")])
  let assert Ok(health) = observer.new(
    "health-check",
    [pass, fail],
    [action.for_variant("Pass", [noop]), action.for_variant("Fail", [retry])],
  )

  // Build tree
  let tree = bias.Tree(
    sha: "",
    observable: observable,
    observers: [scanner, health],
  )

  // Each observer decides independently
  let scanner_decisions = observer.observe(scanner, tree.observable, fn(_) {
    [decision.variant("Ignore")]
  })
  let health_decisions = observer.observe(health, tree.observable, fn(_) {
    [decision.variant("Fail")]
  })

  // Dispatch independently
  let scanner_actions = action.dispatch_all(scanner, scanner_decisions)
  let health_actions = action.dispatch_all(health, health_decisions)

  // Scanner decided Ignore -> Log
  assert list.length(scanner_actions) == 1
  let assert [log] = scanner_actions
  assert log.target == "Log"

  // Health decided Fail -> Retry
  assert list.length(health_actions) == 1
  let assert [retry_action] = health_actions
  assert retry_action.target == "Retry"
  assert action.get_config(retry_action, "attempts") == Ok("3")

  // Tree is hashable
  let h = bias.hash_tree(tree)
  assert string.length(h) == 64
}
