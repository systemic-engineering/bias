/// Decision: operations for building and working with decisions.
///
/// A decision is the transformation result — what an observer produces
/// after processing an observable. The decision function IS the observer's
/// subjectivity made structural: weight-shifting, legacy patterns, filters, bias.
///
/// Decisions are typed variants. The action space is bounded by the
/// decision type. No catch-all actions allowed — exhaustive match only.

import bias.{type Decision}
import gleam/list

/// Build a new Decision with computed content hash.
pub fn new(
  variant: String,
  payload: List(#(String, String)),
) -> Decision {
  let dec = bias.Decision(sha: "", variant: variant, payload: payload)
  let sha = bias.hash_decision(dec)
  bias.Decision(..dec, sha: sha)
}

/// Build a Decision with no payload. For simple variant-only decisions
/// like "Ignore" or "Pass".
pub fn variant(name: String) -> Decision {
  new(name, [])
}

/// Extract the variant name from a decision.
pub fn variant_name(decision: Decision) -> String {
  decision.variant
}

/// Extract a specific payload value by key.
pub fn get_payload(
  decision: Decision,
  key: String,
) -> Result(String, Nil) {
  decision.payload
  |> list.find(fn(pair) {
    let #(k, _) = pair
    k == key
  })
  |> result_map_value
}

/// Check whether two decisions have the same variant (regardless of payload).
pub fn same_variant(a: Decision, b: Decision) -> Bool {
  a.variant == b.variant
}

/// Check whether two decisions are content-identical (same SHA).
pub fn identical(a: Decision, b: Decision) -> Bool {
  a.sha == b.sha
}

/// Collect all unique variant names from a list of decisions.
pub fn variant_names(decisions: List(Decision)) -> List(String) {
  decisions
  |> list.map(fn(d) { d.variant })
  |> list.unique
}

/// Group decisions by variant name.
pub fn group_by_variant(
  decisions: List(Decision),
) -> List(#(String, List(Decision))) {
  let variants = variant_names(decisions)
  list.map(variants, fn(v) {
    let matching = list.filter(decisions, fn(d) { d.variant == v })
    #(v, matching)
  })
}

fn result_map_value(
  result: Result(#(String, String), Nil),
) -> Result(String, Nil) {
  case result {
    Ok(#(_, v)) -> Ok(v)
    Error(Nil) -> Error(Nil)
  }
}
