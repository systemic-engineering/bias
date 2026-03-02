# Modules

Bias is seven modules. The core module defines types. Six sub-modules provide operations. They compose in one direction: types flow outward, operations build on each other.

```
bias                core types, serialization, hashing
  bias/decision     building decisions, variant queries, grouping
  bias/action       building actions, dispatch, config queries
  bias/observer     construction with exhaustiveness validation, observe
  bias/trace        execution records, tree navigation, content-addressed traces
  bias/context      pipeline execution state, metadata, history
  bias/pipeline     Pipeline type, run_tree orchestrator
```

## bias (core)

Source: `src/bias.gleam`

Everything starts here. Types, serialization, and hashing.

**Types**: `Observable`, `Decision`, `Action`, `Observer`, `DecisionActions`, `Tree`. Six types. Each carries a `sha` field for content addressing.

**Serialization**: `serialize_observable`, `serialize_decision`, `serialize_action`, `serialize_decision_actions`, `serialize_observer`, `serialize_tree`. Each produces a deterministic canonical string. The format is human-readable: `Observable(git.commit, repo, abc)`, `Action(Alert, config[channel=ntfy])`. Pairs serialize as `key=value`. Lists use `, ` separators. Observers separate decisions and action mappings with ` | `.

**Hashing**: `hash` takes a string, returns its SHA-256 as a hex string. `hash_observable`, `hash_decision`, `hash_action`, `hash_observer`, `hash_tree` serialize the type canonically and SHA-256 hash the result.

The Erlang FFI (`src/bias_ffi.erl`) provides the SHA-256 implementation via OTP's `crypto` module.

## bias/decision

Source: `src/bias/decision.gleam`

Building and querying decisions. A decision is the transformation result -- what an observer produces after processing an observable.

**Construction**: `new(variant, payload)` builds a Decision with a computed content hash. `variant(name)` is shorthand for a decision with no payload -- for simple variant-only decisions like "Ignore" or "Pass".

**Queries**: `variant_name` extracts the variant string. `get_payload(decision, key)` looks up a payload value by key, returning `Ok(value)` or `Error(Nil)`.

**Comparison**: `same_variant(a, b)` checks if two decisions have the same variant regardless of payload. `identical(a, b)` checks content identity via SHA.

**Collection operations**: `variant_names(decisions)` returns unique variant names from a list. `group_by_variant(decisions)` groups a list of decisions by variant, returning `List(#(String, List(Decision)))`.

## bias/action

Source: `src/bias/action.gleam`

Building and dispatching actions. Actions are the exhaustive pattern match on the decision space.

**Construction**: `new(target, config)` builds an Action with a computed content hash. `for_variant(variant, actions)` builds a `DecisionActions` mapping -- links a decision variant name to its list of actions.

**Dispatch**: `dispatch(observer, decision)` returns the actions for a specific decision, looking up by variant name. Returns `Ok(actions)` or `Error(Nil)`. `dispatch_all(observer, decisions)` dispatches a list of decisions and returns all actions in order, silently skipping any missing mappings.

**Queries**: `get_config(action, key)` looks up a config value by key. `identical(a, b)` checks content identity via SHA. `total_actions(observer)` counts the total number of actions across all decision mappings.

## bias/observer

Source: `src/bias/observer.gleam`

Construction with exhaustiveness validation. The observer is the decision-making entity.

**Construction**: `new(id, decisions, actions)` builds an Observer. Returns `Ok(observer)` if every decision variant has a corresponding action mapping. Returns `Error(MissingActions(variants))` if any variant lacks actions. The SHA is computed after validation passes.

**Error types**: `MissingActions(variants)` -- decision variants without action mappings. `OrphanActions(variants)` -- action mappings that reference non-existent decision variants.

**Observation**: `observe(observer, observable, decide)` applies the observer to an observable. The caller provides the `decide` function -- a `fn(Observable) -> List(Decision)` that encodes the observer's subjectivity. The observer provides the structure. The caller provides the judgment.

**Queries**: `actions_for(observer, variant)` looks up actions by variant name. `decision_variants(observer)` returns all variant names. `action_targets(observer)` returns all action target names across all decisions. `is_exhaustive(observer)` checks both that every variant has actions and that no orphan action mappings exist.

## bias/trace

Source: `src/bias/trace.gleam`

Execution records. Every step of a pipeline -- observe, decide, act -- produces a trace. Traces nest. The trace tree mirrors the bias tree.

