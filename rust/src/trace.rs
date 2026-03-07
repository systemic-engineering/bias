use crate::action::{self, Action};
use crate::observable::{self, Observable};
use crate::sha::{self, Sha};

/// A trace records what happened during one step of execution.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Trace {
    pub step: Step,
    pub input: String,
    pub output: Result<String, TraceError>,
    pub nested: Vec<Trace>,
}

/// What kind of step produced this trace.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Step {
    Observe(Observable),
    Decide {
        observer_id: String,
        observable_sha: String,
    },
    Act {
        action: Action,
        decision_variant: String,
    },
}

/// What went wrong during execution.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TraceError {
    ObservationFailed(String),
    DecisionFailed {
        observer_id: String,
        reason: String,
    },
    ActionFailed {
        target: String,
        reason: String,
    },
    ExhaustivenessGap {
        observer_id: String,
        variant: String,
    },
}

/// Create a new trace.
pub fn new(
    step: Step,
    input: &str,
    output: Result<String, TraceError>,
    nested: Vec<Trace>,
) -> Trace {
    todo!("implement Trace construction")
}

/// Is this trace's output Ok?
pub fn is_ok(trace: &Trace) -> bool {
    todo!("implement is_ok")
}

/// Is this trace's output an Error?
pub fn is_error(trace: &Trace) -> bool {
    todo!("implement is_error")
}

/// Extract the Result from a trace.
pub fn get_result(trace: &Trace) -> &Result<String, TraceError> {
    todo!("implement get_result")
}

/// Find root causes: leaf error traces with no nested traces.
pub fn root_causes(trace: &Trace) -> Vec<&Trace> {
    todo!("implement root_causes")
}

/// Recursively find all traces matching a predicate.
pub fn find<'a>(trace: &'a Trace, predicate: &dyn Fn(&Trace) -> bool) -> Vec<&'a Trace> {
    todo!("implement find")
}

/// Fold over the trace and all nested traces.
pub fn reduce<A, F>(trace: &Trace, acc: A, fun: &F) -> A
where
    F: Fn(&Trace, A) -> A,
{
    todo!("implement reduce")
}

/// Serialize a Step to canonical form.
pub fn serialize_step(step: &Step) -> String {
    todo!("implement Step serialization")
}

/// Serialize a TraceError to canonical form.
pub fn serialize_error(err: &TraceError) -> String {
    todo!("implement TraceError serialization")
}

/// Serialize a Trace to deterministic canonical form.
pub fn serialize_trace(trace: &Trace) -> String {
    todo!("implement Trace serialization")
}

/// Content-address a trace. Same execution = same hash.
pub fn hash_trace(trace: &Trace) -> Sha {
    todo!("implement Trace hashing")
}
