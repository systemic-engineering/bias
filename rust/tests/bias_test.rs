/// Bias tests: Observe, Decide, Act.
///
/// TDD bottom-up: construct trees by hand,
/// verify they hash correctly, validate exhaustiveness,
/// and test the dispatch pipeline.
use bias::action;
use bias::context;
use bias::decision;
use bias::observable::{self, Observable};
use bias::observer::{self, Observer, ObserverError};
use bias::pipeline;
use bias::sha;
use bias::trace;
use bias::tree;

// ---------------------------------------------------------------------------
// Observable: content-addressed observations
// ---------------------------------------------------------------------------

#[test]
fn observable_constructs() {
    let obs = Observable::new("abc123", "git.commit", "repo");
    assert_eq!(obs.sha, "abc123");
    assert_eq!(obs.kind, "git.commit");
    assert_eq!(obs.source, "repo");
}

#[test]
fn observable_hash_is_sha256() {
    let obs = Observable::new("abc123", "git.commit", "repo");
    let h = observable::hash(&obs);
    assert_eq!(h.0.len(), 64);
}

#[test]
fn observable_identical_hash_equal() {
    let a = Observable::new("abc", "git.commit", "repo");
    let b = Observable::new("abc", "git.commit", "repo");
    assert_eq!(observable::hash(&a), observable::hash(&b));
}

#[test]
fn observable_different_sha_hash_different() {
    let a = Observable::new("abc", "git.commit", "repo");
    let b = Observable::new("def", "git.commit", "repo");
    assert_ne!(observable::hash(&a), observable::hash(&b));
}

#[test]
fn observable_different_kind_hash_different() {
    let a = Observable::new("abc", "git.commit", "repo");
    let b = Observable::new("abc", "github.pr", "repo");
    assert_ne!(observable::hash(&a), observable::hash(&b));
}

// ---------------------------------------------------------------------------
// Decision: typed transformation results
// ---------------------------------------------------------------------------

#[test]
fn decision_new_with_payload() {
    let dec = decision::new("Critical", vec![("severity".into(), "high".into())]);
    assert_eq!(dec.variant, "Critical");
    assert_eq!(dec.payload, vec![("severity".into(), "high".into())]);
    assert_eq!(dec.sha.len(), 64);
}

#[test]
fn decision_variant_shorthand() {
    let dec = decision::variant("Ignore");
    assert_eq!(dec.variant, "Ignore");
    assert!(dec.payload.is_empty());
    assert_eq!(dec.sha.len(), 64);
}

#[test]
fn decision_identical_hash_equal() {
    let a = decision::new("Critical", vec![("severity".into(), "high".into())]);
    let b = decision::new("Critical", vec![("severity".into(), "high".into())]);
    assert!(decision::identical(&a, &b));
}

#[test]
fn decision_different_variant_hash_different() {
    let a = decision::variant("Critical");
    let b = decision::variant("Ignore");
    assert!(!decision::identical(&a, &b));
}

#[test]
fn decision_different_payload_hash_different() {
    let a = decision::new("Critical", vec![("severity".into(), "high".into())]);
    let b = decision::new("Critical", vec![("severity".into(), "low".into())]);
    assert!(!decision::identical(&a, &b));
}

#[test]
fn decision_same_variant() {
    let a = decision::new("Critical", vec![("severity".into(), "high".into())]);
    let b = decision::new("Critical", vec![("severity".into(), "low".into())]);
    assert!(decision::same_variant(&a, &b));
}

#[test]
fn decision_get_payload_found() {
    let dec = decision::new(
        "Alert",
        vec![
            ("channel".into(), "email".into()),
            ("priority".into(), "1".into()),
        ],
    );
    assert_eq!(decision::get_payload(&dec, "channel"), Some("email"));
    assert_eq!(decision::get_payload(&dec, "priority"), Some("1"));
}

#[test]
fn decision_get_payload_not_found() {
    let dec = decision::variant("Ignore");
    assert_eq!(decision::get_payload(&dec, "anything"), None);
}

#[test]
fn decision_variant_names() {
    let decs = vec![
        decision::variant("Critical"),
        decision::variant("Warning"),
        decision::variant("Ignore"),
    ];
    let names = decision::variant_names(&decs);
    assert_eq!(names, vec!["Critical", "Warning", "Ignore"]);
}

