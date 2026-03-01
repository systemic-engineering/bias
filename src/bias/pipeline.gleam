/// Pipeline: tree executor with full tracing.
///
/// Executes a tree (observable -> observers -> decisions -> actions)
/// and produces a nested trace tree recording what happened at every step.
///
/// The trace tree mirrors the tree structure. Content-addressed:
/// same tree + same decide function + same data = same trace hash.
///
/// Inspired by Babel.Pipeline (Elixir). Key difference: traces are
/// content-addressed for git-native storage and diffing.

import bias.{
  type Decision, type DecisionActions, type Observable, type Observer, type Tree,
}
import bias/action
import bias/trace.{type Trace}
import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Pipeline type
// ---------------------------------------------------------------------------

pub type Pipeline {
  Pipeline(name: String, steps: List(PipelineStep))
}

pub type PipelineStep {
  PipelineObserve(Observable)
  PipelineDecide(Observer)
  PipelineAct(List(DecisionActions))
}

/// Create a new empty pipeline.
pub fn new(name: String) -> Pipeline {
  Pipeline(name: name, steps: [])
}

pub fn add_step(pipeline: Pipeline, step: PipelineStep) -> Pipeline {
  todo
}

pub fn chain(a: Pipeline, b: Pipeline) -> Pipeline {
  todo
}

// ---------------------------------------------------------------------------
// Tree execution
// ---------------------------------------------------------------------------

pub fn run_tree(
  tree: Tree,
  data: String,
  decide_fn: fn(Observer, Observable) -> Result(List(Decision), String),
) -> Trace {
  todo
}