**Types**:

```gleam
pub type Trace {
  Trace(
    step: Step,
    input: String,
    output: Result(String, TraceError),
    nested: List(Trace),
  )
}

pub type Step {
  Observe(observable: Observable)
  Decide(observer_id: String, observable_sha: String)
  Act(action: Action, decision_variant: String)
}

pub type TraceError {
  ObservationFailed(reason: String)
  DecisionFailed(observer_id: String, reason: String)
  ActionFailed(target: String, reason: String)
  ExhaustivenessGap(observer_id: String, variant: String)
}
```

A `Trace` records what happened during one step: what step ran (`Step`), what went in (`input`), what came out (`output` as `Result(String, TraceError)`), and what nested operations occurred.

`Step` is a tagged union: `Observe`, `Decide`, or `Act`. Each carries context about what it was operating on.

`TraceError` covers four failure modes: observation failure, decision failure, action failure, and exhaustiveness gaps (a decision variant with no action mapping at runtime).

**Construction**: `new(step, input, output, nested)` creates a trace.

**Queries**: `is_ok`, `is_error`, `get_result` -- basic output inspection.

**Tree operations**: `root_causes(trace)` finds leaf error traces with no nested children -- the bottom of the failure chain. `find(trace, predicate)` recursively collects all traces matching a predicate. `reduce(trace, acc, fun)` folds over the trace tree depth-first.

**Serialization and hashing**: `serialize_step`, `serialize_error`, `serialize_trace` produce deterministic canonical forms. `hash_trace` content-addresses the trace. Same execution, same hash.

Ported from Babel.Trace (Elixir).

## bias/context

Source: `src/bias/context.gleam`

Pipeline execution state. Carries data through execution, accumulates trace history, holds metadata.

```gleam
pub type Context {
  Context(
    data: String,
    history: List(Trace),
    metadata: List(#(String, String)),
  )
}
```

**Construction**: `new(data)` creates a fresh context. `with_history(ctx, traces)` appends traces. `with_metadata(ctx, key, value)` adds a metadata pair.

**Queries**: `get_metadata(ctx, key)` looks up a metadata value.

**Advancement**: `advance(ctx, new_data, trace)` updates the context's data and appends the trace to history. This is the step-forward operation -- after each pipeline step, the context advances.

Ported from Babel.Context (Elixir).

## bias/pipeline

Source: `src/bias/pipeline.gleam`

The orchestrator. Executes a tree and produces a nested trace tree recording what happened at every step.

**Pipeline type**:

```gleam
pub type Pipeline {
  Pipeline(name: String, steps: List(PipelineStep))
}

pub type PipelineStep {
  PipelineObserve(Observable)
  PipelineDecide(Observer)
  PipelineAct(List(DecisionActions))
}
```

`new(name)` creates an empty pipeline. `add_step` appends a step. `chain(a, b)` merges two pipelines, taking the first non-empty name.

**Tree execution**: `run_tree(tree, data, decide_fn)` is the core operation. It takes a `Tree`, raw input data, and a decision function `fn(Observer, Observable) -> Result(List(Decision), String)`.

The execution flow:
1. For each observer in the tree, call the decide function with that observer and the observable.
2. For each decision produced, dispatch the actions through the observer's action map.
3. Build nested traces mirroring the tree structure: root `Observe` trace contains `Decide` traces, each containing `Act` traces.

If a decision function returns `Error`, the trace records `DecisionFailed`. If a decision variant has no action mapping at runtime (an exhaustiveness gap), the trace records `ExhaustivenessGap`. If any observer fails, the root trace is marked as error.

The trace tree is content-addressed. Same tree, same decide function, same data produces the same trace hash.

## How They Compose

A typical workflow:

1. **Build decisions** with `bias/decision`.
2. **Build actions** with `bias/action`, mapping variants to action lists.
3. **Construct an observer** with `bias/observer`, which validates exhaustiveness.
4. **Build a tree** with the core `bias` types.
5. **Execute** with `bias/pipeline.run_tree`, getting a traced execution.
6. **Inspect** the trace with `bias/trace` operations.

The modules don't form a deep dependency chain. Decision and action are independent. Observer uses both. Trace is independent of all three. Context uses trace. Pipeline uses everything. You can use observer and action without pipeline. You can use trace without pipeline. They compose but don't require each other.