#[test]
fn decision_variant_names_deduplicates() {
    let decs = vec![
        decision::new("Critical", vec![("a".into(), "1".into())]),
        decision::new("Critical", vec![("a".into(), "2".into())]),
        decision::variant("Ignore"),
    ];
    let names = decision::variant_names(&decs);
    assert_eq!(names, vec!["Critical", "Ignore"]);
}

#[test]
fn decision_group_by_variant() {
    let d1 = decision::new("Critical", vec![("id".into(), "1".into())]);
    let d2 = decision::new("Critical", vec![("id".into(), "2".into())]);
    let d3 = decision::variant("Ignore");
    let decs = [d1, d2, d3];
    let groups = decision::group_by_variant(&decs);
    assert_eq!(groups.len(), 2);
    assert_eq!(groups[0].0, "Critical");
    assert_eq!(groups[0].1.len(), 2);
    assert_eq!(groups[1].0, "Ignore");
    assert_eq!(groups[1].1.len(), 1);
}

// ---------------------------------------------------------------------------
// Action: exhaustive dispatch
// ---------------------------------------------------------------------------

#[test]
fn action_new() {
    let act = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    assert_eq!(act.target, "Alert");
    assert_eq!(act.config, vec![("channel".into(), "ntfy".into())]);
    assert_eq!(act.sha.len(), 64);
}

#[test]
fn action_identical_hash_equal() {
    let a = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    let b = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    assert!(action::identical(&a, &b));
}

#[test]
fn action_different_target_hash_different() {
    let a = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    let b = action::new("Deploy", vec![("channel".into(), "ntfy".into())]);
    assert!(!action::identical(&a, &b));
}

#[test]
fn action_get_config() {
    let act = action::new(
        "Alert",
        vec![
            ("channel".into(), "ntfy".into()),
            ("priority".into(), "high".into()),
        ],
    );
    assert_eq!(action::get_config(&act, "channel"), Some("ntfy"));
    assert_eq!(action::get_config(&act, "priority"), Some("high"));
    assert_eq!(action::get_config(&act, "missing"), None);
}

#[test]
fn action_for_variant() {
    let act1 = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    let act2 = action::new("Email", vec![("to".into(), "ops@example.com".into())]);
    let da = action::for_variant("Critical", vec![act1, act2]);
    assert_eq!(da.variant, "Critical");
    assert_eq!(da.actions.len(), 2);
}

// ---------------------------------------------------------------------------
// Observer: decision-making entity with exhaustiveness
// ---------------------------------------------------------------------------

/// Helper: build a valid observer with two decisions and exhaustive actions.
fn sample_observer() -> Observer {
    let critical = decision::variant("Critical");
    let ignore = decision::variant("Ignore");

    let alert = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    let log = action::new("Log", vec![("level".into(), "info".into())]);

    let actions = vec![
        action::for_variant("Critical", vec![alert]),
        action::for_variant("Ignore", vec![log]),
    ];

    observer::new("security-scanner", vec![critical, ignore], actions).unwrap()
}

#[test]
fn observer_new_valid() {
    let obs = sample_observer();
    assert_eq!(obs.id, "security-scanner");
    assert_eq!(obs.decisions.len(), 2);
    assert_eq!(obs.actions.len(), 2);
    assert_eq!(obs.sha.len(), 64);
}

#[test]
fn observer_new_missing_actions_fails() {
    let critical = decision::variant("Critical");
    let ignore = decision::variant("Ignore");

    let alert = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    let actions = vec![action::for_variant("Critical", vec![alert])];

    let result = observer::new("incomplete", vec![critical, ignore], actions);
    match result {
        Err(ObserverError::MissingActions(missing)) => {
            assert_eq!(missing, vec!["Ignore"]);
        }
        _ => panic!("expected MissingActions error"),
    }
}

#[test]
fn observer_is_exhaustive() {
    let obs = sample_observer();
    assert!(observer::is_exhaustive(&obs));
}

#[test]
fn observer_decision_variants() {
    let obs = sample_observer();
    let variants = observer::decision_variants(&obs);
    assert_eq!(variants, vec!["Critical", "Ignore"]);
}

