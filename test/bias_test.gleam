/// Bias tests: Observe, Decide, Act.
///
/// TDD bottom-up: construct trees by hand,
/// verify they hash correctly, validate exhaustiveness,
/// and test the dispatch pipeline.

import bias
import bias/action
import bias/context
import bias/decision
import bias/observer
import bias/pipeline
import bias/trace
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

// ---------------------------------------------------------------------------
// Trace: execution records
// ---------------------------------------------------------------------------

pub fn trace_new_ok_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let t = trace.new(trace.Observe(obs), "input-data", Ok("abc-hash"), [])
  assert trace.is_ok(t)
  assert !trace.is_error(t)
  assert t.input == "input-data"
  assert t.output == Ok("abc-hash")
  assert t.nested == []
}

pub fn trace_new_error_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let err = trace.ObservationFailed("timeout")
  let t = trace.new(trace.Observe(obs), "input-data", Error(err), [])
  assert trace.is_error(t)
  assert !trace.is_ok(t)
  assert t.output == Error(trace.ObservationFailed("timeout"))
}

pub fn trace_get_result_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let t = trace.new(trace.Observe(obs), "data", Ok("result-sha"), [])
  assert trace.get_result(t) == Ok("result-sha")
}

pub fn trace_root_causes_finds_leaf_errors_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")

  // Leaf error trace (no nested)
  let leaf_err = trace.new(
    trace.Act(bias.Action(sha: "a1", target: "Alert", config: []), "Critical"),
    "dec-sha",
    Error(trace.ActionFailed("Alert", "connection refused")),
    [],
  )

  // Middle trace (has nested, is error)
  let middle = trace.new(
    trace.Decide("scanner", "obs-sha"),
    "obs-sha",
    Error(trace.ActionFailed("scanner", "action failed")),
    [leaf_err],
  )

  // Root trace
  let root = trace.new(
    trace.Observe(obs),
    "data",
    Error(trace.ObservationFailed("observer failed")),
    [middle],
  )

  let causes = trace.root_causes(root)
  // Only the leaf error should be a root cause
  assert list.length(causes) == 1
  let assert [cause] = causes
  assert cause.input == "dec-sha"
}

pub fn trace_find_by_predicate_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let act = bias.Action(sha: "a1", target: "Alert", config: [])
  let leaf1 = trace.new(trace.Act(act, "Critical"), "d1", Ok("a1"), [])
  let leaf2 = trace.new(trace.Act(act, "Ignore"), "d2", Ok("a1"), [])
  let parent = trace.new(
    trace.Decide("scanner", "obs"),
    "obs",
    Ok("d1,d2"),
    [leaf1, leaf2],
  )
  let root = trace.new(trace.Observe(obs), "data", Ok("obs"), [parent])

  // Find all Act traces
  let acts = trace.find(root, fn(t) {
    case t.step {
      trace.Act(_, _) -> True
      _ -> False
    }
  })
  assert list.length(acts) == 2
}

pub fn trace_reduce_counts_all_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let act = bias.Action(sha: "a1", target: "Alert", config: [])
  let leaf = trace.new(trace.Act(act, "Critical"), "d1", Ok("a1"), [])
  let parent = trace.new(trace.Decide("scanner", "obs"), "obs", Ok("d1"), [leaf])
  let root = trace.new(trace.Observe(obs), "data", Ok("obs"), [parent])

  // Count all traces: root + parent + leaf = 3
  let count = trace.reduce(root, 0, fn(_, acc) { acc + 1 })
  assert count == 3
}

pub fn trace_serialize_deterministic_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let t = trace.new(trace.Observe(obs), "data", Ok("result"), [])
  let s1 = trace.serialize_trace(t)
  let s2 = trace.serialize_trace(t)
  assert s1 == s2
}

pub fn trace_hash_deterministic_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let t1 = trace.new(trace.Observe(obs), "data", Ok("result"), [])
  let t2 = trace.new(trace.Observe(obs), "data", Ok("result"), [])
  assert trace.hash_trace(t1) == trace.hash_trace(t2)
  assert string.length(trace.hash_trace(t1)) == 64
}

pub fn trace_different_input_hash_different_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let t1 = trace.new(trace.Observe(obs), "data-1", Ok("result"), [])
  let t2 = trace.new(trace.Observe(obs), "data-2", Ok("result"), [])
  assert trace.hash_trace(t1) != trace.hash_trace(t2)
}

// ---------------------------------------------------------------------------
// Context: execution state
// ---------------------------------------------------------------------------

pub fn context_new_test() {
  let ctx = context.new("initial-data")
  assert ctx.data == "initial-data"
  assert ctx.history == []
  assert ctx.metadata == []
}

pub fn context_with_metadata_test() {
  let ctx =
    context.new("data")
    |> context.with_metadata("author", "reed")
    |> context.with_metadata("timestamp", "2026-03-01")
  assert context.get_metadata(ctx, "author") == Ok("reed")
  assert context.get_metadata(ctx, "timestamp") == Ok("2026-03-01")
}

pub fn context_get_metadata_not_found_test() {
  let ctx = context.new("data")
  assert context.get_metadata(ctx, "missing") == Error(Nil)
}

pub fn context_advance_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let t = trace.new(trace.Observe(obs), "old-data", Ok("new-sha"), [])
  let ctx = context.new("old-data")
  let advanced = context.advance(ctx, "new-sha", t)
  assert advanced.data == "new-sha"
  assert list.length(advanced.history) == 1
}

pub fn context_with_history_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let t = trace.new(trace.Observe(obs), "data", Ok("sha"), [])
  let ctx =
    context.new("data")
    |> context.with_history([t])
  assert list.length(ctx.history) == 1
}

