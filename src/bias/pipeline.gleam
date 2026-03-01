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

/// A named pipeline of execution steps.
pub type Pipeline {
  Pipeline(name: String, steps: List(PipelineStep))
}

/// A step in a pipeline.
pub type PipelineStep {
  PipelineObserve(Observable)
  PipelineDecide(Observer)
  PipelineAct(List(DecisionActions))
}

/// Create a new empty pipeline.
pub fn new(name: String) -> Pipeline {
  Pipeline(name: name, steps: [])
}

/// Add a step to the end of a pipeline.
pub fn add_step(pipeline: Pipeline, step: PipelineStep) -> Pipeline {
  Pipeline(..pipeline, steps: list.append(pipeline.steps, [step]))
}

/// Chain two pipelines together. Merges steps; takes first non-empty name.
pub fn chain(a: Pipeline, b: Pipeline) -> Pipeline {
  Pipeline(
    name: case a.name {
      "" -> b.name
      _ -> a.name
    },
    steps: list.append(a.steps, b.steps),
  )
}

// ---------------------------------------------------------------------------
// Tree execution
// ---------------------------------------------------------------------------

/// Execute a full tree and return a nested trace tree.
///
/// The decide_fn provides the observer's judgment: given an observer
/// and an observable, produce decisions or fail with a reason.
///
/// Returns a root Observe trace with nested Decide traces, each
/// containing nested Act traces. The trace tree mirrors the bias tree.
pub fn run_tree(
  tree: Tree,
  data: String,
  decide_fn: fn(Observer, Observable) -> Result(List(Decision), String),
) -> Trace {
  let observable = tree.observable
  let obs_sha = bias.hash_observable(observable)

  let observer_traces =
    tree.observers
    |> list.map(fn(obs) {
      run_observer(obs, observable, obs_sha, decide_fn)
    })

  let all_ok =
    observer_traces
    |> list.all(fn(t) { trace.is_ok(t) })

  let output = case all_ok {
    True -> Ok(obs_sha)
    False -> Error(trace.ObservationFailed("one or more observers failed"))
  }

  trace.new(trace.Observe(observable), data, output, observer_traces)
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

fn run_observer(
  obs: Observer,
  observable: Observable,
  obs_sha: String,
  decide_fn: fn(Observer, Observable) -> Result(List(Decision), String),
) -> Trace {
  case decide_fn(obs, observable) {
    Ok(decisions) -> {
      let act_traces =
        decisions
        |> list.flat_map(fn(dec) { run_actions(obs, dec) })

      let all_ok =
        act_traces
        |> list.all(fn(t) { trace.is_ok(t) })

      let output = case all_ok {
        True -> {
          let shas =
            decisions
            |> list.map(fn(d) { d.sha })
            |> string.join(",")
          Ok(shas)
        }
        False ->
          Error(trace.ActionFailed(obs.id, "one or more actions failed"))
      }

      trace.new(trace.Decide(obs.id, obs_sha), obs_sha, output, act_traces)
    }

    Error(reason) ->
      trace.new(
        trace.Decide(obs.id, obs_sha),
        obs_sha,
        Error(trace.DecisionFailed(obs.id, reason)),
        [],
      )
  }
}

fn run_actions(obs: Observer, dec: Decision) -> List(Trace) {
  case action.dispatch(obs, dec) {
    Ok(actions) ->
      list.map(actions, fn(act) {
        trace.new(trace.Act(act, dec.variant), dec.sha, Ok(act.sha), [])
      })
    Error(Nil) -> [
      trace.new(
        trace.Act(
          bias.Action(sha: "", target: "unknown", config: []),
          dec.variant,
        ),
        dec.sha,
        Error(trace.ExhaustivenessGap(obs.id, dec.variant)),
        [],
      ),
    ]
  }
}