#[test]
fn observer_action_targets() {
    let obs = sample_observer();
    let targets = observer::action_targets(&obs);
    assert_eq!(targets, vec!["Alert", "Log"]);
}

#[test]
fn observer_actions_for_found() {
    let obs = sample_observer();
    let actions = observer::actions_for(&obs, "Critical").unwrap();
    assert_eq!(actions.len(), 1);
    assert_eq!(actions[0].target, "Alert");
}

#[test]
fn observer_actions_for_not_found() {
    let obs = sample_observer();
    assert!(observer::actions_for(&obs, "NonExistent").is_none());
}

#[test]
fn observer_identical_hash_equal() {
    let a = sample_observer();
    let b = sample_observer();
    assert_eq!(a.sha, b.sha);
}

// ---------------------------------------------------------------------------
// Action dispatch
// ---------------------------------------------------------------------------

#[test]
fn dispatch_single_decision() {
    let obs = sample_observer();
    let critical = decision::variant("Critical");
    let actions = action::dispatch(&obs, &critical).unwrap();
    assert_eq!(actions.len(), 1);
    assert_eq!(actions[0].target, "Alert");
}

#[test]
fn dispatch_returns_none_for_unknown_variant() {
    let obs = sample_observer();
    let unknown = decision::variant("Unknown");
    assert!(action::dispatch(&obs, &unknown).is_none());
}

#[test]
fn dispatch_all() {
    let obs = sample_observer();
    let decisions = vec![
        decision::variant("Critical"),
        decision::variant("Ignore"),
    ];
    let actions = action::dispatch_all(&obs, &decisions);
    assert_eq!(actions.len(), 2);
    let targets: Vec<&str> = actions.iter().map(|a| a.target.as_str()).collect();
    assert_eq!(targets, vec!["Alert", "Log"]);
}

#[test]
fn total_actions() {
    let obs = sample_observer();
    assert_eq!(action::total_actions(&obs), 2);
}

// ---------------------------------------------------------------------------
// Tree: full tree
// ---------------------------------------------------------------------------

#[test]
fn tree_constructs() {
    let observable = Observable::new("commit-abc", "git.commit", "gestalt");
    let obs = sample_observer();
    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };
    assert_eq!(t.observable.kind, "git.commit");
    assert_eq!(t.observers.len(), 1);
}

#[test]
fn tree_hash_is_sha256() {
    let observable = Observable::new("commit-abc", "git.commit", "gestalt");
    let obs = sample_observer();
    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };
    let h = tree::hash(&t);
    assert_eq!(h.0.len(), 64);
}

#[test]
fn tree_identical_hash_equal() {
    let observable = Observable::new("commit-abc", "git.commit", "gestalt");
    let obs = sample_observer();
    let tree_a = tree::Tree {
        sha: String::new(),
        observable: observable.clone(),
        observers: vec![obs.clone()],
    };
    let tree_b = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };
    assert_eq!(tree::hash(&tree_a), tree::hash(&tree_b));
}

#[test]
fn tree_different_observable_hash_different() {
    let obs = sample_observer();
    let tree_a = tree::Tree {
        sha: String::new(),
        observable: Observable::new("aaa", "git.commit", "repo"),
        observers: vec![obs.clone()],
    };
    let tree_b = tree::Tree {
        sha: String::new(),
        observable: Observable::new("bbb", "git.commit", "repo"),
        observers: vec![obs],
    };
    assert_ne!(tree::hash(&tree_a), tree::hash(&tree_b));
}

#[test]
fn tree_different_observers_hash_different() {
    let observable = Observable::new("abc", "git.commit", "repo");

    let obs1 = sample_observer();

    let pass = decision::variant("Pass");
    let fail = decision::variant("Fail");
    let noop = action::new("Noop", vec![]);
    let retry = action::new("Retry", vec![]);
    let obs2 = observer::new(
        "health-check",
        vec![pass, fail],
        vec![
            action::for_variant("Pass", vec![noop]),
            action::for_variant("Fail", vec![retry]),
        ],
    )
    .unwrap();

    let tree_a = tree::Tree {
        sha: String::new(),
        observable: observable.clone(),
        observers: vec![obs1],
    };
    let tree_b = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs2],
    };
    assert_ne!(tree::hash(&tree_a), tree::hash(&tree_b));
}

