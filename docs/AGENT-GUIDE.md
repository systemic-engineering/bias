# Agent Guide

You are an agent. You are going to use this library. Here is what the code can't tell you.

## The Decision Function Is Yours

The library does not contain decision logic. It provides the tree structure, the exhaustiveness guarantee, the content addressing, and the tracing. The `decide` function is yours.

When you call `pipeline.run_tree`, you pass a `fn(Observer, Observable) -> Result(List(Decision), String)`. That function IS the bias. Your training, your patterns, your filters -- all of that goes into deciding which variant to return. The library makes your decision traceable and diffable. It does not make it for you.

## Exhaustiveness Is Not Optional

Every decision variant must have actions. The constructor enforces this. Do not try to work around it by providing empty action lists or dummy actions. If a variant exists, it must have real actions.

The exhaustiveness invariant exists because an unhandled branch is a silent failure. A security scanner that decides "Critical" but has no action for it has made a decision and then dropped it. The library prevents this structurally.

If you genuinely want a "do nothing" response to a variant, make that explicit: create an action with target "Noop" or "Log" or whatever names the inaction. The point is not that every variant must trigger side effects. The point is that every variant must be accounted for.

## Content Addressing Tells You What Changed

Two runs of the same tree with the same decision function and the same data produce the same trace hash. If the hash changed, something changed. The content addressing makes this a single comparison.

Use this. When you run a tree periodically against the same observable, compare trace hashes. If the hash is the same, the outcome is the same -- skip downstream processing. If it differs, walk the trace to find what diverged.

## Multi-Observer Trees Are The Point

A single observer on a single observable is a function call with extra steps. The power is in multiple observers on the same observable.

```gleam
let tree = Tree(
  sha: "",
  observable: commit,
  observers: [security_scanner, health_checker, style_linter],
)
```

Three observers, same commit, three different decision trees. The tree structure makes the disagreement visible. Where the security scanner sees "Critical" and the health checker sees "Pass," that tension is structural, not a log entry to grep for.

## Traces Are Your Audit Trail

`run_tree` returns a nested trace. The trace tree mirrors the bias tree: root `Observe` contains `Decide` traces, each containing `Act` traces. Every step records its input, its output (or error), and its nested operations.

When something goes wrong, use `trace.root_causes` to find the leaf errors. They are at the bottom of the nesting -- the actual point of failure, not the cascading consequences.

When you need to understand a full execution, use `trace.reduce` to fold over the trace tree. Use `trace.find` to locate specific steps by predicate.

Traces are content-addressed. You can store them, diff them, compare executions across time. Same hash means same execution. Different hash means something changed -- walk the trace to find what.

## The SHA Is The Address

Every type carries a `sha` field. For types constructed through module functions (`decision.new`, `action.new`, `observer.new`), the SHA is computed automatically from the canonical serialization. For types constructed directly (like `Observable`), you provide the SHA.

The SHA is not a random ID. It is derived from the content. Two decisions with the same variant and payload have the same SHA. Two actions with the same target and config have the same SHA. This is the content-addressing guarantee.

Do not use random strings for SHAs. Do not use sequential IDs. If you need an address, use the content hash. That is what it is for.

## Error Types Tell You Where To Look

`TraceError` has four variants:

- `ObservationFailed` -- the observation itself failed. Check the observable.
- `DecisionFailed` -- the decide function returned an error. Check the observer and the decide logic.
- `ActionFailed` -- an action failed to dispatch. Check the action config.
- `ExhaustivenessGap` -- a decision variant had no action mapping at runtime. This should not happen if the observer was constructed through `observer.new`. If it does, something constructed a decision with a variant that was not in the original observer's decision list.

The error type tells you which layer broke. Work from the error type, not from the error message string.

## Context Is The Pipeline's Memory

If you are building multi-step pipelines, `Context` carries state between steps. It holds the current data, the trace history, and metadata key-value pairs. `context.advance` is the step-forward operation: new data, new trace appended to history.

The metadata is useful for recording who ran the pipeline, when, and with what parameters. It is not part of the content hash. It is operational context.

## What You Can Break

Nothing, structurally. The library is pure functions on immutable types. You cannot corrupt a tree or produce an invalid hash.

What you can get wrong:
- Providing a decision function that returns variants not in the observer's decision list. The observer was built with specific variants. If your decide function returns a variant the observer doesn't know about, `dispatch` returns `Error(Nil)` and the trace records an `ExhaustivenessGap`.
- Constructing Observables with meaningless SHAs. The library trusts the SHA you provide. If you pass `"abc"` as the SHA of a git commit, the content addressing still works -- it just addresses a lie.
- Ignoring trace errors. `run_tree` always returns a trace, even on failure. The trace records what went wrong. If you only check `trace.is_ok` and throw away errors, you are discarding the diagnostic information.
- Flattening multi-observer trees into sequential processing. The tree structure encodes parallel observation. If you loop over observers and process them sequentially without the tree, you lose the structural relationship between their decisions.
