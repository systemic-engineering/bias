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

pub fn is_ok(trace: Trace) -> Bool {
  todo
}

pub fn is_error(trace: Trace) -> Bool {
  todo
}

pub fn get_result(trace: Trace) -> Result(String, TraceError) {
  todo
}

// ---------------------------------------------------------------------------
// Tree operations
// ---------------------------------------------------------------------------

pub fn root_causes(trace: Trace) -> List(Trace) {
  todo
}

pub fn find(trace: Trace, predicate: fn(Trace) -> Bool) -> List(Trace) {
  todo
}

pub fn reduce(trace: Trace, acc: a, fun: fn(Trace, a) -> a) -> a {
  todo
}

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------

pub fn serialize_step(step: Step) -> String {
  todo
}

pub fn serialize_error(err: TraceError) -> String {
  todo
}

pub fn serialize_trace(trace: Trace) -> String {
  todo
}

// ---------------------------------------------------------------------------
// Content addressing
// ---------------------------------------------------------------------------

pub fn hash_trace(trace: Trace) -> String {
  todo
}