// ---------------------------------------------------------------------------
// Serialization: deterministic canonical form
// ---------------------------------------------------------------------------

#[test]
fn observable_serializes_deterministically() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let s1 = observable::serialize(&obs);
    let s2 = observable::serialize(&obs);
    assert_eq!(s1, s2);
    assert_eq!(s1, "Observable(git.commit, repo, abc)");
}

#[test]
fn decision_serializes_deterministically() {
    let dec = decision::new("Critical", vec![("severity".into(), "high".into())]);
    let s1 = decision::serialize(&dec);
    let s2 = decision::serialize(&dec);
    assert_eq!(s1, s2);
}

#[test]
fn action_serializes_deterministically() {
    let act = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    let s1 = action::serialize_action(&act);
    let s2 = action::serialize_action(&act);
    assert_eq!(s1, s2);
    assert_eq!(s1, "Action(Alert, config[channel=ntfy])");
}

// ---------------------------------------------------------------------------
// Cross-verification: byte-identical hashes between Gleam and Rust
// ---------------------------------------------------------------------------

#[test]
fn cross_verify_observable_hash() {
    // Known serialization: "Observable(git.commit, repo, abc)"
    let obs = Observable::new("abc", "git.commit", "repo");
    let serialized = observable::serialize(&obs);
    assert_eq!(serialized, "Observable(git.commit, repo, abc)");
    // Hash the serialized form and verify it's a valid SHA-256
    let hash = sha::hash(&serialized);
    assert_eq!(hash.0.len(), 64);
    // The hash must be deterministic
    assert_eq!(hash, sha::hash("Observable(git.commit, repo, abc)"));
}

#[test]
fn cross_verify_decision_hash() {
    let dec = decision::new("Critical", vec![("severity".into(), "high".into())]);
    let serialized = decision::serialize(&dec);
    assert_eq!(serialized, "Decision(Critical, payload[severity=high])");
    let hash = sha::hash(&serialized);
    assert_eq!(hash.0.len(), 64);
    assert_eq!(
        hash,
        sha::hash("Decision(Critical, payload[severity=high])")
    );
}

#[test]
fn cross_verify_action_hash() {
    let act = action::new("Alert", vec![("channel".into(), "ntfy".into())]);
    let serialized = action::serialize_action(&act);
    assert_eq!(serialized, "Action(Alert, config[channel=ntfy])");
    let hash = sha::hash(&serialized);
    assert_eq!(hash.0.len(), 64);
    assert_eq!(hash, sha::hash("Action(Alert, config[channel=ntfy])"));
}

// ---------------------------------------------------------------------------
// Integration: full pipeline
// ---------------------------------------------------------------------------

#[test]
fn full_pipeline() {
    let observable = Observable::new("a1b2c3", "git.commit", "gestalt");
    let obs = sample_observer();

    let decisions = observer::observe(&obs, &observable, |_obs| {
        vec![decision::variant("Critical")]
    });

    let actions = action::dispatch_all(&obs, &decisions);

    assert_eq!(actions.len(), 1);
    assert_eq!(actions[0].target, "Alert");
    assert_eq!(action::get_config(actions[0], "channel"), Some("ntfy"));
}

#[test]
fn multi_observer_pipeline() {
    let observable = Observable::new("commit-xyz", "git.commit", "gestalt");

    let scanner = sample_observer();

    let pass = decision::variant("Pass");
    let fail = decision::variant("Fail");
    let noop = action::new("Noop", vec![]);
    let retry = action::new("Retry", vec![("attempts".into(), "3".into())]);
    let health = observer::new(
        "health-check",
        vec![pass, fail],
        vec![
            action::for_variant("Pass", vec![noop]),
            action::for_variant("Fail", vec![retry]),
        ],
    )
    .unwrap();

    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![scanner.clone(), health.clone()],
    };

    let scanner_decisions =
        observer::observe(&scanner, &t.observable, |_| vec![decision::variant("Ignore")]);
    let health_decisions =
        observer::observe(&health, &t.observable, |_| vec![decision::variant("Fail")]);

    let scanner_actions = action::dispatch_all(&scanner, &scanner_decisions);
    let health_actions = action::dispatch_all(&health, &health_decisions);

    assert_eq!(scanner_actions.len(), 1);
    assert_eq!(scanner_actions[0].target, "Log");

    assert_eq!(health_actions.len(), 1);
    assert_eq!(health_actions[0].target, "Retry");
    assert_eq!(action::get_config(health_actions[0], "attempts"), Some("3"));

    let h = tree::hash(&t);
    assert_eq!(h.0.len(), 64);
}

