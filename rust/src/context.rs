use crate::trace::Trace;

/// Execution context for pipelines.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Context {
    pub data: String,
    pub history: Vec<Trace>,
    pub metadata: Vec<(String, String)>,
}

/// Create a fresh context with data.
pub fn new(data: &str) -> Context {
    Context {
        data: data.to_string(),
        history: Vec::new(),
        metadata: Vec::new(),
    }
}

/// Add trace history to a context.
pub fn with_history(mut ctx: Context, traces: Vec<Trace>) -> Context {
    ctx.history.extend(traces);
    ctx
}

/// Add a metadata key-value pair.
pub fn with_metadata(mut ctx: Context, key: &str, value: &str) -> Context {
    ctx.metadata.insert(0, (key.to_string(), value.to_string()));
    ctx
}

/// Look up a metadata value by key.
pub fn get_metadata<'a>(ctx: &'a Context, key: &str) -> Option<&'a str> {
    ctx.metadata
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.as_str())
}

/// Advance the context: update data, append trace to history.
pub fn advance(ctx: Context, new_data: &str, trace: Trace) -> Context {
    let mut history = ctx.history;
    history.push(trace);
    Context {
        data: new_data.to_string(),
        history,
        metadata: ctx.metadata,
    }
}
