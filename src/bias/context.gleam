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

pub fn with_history(ctx: Context, traces: List(Trace)) -> Context {
  todo
}

pub fn with_metadata(ctx: Context, key: String, value: String) -> Context {
  todo
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

pub fn get_metadata(ctx: Context, key: String) -> Result(String, Nil) {
  todo
}

// ---------------------------------------------------------------------------
// Advancement
// ---------------------------------------------------------------------------

pub fn advance(ctx: Context, new_data: String, t: Trace) -> Context {
  todo
}
