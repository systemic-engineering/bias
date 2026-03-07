use crate::action::{self, Action, DecisionActions};
use crate::decision::Decision;
use crate::observable::{self, Observable};
use crate::observer::Observer;
use crate::trace::{self, Trace};
use crate::tree::Tree;

/// A named pipeline of execution steps.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pipeline {
    pub name: String,
    pub steps: Vec<PipelineStep>,
}

/// A step in a pipeline.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PipelineStep {
    Observe(Observable),
    Decide(Observer),
    Act(Vec<DecisionActions>),
}

/// Create a new empty pipeline.
pub fn new(name: &str) -> Pipeline {
    Pipeline {
        name: name.to_string(),
        steps: Vec::new(),
    }
}

/// Add a step to the end of a pipeline.
pub fn add_step(mut pipeline: Pipeline, step: PipelineStep) -> Pipeline {
    pipeline.steps.push(step);
    pipeline
}

/// Chain two pipelines together. Merges steps; takes first non-empty name.
pub fn chain(a: Pipeline, b: Pipeline) -> Pipeline {
    let name = if a.name.is_empty() { b.name } else { a.name };
    let mut steps = a.steps;
    steps.extend(b.steps);
    Pipeline { name, steps }
}

/// Execute a full tree and return a nested trace tree.
pub fn run_tree<F>(tree: &Tree, data: &str, decide_fn: F) -> Trace
where
    F: Fn(&Observer, &Observable) -> Result<Vec<Decision>, String>,
{
    let observable = &tree.observable;
    let obs_sha = observable::hash(observable).0;

    let observer_traces: Vec<Trace> = tree
        .observers
        .iter()
        .map(|obs| run_observer(obs, observable, &obs_sha, &decide_fn))
        .collect();

    let all_ok = observer_traces.iter().all(trace::is_ok);

    let output = if all_ok {
        Ok(obs_sha.clone())
    } else {
        Err(trace::TraceError::ObservationFailed(
            "one or more observers failed".to_string(),
        ))
    };

    trace::new(
        trace::Step::Observe(observable.clone()),
        data,
        output,
        observer_traces,
    )
}

fn run_observer<F>(obs: &Observer, observable: &Observable, obs_sha: &str, decide_fn: &F) -> Trace
where
    F: Fn(&Observer, &Observable) -> Result<Vec<Decision>, String>,
{
    match decide_fn(obs, observable) {
        Ok(decisions) => {
            let act_traces: Vec<Trace> = decisions
                .iter()
                .flat_map(|dec| run_actions(obs, dec))
                .collect();

            let all_ok = act_traces.iter().all(trace::is_ok);

            let output = if all_ok {
                let shas: Vec<String> = decisions.iter().map(|d| d.sha.clone()).collect();
                Ok(shas.join(","))
            } else {
                Err(trace::TraceError::ActionFailed {
                    target: obs.id.clone(),
                    reason: "one or more actions failed".to_string(),
                })
            };

            trace::new(
                trace::Step::Decide {
                    observer_id: obs.id.clone(),
                    observable_sha: obs_sha.to_string(),
                },
                obs_sha,
                output,
                act_traces,
            )
        }
        Err(reason) => trace::new(
            trace::Step::Decide {
                observer_id: obs.id.clone(),
                observable_sha: obs_sha.to_string(),
            },
            obs_sha,
            Err(trace::TraceError::DecisionFailed {
                observer_id: obs.id.clone(),
                reason,
            }),
            vec![],
        ),
    }
}

fn run_actions(obs: &Observer, dec: &Decision) -> Vec<Trace> {
    match action::dispatch(obs, dec) {
        Some(actions) => actions
            .iter()
            .map(|act| {
                trace::new(
                    trace::Step::Act {
                        action: act.clone(),
                        decision_variant: dec.variant.clone(),
                    },
                    &dec.sha,
                    Ok(act.sha.clone()),
                    vec![],
                )
            })
            .collect(),
        None => vec![trace::new(
            trace::Step::Act {
                action: Action {
                    sha: String::new(),
                    target: "unknown".to_string(),
                    config: vec![],
                },
                decision_variant: dec.variant.clone(),
            },
            &dec.sha,
            Err(trace::TraceError::ExhaustivenessGap {
                observer_id: obs.id.clone(),
                variant: dec.variant.clone(),
            }),
            vec![],
        )],
    }
}
