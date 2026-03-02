# What Bias Is

Every observer has bias. That is not a flaw to fix. It is the structure of observation itself.

When you look at a git commit, you don't see "a git commit." You see it through whatever you are -- your training, your history, your decision function. A security scanner sees vulnerabilities. A health checker sees uptime risk. A style linter sees formatting violations. Same commit. Different observations. The difference between those observations is bias.

Bias takes that difference and makes it typed, exhaustive, content-addressed, and diffable. Not to remove the subjectivity. To make it structural.

## The Pattern

Observe. Decide. Act.

An observable exists. An observer looks at it and produces decisions -- typed variants that represent what the observer sees. Each decision variant maps to actions. Every variant has actions. No catch-all. No unhandled branches. The decision space is exhaustive.

```
observable
+-- observer-A
|   +-- decision-1
|   |   +-- action-a
|   |   +-- action-b
|   +-- decision-2
|       +-- action-c
+-- observer-B
    +-- decision-3
        +-- action-d
```

The tree structure is the bias made visible. Observer A and Observer B look at the same observable and produce different decisions. That is not a bug. That is the point.

## The Types

```gleam
pub type Observable {
  Observable(sha: String, kind: String, source: String)
}

pub type Decision {
  Decision(sha: String, variant: String, payload: List(#(String, String)))
}

pub type Action {
  Action(sha: String, target: String, config: List(#(String, String)))
}

pub type Observer {
  Observer(
    sha: String,
    id: String,
    decisions: List(Decision),
    actions: List(DecisionActions),
  )
}

pub type DecisionActions {
  DecisionActions(variant: String, actions: List(Action))
}

pub type Tree {
  Tree(sha: String, observable: Observable, observers: List(Observer))
}
```

Six types. Every one carries a `sha` field. That is the content-addressed hash of its canonical serialization. Same content, same hash.

`Observable` is the root -- the thing being observed. It has a kind (what it is), a source (where it came from), and a SHA (its content address).

`Decision` is the transformation result -- what an observer produces after processing the observable. The `variant` names the decision ("Critical", "Ignore", "Escalate"). The `payload` carries key-value data specific to that variant.

`Action` is what fires in response to a decision. The `target` names the action kind ("Alert", "Deploy", "Log"). The `config` carries action parameters.

`Observer` is the decision-making entity. It holds its decisions and their action mappings. The `DecisionActions` type links each decision variant to its list of actions.

`Tree` is the full structure: one observable, one or more observers, each with their decisions and exhaustive actions. The tree SHA covers everything -- the observable, every observer, every decision, every action. A change anywhere produces a different root hash.

## Content Addressing

Every level has a SHA-256 hash. The hash is computed from a canonical serialization of the type's fields. The serialization is deterministic: same data, same string, same hash. Always.

```gleam
let obs = Observable(sha: "abc", kind: "git.commit", source: "repo")
let h = hash_observable(obs)
// h is a 64-character hex string (SHA-256)
```

The content-addressing property means:
- Same observable, same hash. Deduplication is free.
- Different observable, different hash. Comparison is a single string check.
- Change anything inside a tree -- a decision payload, an action config, an observer's decisions -- and the tree hash changes. The hash covers the full structure.

## The Exhaustiveness Invariant

Every decision variant in an observer must have a corresponding entry in the observer's action map. This is enforced at construction time. `observer.new` returns `Error(MissingActions(variants))` if any decision variant lacks actions.

```gleam
let critical = decision.variant("Critical")
let ignore = decision.variant("Ignore")
let alert = action.new("Alert", [#("channel", "ntfy")])

// Only providing actions for Critical, not Ignore
let result = observer.new("scanner", [critical, ignore], [
  action.for_variant("Critical", [alert]),
])
// result == Error(MissingActions(["Ignore"]))
```

This is structural, not advisory. You cannot build an observer with unhandled decision branches. The type system and the constructor together guarantee that every decision path leads to actions. No catch-all. No default case. Every variant has a branch.

## Different Witness, Different Hash

Two observers looking at the same observable produce different decision trees. Those trees have different hashes. This is not incidental -- it is the design.

The observer's id, decisions, and action mappings are all part of the hash. A security scanner and a health checker produce different observers, different decisions, different actions, and therefore different tree hashes -- even when pointed at the same observable.

The hash tells you not just what was observed, but how it was observed. The bias is in the hash.

## ADO Encoded

The observe-decide-act pattern maps to the ADO communication protocol: observe first, form a decision, then act on it. The decision function is the transformation -- the observer's subjectivity made structural. Weight-shifting, legacy patterns, filters. All of that is the decision function.

The library does not contain the decision logic. The caller provides the `decide` function. What the library provides is the structure that makes the decision traceable, exhaustive, and diffable. You bring the subjectivity. Bias gives it a shape.