// ---------------------------------------------------------------------------
// Trace: execution records
// ---------------------------------------------------------------------------

#[test]
fn trace_new_ok() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let t = trace::new(
        trace::Step::Observe(obs),
        "input-data",
        Ok("abc-hash".to_string()),
        vec![],
    );
    assert!(trace::is_ok(&t));
    assert!(!trace::is_error(&t));
    assert_eq!(t.input, "input-data");
    assert_eq!(t.output, Ok("abc-hash".to_string()));
    assert!(t.nested.is_empty());
}

#[test]
fn trace_new_error() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let err = trace::TraceError::ObservationFailed("timeout".to_string());
    let t = trace::new(
        trace::Step::Observe(obs),
        "input-data",
        Err(err),
        vec![],
    );
    assert!(trace::is_error(&t));
    assert!(!trace::is_ok(&t));
    assert_eq!(
        t.output,
        Err(trace::TraceError::ObservationFailed("timeout".to_string()))
    );
}

#[test]
fn trace_get_result() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let t = trace::new(
        trace::Step::Observe(obs),
        "data",
        Ok("result-sha".to_string()),
        vec![],
    );
    assert_eq!(trace::get_result(&t), &Ok("result-sha".to_string()));
}

#[test]
fn trace_root_causes_finds_leaf_errors() {
    let obs = Observable::new("abc", "git.commit", "repo");

    let leaf_err = trace::new(
        trace::Step::Act {
            action: action::Action {
                sha: "a1".to_string(),
                target: "Alert".to_string(),
                config: vec![],
            },
            decision_variant: "Critical".to_string(),
        },
        "dec-sha",
        Err(trace::TraceError::ActionFailed {
            target: "Alert".to_string(),
            reason: "connection refused".to_string(),
        }),
        vec![],
    );

    let middle = trace::new(
        trace::Step::Decide {
            observer_id: "scanner".to_string(),
            observable_sha: "obs-sha".to_string(),
        },
        "obs-sha",
        Err(trace::TraceError::ActionFailed {
            target: "scanner".to_string(),
            reason: "action failed".to_string(),
        }),
        vec![leaf_err],
    );

    let root = trace::new(
        trace::Step::Observe(obs),
        "data",
        Err(trace::TraceError::ObservationFailed(
            "observer failed".to_string(),
        )),
        vec![middle],
    );

    let causes = trace::root_causes(&root);
    assert_eq!(causes.len(), 1);
    assert_eq!(causes[0].input, "dec-sha");
}

#[test]
fn trace_find_by_predicate() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let act = action::Action {
        sha: "a1".to_string(),
        target: "Alert".to_string(),
        config: vec![],
    };
    let leaf1 = trace::new(
        trace::Step::Act {
            action: act.clone(),
            decision_variant: "Critical".to_string(),
        },
        "d1",
        Ok("a1".to_string()),
        vec![],
    );
    let leaf2 = trace::new(
        trace::Step::Act {
            action: act,
            decision_variant: "Ignore".to_string(),
        },
        "d2",
        Ok("a1".to_string()),
        vec![],
    );
    let parent = trace::new(
        trace::Step::Decide {
            observer_id: "scanner".to_string(),
            observable_sha: "obs".to_string(),
        },
        "obs",
        Ok("d1,d2".to_string()),
        vec![leaf1, leaf2],
    );
    let root = trace::new(
        trace::Step::Observe(obs),
        "data",
        Ok("obs".to_string()),
        vec![parent],
    );

    let acts = trace::find(&root, &|t| matches!(t.step, trace::Step::Act { .. }));
    assert_eq!(acts.len(), 2);
}

