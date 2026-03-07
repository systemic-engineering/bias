/// Context: execution context for pipelines.
///
/// Carries data through pipeline execution, accumulates trace history,
/// and holds metadata (author, timestamp, etc.).
///
/// Ported from Babel.Context (Elixir) to Gleam.

import bias/trace.{type Trace}
import gleam/list

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

/// Execution context for pipelines.
pub type Context {
  Context(
    data: String,
    history: List(Trace),
    metadata: List(#(String, String)),
  )
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

/// Create a fresh context with data.
pub fn new(data: String) -> Context {
  Context(data: data, history: [], metadata: [])
}

/// Add trace history to a context.
pub fn with_history(ctx: Context, traces: List(Trace)) -> Context {
  Context(..ctx, history: list.append(ctx.history, traces))
}

/// Add a metadata key-value pair.
pub fn with_metadata(ctx: Context, key: String, value: String) -> Context {
  Context(..ctx, metadata: [#(key, value), ..ctx.metadata])
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/// Look up a metadata value by key.
pub fn get_metadata(ctx: Context, key: String) -> Result(String, Nil) {
  ctx.metadata
  |> list.find(fn(pair) {
    let #(k, _) = pair
    k == key
  })
  |> result_map_value
}

// ---------------------------------------------------------------------------
// Advancement
// ---------------------------------------------------------------------------

/// Advance the context: update data, append trace to history.
pub fn advance(ctx: Context, new_data: String, t: Trace) -> Context {
  Context(
    data: new_data,
    history: list.append(ctx.history, [t]),
    metadata: ctx.metadata,
  )
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

fn result_map_value(
  r: Result(#(String, String), Nil),
) -> Result(String, Nil) {
  case r {
    Ok(#(_, v)) -> Ok(v)
    Error(Nil) -> Error(Nil)
  }
}
