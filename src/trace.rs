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
    Trace {
        step,
        input: input.to_string(),
        output,
        nested,
    }
}

/// Is this trace's output Ok?
pub fn is_ok(trace: &Trace) -> bool {
    trace.output.is_ok()
}

/// Is this trace's output an Error?
pub fn is_error(trace: &Trace) -> bool {
    trace.output.is_err()
}

/// Extract the Result from a trace.
pub fn get_result(trace: &Trace) -> &Result<String, TraceError> {
    &trace.output
}

/// Find root causes: leaf error traces with no nested traces.
pub fn root_causes(trace: &Trace) -> Vec<&Trace> {
    find(trace, &|t| is_error(t) && t.nested.is_empty())
}

/// Recursively find all traces matching a predicate.
pub fn find<'a>(trace: &'a Trace, predicate: &dyn Fn(&Trace) -> bool) -> Vec<&'a Trace> {
    let mut results = Vec::new();
    if predicate(trace) {
        results.push(trace);
    }
    for nested in &trace.nested {
        results.extend(find(nested, predicate));
    }
    results
}

/// Fold over the trace and all nested traces.
pub fn reduce<A, F>(trace: &Trace, acc: A, fun: &F) -> A
where
    F: Fn(&Trace, A) -> A,
{
    let new_acc = fun(trace, acc);
    trace.nested.iter().fold(new_acc, |a, t| reduce(t, a, fun))
}

/// Serialize a Step to canonical form.
pub fn serialize_step(step: &Step) -> String {
    match step {
        Step::Observe(obs) => format!("Observe({})", observable::serialize(obs)),
        Step::Decide {
            observer_id,
            observable_sha,
        } => format!("Decide({}, {})", observer_id, observable_sha),
        Step::Act {
            action: act,
            decision_variant,
        } => format!(
            "Act({}, {})",
            action::serialize_action(act),
            decision_variant
        ),
    }
}

/// Serialize a TraceError to canonical form.
pub fn serialize_error(err: &TraceError) -> String {
    match err {
        TraceError::ObservationFailed(reason) => {
            format!("ObservationFailed({})", reason)
        }
        TraceError::DecisionFailed {
            observer_id,
            reason,
        } => format!("DecisionFailed({}, {})", observer_id, reason),
        TraceError::ActionFailed { target, reason } => {
            format!("ActionFailed({}, {})", target, reason)
        }
        TraceError::ExhaustivenessGap {
            observer_id,
            variant,
        } => format!("ExhaustivenessGap({}, {})", observer_id, variant),
    }
}

/// Serialize a Trace to deterministic canonical form.
pub fn serialize_trace(trace: &Trace) -> String {
    let output_str = match &trace.output {
        Ok(sha) => format!("Ok({})", sha),
        Err(err) => format!("Error({})", serialize_error(err)),
    };
    let nested_str: Vec<String> = trace.nested.iter().map(serialize_trace).collect();
    format!(
        "Trace({}, {}, {}, [{}])",
        serialize_step(&trace.step),
        trace.input,
        output_str,
        nested_str.join(", ")
    )
}

/// Content-address a trace. Same execution = same hash.
pub fn hash_trace(trace: &Trace) -> Sha {
    sha::hash(&serialize_trace(trace))
}