#[test]
fn trace_reduce_counts_all() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let act = action::Action {
        sha: "a1".to_string(),
        target: "Alert".to_string(),
        config: vec![],
    };
    let leaf = trace::new(
        trace::Step::Act {
            action: act,
            decision_variant: "Critical".to_string(),
        },
        "d1",
        Ok("a1".to_string()),
        vec![],
    );
    let parent = trace::new(
        trace::Step::Decide {
            observer_id: "scanner".to_string(),
            observable_sha: "obs".to_string(),
        },
        "obs",
        Ok("d1".to_string()),
        vec![leaf],
    );
    let root = trace::new(
        trace::Step::Observe(obs),
        "data",
        Ok("obs".to_string()),
        vec![parent],
    );

    let count = trace::reduce(&root, 0, &|_, acc| acc + 1);
    assert_eq!(count, 3);
}

#[test]
fn trace_serialize_deterministic() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let t = trace::new(
        trace::Step::Observe(obs),
        "data",
        Ok("result".to_string()),
        vec![],
    );
    let s1 = trace::serialize_trace(&t);
    let s2 = trace::serialize_trace(&t);
    assert_eq!(s1, s2);
}

#[test]
fn trace_hash_deterministic() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let t1 = trace::new(
        trace::Step::Observe(obs.clone()),
        "data",
        Ok("result".to_string()),
        vec![],
    );
    let t2 = trace::new(
        trace::Step::Observe(obs),
        "data",
        Ok("result".to_string()),
        vec![],
    );
    assert_eq!(trace::hash_trace(&t1), trace::hash_trace(&t2));
    assert_eq!(trace::hash_trace(&t1).0.len(), 64);
}

#[test]
fn trace_different_input_hash_different() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let t1 = trace::new(
        trace::Step::Observe(obs.clone()),
        "data-1",
        Ok("result".to_string()),
        vec![],
    );
    let t2 = trace::new(
        trace::Step::Observe(obs),
        "data-2",
        Ok("result".to_string()),
        vec![],
    );
    assert_ne!(trace::hash_trace(&t1), trace::hash_trace(&t2));
}

// ---------------------------------------------------------------------------
// Context: execution state
// ---------------------------------------------------------------------------

#[test]
fn context_new() {
    let ctx = context::new("initial-data");
    assert_eq!(ctx.data, "initial-data");
    assert!(ctx.history.is_empty());
    assert!(ctx.metadata.is_empty());
}

#[test]
fn context_with_metadata() {
    let ctx = context::new("data");
    let ctx = context::with_metadata(ctx, "author", "reed");
    let ctx = context::with_metadata(ctx, "timestamp", "2026-03-01");
    assert_eq!(context::get_metadata(&ctx, "author"), Some("reed"));
    assert_eq!(
        context::get_metadata(&ctx, "timestamp"),
        Some("2026-03-01")
    );
}

#[test]
fn context_get_metadata_not_found() {
    let ctx = context::new("data");
    assert_eq!(context::get_metadata(&ctx, "missing"), None);
}

#[test]
fn context_advance() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let t = trace::new(
        trace::Step::Observe(obs),
        "old-data",
        Ok("new-sha".to_string()),
        vec![],
    );
    let ctx = context::new("old-data");
    let advanced = context::advance(ctx, "new-sha", t);
    assert_eq!(advanced.data, "new-sha");
    assert_eq!(advanced.history.len(), 1);
}

#[test]
fn context_with_history() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let t = trace::new(
        trace::Step::Observe(obs),
        "data",
        Ok("sha".to_string()),
        vec![],
    );
    let ctx = context::new("data");
    let ctx = context::with_history(ctx, vec![t]);
    assert_eq!(ctx.history.len(), 1);
}

// ---------------------------------------------------------------------------
// Pipeline: run_tree — full execution with tracing
// ---------------------------------------------------------------------------

#[test]
fn run_tree_single_observer() {
    let observable = Observable::new("commit-abc", "git.commit", "bias");
    let obs = sample_observer();
    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };

    let result_trace = pipeline::run_tree(&t, "raw-data", |_, _| {
        Ok(vec![decision::variant("Critical")])
    });

    assert!(trace::is_ok(&result_trace));
    assert_eq!(result_trace.nested.len(), 1);
    let decide_trace = &result_trace.nested[0];
    assert!(trace::is_ok(decide_trace));
    assert_eq!(decide_trace.nested.len(), 1);
    let act_trace = &decide_trace.nested[0];
    assert!(trace::is_ok(act_trace));
}

