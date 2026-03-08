# bias

Observation filtered through subjectivity, made structural.

A Gleam library for content-addressed, exhaustive decision trees. Every observer has bias -- weight-shifting, legacy patterns, filters. Bias makes it typed, exhaustive, and diffable.

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

Every level is content-addressable (SHA-256). The tree is diffable at every level. Decision variants are exhaustive -- every variant has actions, no catch-all.

## Install

```sh
gleam add bias
```

## Documentation

Full documentation: [`docs/`](docs/INDEX.md)

1. [What Bias Is](docs/WHAT-BIAS-IS.md) -- the concept, the types, content addressing.
2. [Modules](docs/MODULES.md) -- how the seven modules compose.
3. [Agent Guide](docs/AGENT-GUIDE.md) -- what future agents need to know.

## Development

```sh
gleam test
```

## Licence

`LICENSE.md` contains the Apache-2.0 licence required by Hex. The actual
governing terms are the [systemic.engineering License v1.0](REAL_LICENSE.md).
