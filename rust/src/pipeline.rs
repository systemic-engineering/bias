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
    todo!("implement Pipeline construction")
}

/// Add a step to the end of a pipeline.
pub fn add_step(pipeline: Pipeline, step: PipelineStep) -> Pipeline {
    todo!("implement add_step")
}

/// Chain two pipelines together. Merges steps; takes first non-empty name.
pub fn chain(a: Pipeline, b: Pipeline) -> Pipeline {
    todo!("implement chain")
}

/// Execute a full tree and return a nested trace tree.
pub fn run_tree<F>(tree: &Tree, data: &str, decide_fn: F) -> Trace
where
    F: Fn(&Observer, &Observable) -> Result<Vec<Decision>, String>,
{
    todo!("implement run_tree")
}