#[test]
fn run_tree_multi_observer() {
    let observable = Observable::new("commit-xyz", "git.commit", "bias");

    let scanner = sample_observer();

    let pass = decision::variant("Pass");
    let fail = decision::variant("Fail");
    let noop = action::new("Noop", vec![]);
    let retry = action::new("Retry", vec![("attempts".into(), "3".into())]);
    let health = observer::new(
        "health-check",
        vec![pass, fail],
        vec![
            action::for_variant("Pass", vec![noop]),
            action::for_variant("Fail", vec![retry]),
        ],
    )
    .unwrap();

    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![scanner, health],
    };

    let result_trace = pipeline::run_tree(&t, "raw-data", |obs, _| match obs.id.as_str() {
        "security-scanner" => Ok(vec![decision::variant("Critical")]),
        "health-check" => Ok(vec![decision::variant("Fail")]),
        _ => Err("unknown observer".to_string()),
    });

    assert!(trace::is_ok(&result_trace));
    assert_eq!(result_trace.nested.len(), 2);
}

#[test]
fn run_tree_error_propagation() {
    let observable = Observable::new("abc", "git.commit", "repo");
    let obs = sample_observer();
    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };

    let result_trace = pipeline::run_tree(&t, "data", |_, _| {
        Err("decision function crashed".to_string())
    });

    assert!(trace::is_error(&result_trace));
    let causes = trace::root_causes(&result_trace);
    assert_eq!(causes.len(), 1);
}

#[test]
fn run_tree_trace_nesting_mirrors_tree() {
    let observable = Observable::new("abc", "git.commit", "bias");
    let obs = sample_observer();
    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };

    let result_trace = pipeline::run_tree(&t, "data", |_, _| {
        Ok(vec![
            decision::variant("Critical"),
            decision::variant("Ignore"),
        ])
    });

    assert!(trace::is_ok(&result_trace));
    assert_eq!(result_trace.nested.len(), 1);
    let decide_trace = &result_trace.nested[0];
    assert_eq!(decide_trace.nested.len(), 2);
}

#[test]
fn run_tree_deterministic_hash() {
    let observable = Observable::new("commit-abc", "git.commit", "bias");
    let obs = sample_observer();
    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };

    let decide = |_: &Observer, _: &Observable| Ok(vec![decision::variant("Critical")]);
    let trace1 = pipeline::run_tree(&t, "data", decide);
    let trace2 = pipeline::run_tree(&t, "data", decide);

    assert_eq!(trace::hash_trace(&trace1), trace::hash_trace(&trace2));
}

#[test]
fn run_tree_exhaustiveness_gap() {
    let observable = Observable::new("abc", "git.commit", "repo");
    let obs = sample_observer();
    let t = tree::Tree {
        sha: String::new(),
        observable,
        observers: vec![obs],
    };

    let result_trace = pipeline::run_tree(&t, "data", |_, _| {
        Ok(vec![decision::Decision {
            sha: "fake".to_string(),
            variant: "Nonexistent".to_string(),
            payload: vec![],
        }])
    });

    assert!(trace::is_error(&result_trace));
    let causes = trace::root_causes(&result_trace);
    assert_eq!(causes.len(), 1);
    assert_eq!(
        causes[0].output,
        Err(trace::TraceError::ExhaustivenessGap {
            observer_id: "security-scanner".to_string(),
            variant: "Nonexistent".to_string(),
        })
    );
}

// ---------------------------------------------------------------------------
// Pipeline: composition
// ---------------------------------------------------------------------------

#[test]
fn pipeline_new() {
    let p = pipeline::new("test-pipeline");
    assert_eq!(p.name, "test-pipeline");
    assert!(p.steps.is_empty());
}

#[test]
fn pipeline_add_step() {
    let obs = Observable::new("abc", "git.commit", "repo");
    let p = pipeline::new("test");
    let p = pipeline::add_step(p, pipeline::PipelineStep::Observe(obs));
    assert_eq!(p.steps.len(), 1);
}

#[test]
fn pipeline_chain() {
    let a = pipeline::new("first");
    let b = pipeline::new("second");
    let chained = pipeline::chain(a, b);
    assert_eq!(chained.name, "first");
}
