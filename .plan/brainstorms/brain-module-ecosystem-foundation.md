---
created_at: "2026-07-27T21:20:04Z"
project: brain-cloud
slug: brain-module-ecosystem-foundation
status: active
title: Brain module ecosystem foundation
type: brainstorm
updated_at: "2026-07-27T21:21:43Z"
---

# Brainstorm: Brain module ecosystem foundation

Started: 2026-07-27T21:20:04Z

## Focus Question

What is the smallest formal module foundation that lets compiled official modules validate safe Brain extension contracts without prematurely building community module execution?
## Desired Outcome

Brain Core and Brain Cloud gain explicit, capability- and permission-aware module boundaries that support Planning as the first official module and preserve a later external-process path for community modules.
## Vision

Modules adapt Brain to different workflows while Core stays independently useful and secure. Official and community modules share formal contracts; official status grants maintenance and trust, not private access.

## Supporting Material

- `docs/product-vision.md`
- `docs/architecture.md`
- `docs/roadmap.md`
- `docs/security.md`
- ADRs 0007–0012

## Constraints

- Stage 1 supports internal compiled official modules only; no arbitrary loading.
- Planning is optional, receives no private internal exceptions, and has permissions separate from context and memory.
- Hive Mind remains core; modules cannot bypass permissions, visibility, scope, provenance, or tenant isolation.
- External-process transport, package registry, web sandboxing, and final manifest schema remain deferred.

## Open Questions

- Which lifecycle and capability interfaces are truly required by the first Planning slice?
- Which permission names can remain stable across local and cloud runtimes?
- How should module-owned migrations and data export be mediated without a premature general framework?
- What minimum discovery response lets clients degrade safely when a module is absent?
## Ideas

## Raw Notes

Vision: modules adapt Brain to workflows while Core stays independently useful and secure. Official and community modules use formal capability and permission contracts; official status grants maintenance and trust, not private access.

Candidate Stage 1 shape: module identity, enable/disable lifecycle, capability registration, permission declarations, configuration schema hook, event subscriptions, migration ownership, capability discovery, and audit events. Planning is the first compiled official consumer.

Stage 2 direction: community modules run as external processes through a later language-neutral protocol. Transport is deliberately undecided.

Permission model: install approval plus per-capability grants; Planning read/write/approve remains separate from project context read and memory propose/edit.

Explicit non-goals: no Planning-domain implementation or Plan migration, no arbitrary Go plugins, no unrestricted third-party in-process code, no external process runtime, no registry, no package signing implementation, no UI extension sandbox, no permanent GitHub planning dependency, and no official Linear integration.

Supporting material: docs/product-vision.md, docs/architecture.md, docs/roadmap.md, docs/security.md, and ADRs 0007-0012.

## Refinement

### Problem

Brain needs optional workflow capabilities without turning Core into a monolith or allowing extensions to bypass permissions, provenance, lifecycle, and data ownership. Planning needs a stable home, but building a community runtime before one official module validates the contracts would freeze guesses into public APIs.

### User / Value

Brain users can enable only the workflows they need; official teams and community developers get explicit extension seams; administrators can understand and approve module access; Planning can integrate deeply without becoming mandatory or privileged.

### Appetite

One contract-validation foundation for compiled official modules: identity, lifecycle, capabilities, permissions, configuration, events, migrations, discovery, and audit. Stop before Planning domain implementation, community process execution, packaging, registries, or UI extension security.

### Remaining Open Questions

- Which lifecycle and capability interfaces are truly required by the first Planning slice?
- Which permission names can remain stable across local and cloud runtimes?
- How should module-owned migrations and data export be mediated without a premature general framework?
- What minimum discovery response lets clients degrade safely when a module is absent?

### Candidate Approaches

- Define small host-facing interfaces exercised by a minimal compiled official module test fixture before Planning implementation.
- Model module identity, capabilities, permissions, configuration, migrations, and events as explicit descriptors owned by Core.
- Keep module storage behind module-scoped repositories and migration ownership while Core enforces tenant/project/audit context.
- Expose enabled module IDs and capabilities through system discovery; defer remote transport and packaging.

### Decision Snapshot

Stage 1 should define only the compiled official-module host contract needed to make Planning optional and non-privileged. Validate identity, lifecycle, capability/permission declarations, configuration, events, migrations, discovery, and audit with small tests; design external-process community modules only after this contract survives real Planning use.

## Challenge

### Rabbit Holes

- Designing the remote protocol, registry, signing service, package manager, or UI sandbox before an official module exists.
- Making Planning semantics part of generic Core interfaces.
- Building abstractions for hypothetical module types without a concrete consumer.
- Treating in-process official modules as permission-exempt trusted internals.

### No-Gos

- No Planning domain migration or API design in this workstream.
- No arbitrary Go plugins or third-party in-process loading.
- No selected external-process transport.
- No official Linear integration or permanent GitHub planning backend.
- No moving Hive Mind out of Core.

### Assumptions

- One compiled official module can reveal most host-contract gaps before externalization.
- Core can mediate permissions and audit consistently across local and cloud runtimes.
- Planning can keep its domain model behind module boundaries while using shared project identity and context.
- External community compatibility matters, but it does not require freezing transport now.

### Likely Overengineering

A universal manifest and runtime that attempts to support every language, deployment, provider, UI, permission, and migration scenario at once. Keep descriptors provisional and build only seams exercised by compiled official modules.

### Simpler Alternative

A small in-process registry and descriptor contract with explicit enablement, capabilities, permissions, configuration, lifecycle hooks, discovery, and audit—proven by a test module. Add events, migrations, storage, and Planning-specific needs only when their first vertical slice exercises them.