// ---------------------------------------------------------------------------
// Pipeline: run_tree -- full execution with tracing
// ---------------------------------------------------------------------------

pub fn run_tree_single_observer_test() {
  let observable = bias.Observable(
    sha: "commit-abc",
    kind: "git.commit",
    source: "bias",
  )
  let obs = sample_observer()
  let tree = bias.Tree(sha: "", observable: observable, observers: [obs])

  let result_trace = pipeline.run_tree(tree, "raw-data", fn(_, _) {
    Ok([decision.variant("Critical")])
  })

  // Root is an Observe trace
  assert trace.is_ok(result_trace)
  // One nested Decide trace
  assert list.length(result_trace.nested) == 1
  let assert [decide_trace] = result_trace.nested
  // Decide trace has one Act trace (Critical -> Alert)
  assert trace.is_ok(decide_trace)
  assert list.length(decide_trace.nested) == 1
  let assert [act_trace] = decide_trace.nested
  assert trace.is_ok(act_trace)
}

pub fn run_tree_multi_observer_test() {
  let observable = bias.Observable(
    sha: "commit-xyz",
    kind: "git.commit",
    source: "bias",
  )

  let scanner = sample_observer()

  let pass = decision.variant("Pass")
  let fail = decision.variant("Fail")
  let noop = action.new("Noop", [])
  let retry = action.new("Retry", [#("attempts", "3")])
  let assert Ok(health) = observer.new(
    "health-check",
    [pass, fail],
    [action.for_variant("Pass", [noop]), action.for_variant("Fail", [retry])],
  )

  let tree = bias.Tree(
    sha: "",
    observable: observable,
    observers: [scanner, health],
  )

  let result_trace = pipeline.run_tree(tree, "raw-data", fn(obs, _) {
    case obs.id {
      "security-scanner" -> Ok([decision.variant("Critical")])
      "health-check" -> Ok([decision.variant("Fail")])
      _ -> Error("unknown observer")
    }
  })

  // Root is Ok (both observers succeed)
  assert trace.is_ok(result_trace)
  // Two nested Decide traces
  assert list.length(result_trace.nested) == 2
}

pub fn run_tree_error_propagation_test() {
  let observable = bias.Observable(
    sha: "abc",
    kind: "git.commit",
    source: "repo",
  )
  let obs = sample_observer()
  let tree = bias.Tree(sha: "", observable: observable, observers: [obs])

  // Decision function fails
  let result_trace = pipeline.run_tree(tree, "data", fn(_, _) {
    Error("decision function crashed")
  })

  // Root should be error
  assert trace.is_error(result_trace)
  // root_causes should find the leaf error
  let causes = trace.root_causes(result_trace)
  assert list.length(causes) == 1
}

pub fn run_tree_trace_nesting_mirrors_tree_test() {
  let observable = bias.Observable(
    sha: "abc",
    kind: "git.commit",
    source: "bias",
  )
  let obs = sample_observer()
  let tree = bias.Tree(sha: "", observable: observable, observers: [obs])

  // Critical has 1 action (Alert), Ignore has 1 action (Log)
  // Decide both variants -> 2 Act traces
  let result_trace = pipeline.run_tree(tree, "data", fn(_, _) {
    Ok([decision.variant("Critical"), decision.variant("Ignore")])
  })

  assert trace.is_ok(result_trace)
  // 1 observer -> 1 Decide trace
  assert list.length(result_trace.nested) == 1
  let assert [decide_trace] = result_trace.nested
  // 2 decisions -> 2 Act traces
  assert list.length(decide_trace.nested) == 2
}

pub fn run_tree_deterministic_hash_test() {
  let observable = bias.Observable(
    sha: "commit-abc",
    kind: "git.commit",
    source: "bias",
  )
  let obs = sample_observer()
  let tree = bias.Tree(sha: "", observable: observable, observers: [obs])

  let decide = fn(_, _) { Ok([decision.variant("Critical")]) }
  let trace1 = pipeline.run_tree(tree, "data", decide)
  let trace2 = pipeline.run_tree(tree, "data", decide)

  // Same tree + same decisions = same trace hash
  assert trace.hash_trace(trace1) == trace.hash_trace(trace2)
}

pub fn run_tree_exhaustiveness_gap_test() {
  let observable = bias.Observable(
    sha: "abc",
    kind: "git.commit",
    source: "repo",
  )
  let obs = sample_observer()
  let tree = bias.Tree(sha: "", observable: observable, observers: [obs])

  // Return a decision variant with no action mapping
  let result_trace = pipeline.run_tree(tree, "data", fn(_, _) {
    Ok([bias.Decision(sha: "fake", variant: "Nonexistent", payload: [])])
  })

  // The Act trace should have an ExhaustivenessGap error
  assert trace.is_error(result_trace)
  let causes = trace.root_causes(result_trace)
  assert list.length(causes) == 1
  let assert [cause] = causes
  assert cause.output
    == Error(trace.ExhaustivenessGap("security-scanner", "Nonexistent"))
}

// ---------------------------------------------------------------------------
// Pipeline: composition
// ---------------------------------------------------------------------------

pub fn pipeline_new_test() {
  let p = pipeline.new("test-pipeline")
  assert p.name == "test-pipeline"
  assert p.steps == []
}

pub fn pipeline_add_step_test() {
  let obs = bias.Observable(sha: "abc", kind: "git.commit", source: "repo")
  let p =
    pipeline.new("test")
    |> pipeline.add_step(pipeline.PipelineObserve(obs))
  assert list.length(p.steps) == 1
}

pub fn pipeline_chain_test() {
  let a = pipeline.new("first")
  let b = pipeline.new("second")
  let chained = pipeline.chain(a, b)
  assert chained.name == "first"
}
