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
    todo!("implement Context construction")
}

/// Add trace history to a context.
pub fn with_history(ctx: Context, traces: Vec<Trace>) -> Context {
    todo!("implement with_history")
}

/// Add a metadata key-value pair.
pub fn with_metadata(ctx: Context, key: &str, value: &str) -> Context {
    todo!("implement with_metadata")
}

/// Look up a metadata value by key.
pub fn get_metadata<'a>(ctx: &'a Context, key: &str) -> Option<&'a str> {
    todo!("implement get_metadata")
}

/// Advance the context: update data, append trace to history.
pub fn advance(ctx: Context, new_data: &str, trace: Trace) -> Context {
    todo!("implement advance")
}
