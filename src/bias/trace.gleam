/// Trace: execution record for pipeline steps.
///
/// Every step -- observe, decide, act -- produces a trace recording:
/// - What step executed
/// - What went in
/// - What came out (Result: SHA or error)
/// - What nested operations occurred
///
/// Traces are content-addressed. Same execution = same hash.
/// Ported from Babel.Trace (Elixir) to Gleam.

import bias.{type Action, type Observable}
import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A trace records what happened during one step of execution.
pub type Trace {
  Trace(
    step: Step,
    input: String,
    output: Result(String, TraceError),
    nested: List(Trace),
  )
}

/// What kind of step produced this trace.
pub type Step {
  Observe(observable: Observable)
  Decide(observer_id: String, observable_sha: String)
  Act(action: Action, decision_variant: String)
}

/// What went wrong during execution.
pub type TraceError {
  ObservationFailed(reason: String)
  DecisionFailed(observer_id: String, reason: String)
  ActionFailed(target: String, reason: String)
  ExhaustivenessGap(observer_id: String, variant: String)
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

/// Create a new trace.
pub fn new(
  step: Step,
  input: String,
  output: Result(String, TraceError),
  nested: List(Trace),
) -> Trace {
  Trace(step: step, input: input, output: output, nested: nested)
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/// Is this trace's output Ok?
pub fn is_ok(trace: Trace) -> Bool {
  case trace.output {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Is this trace's output an Error?
pub fn is_error(trace: Trace) -> Bool {
  case trace.output {
    Ok(_) -> False
    Error(_) -> True
  }
}

/// Extract the Result from a trace.
pub fn get_result(trace: Trace) -> Result(String, TraceError) {
  trace.output
}

// ---------------------------------------------------------------------------
// Tree operations -- from Babel.Trace
// ---------------------------------------------------------------------------

/// Find root causes: leaf error traces with no nested traces.
/// Mirrors Babel.Trace.root_causes/1.
pub fn root_causes(trace: Trace) -> List(Trace) {
  find(trace, fn(t) { is_error(t) && list.is_empty(t.nested) })
}

/// Recursively find all traces matching a predicate.
/// Mirrors Babel.Trace.find/2 (function variant).
pub fn find(trace: Trace, predicate: fn(Trace) -> Bool) -> List(Trace) {
  let self_matches = case predicate(trace) {
    True -> [trace]
    False -> []
  }
  let nested_matches =
    trace.nested
    |> list.flat_map(fn(t) { find(t, predicate) })
  list.append(self_matches, nested_matches)
}

/// Fold over the trace and all nested traces.
/// Mirrors Babel.Trace.reduce/3.
pub fn reduce(trace: Trace, acc: a, fun: fn(Trace, a) -> a) -> a {
  let new_acc = fun(trace, acc)
  list.fold(trace.nested, new_acc, fn(a, t) { reduce(t, a, fun) })
}

// ---------------------------------------------------------------------------
// Serialization -- deterministic canonical form
// ---------------------------------------------------------------------------

/// Serialize a Step to canonical form.
pub fn serialize_step(step: Step) -> String {
  case step {
    Observe(obs) -> "Observe(" <> bias.serialize_observable(obs) <> ")"
    Decide(id, sha) -> "Decide(" <> id <> ", " <> sha <> ")"
    Act(act, variant) ->
      "Act(" <> bias.serialize_action(act) <> ", " <> variant <> ")"
  }
}

/// Serialize a TraceError to canonical form.
pub fn serialize_error(err: TraceError) -> String {
  case err {
    ObservationFailed(reason) -> "ObservationFailed(" <> reason <> ")"
    DecisionFailed(id, reason) ->
      "DecisionFailed(" <> id <> ", " <> reason <> ")"
    ActionFailed(target, reason) ->
      "ActionFailed(" <> target <> ", " <> reason <> ")"
    ExhaustivenessGap(id, variant) ->
      "ExhaustivenessGap(" <> id <> ", " <> variant <> ")"
  }
}

/// Serialize a Trace to deterministic canonical form.
pub fn serialize_trace(trace: Trace) -> String {
  let output_str = case trace.output {
    Ok(sha) -> "Ok(" <> sha <> ")"
    Error(err) -> "Error(" <> serialize_error(err) <> ")"
  }
  let nested_str =
    trace.nested
    |> list.map(serialize_trace)
    |> string.join(", ")
  "Trace("
  <> serialize_step(trace.step)
  <> ", "
  <> trace.input
  <> ", "
  <> output_str
  <> ", ["
  <> nested_str
  <> "])"
}

// ---------------------------------------------------------------------------
// Content addressing
// ---------------------------------------------------------------------------

/// Content-address a trace. Same execution = same hash.
pub fn hash_trace(trace: Trace) -> String {
  trace
  |> serialize_trace
  |> bias.hash
}
