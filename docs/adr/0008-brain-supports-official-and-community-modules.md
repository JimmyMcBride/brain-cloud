# 0008: Brain supports official and community modules

## Status

Accepted; Stage 1 runtime wording is superseded by ADR 0013.

## Context

Brain needs workflow adaptation without absorbing every integration, knowledge model, tool, or UI into Core. Official capabilities need strong product integration; organizations and third parties need extension points that do not depend on private internals.

## Decision

Brain supports official and community modules through formal lifecycle, capability, permission, configuration, event, migration, storage, API, and audit contracts. Official modules use the same declared contracts available to trusted community modules. Planning is the first major official module.

Stage 1 originally proposed compiled Go modules in process. ADR 0013 replaces the Brain Cloud server runtime with Elixir/Phoenix and defines official cloud modules as supervised OTP applications implementing explicit behaviours. Community execution and distribution still arrive only after those contracts prove stable.

## Consequences

Core remains smaller and modules become explicitly optional. Capability discovery and permission mediation become platform responsibilities. Stable contracts take priority over convenient private imports. Official status implies maintenance and trust, not privileged access.

## Alternatives considered

- Put every capability in Core: rejected as a monolith.
- Build integrations ad hoc: rejected because permissions and lifecycle would drift.
- Require each official module in a separate repository: rejected as premature release overhead.

## Migration implications

Existing and future optional features should identify their Core dependencies and module-owned data. No current package is automatically declared a module. The module manifest and APIs remain provisional until Phase 10.
