---
updated: "2026-09-02T14:37:21Z"
---
# Product vision

> Brain is an extensible context and memory platform for people, teams, and AI agents. Brain Cloud makes that platform available from anywhere. Official and community modules adapt Brain to different workflows without forcing every user to adopt the same toolchain.

## Brain Core

Brain Core is the durable foundation every deployment and module can rely on. It owns project identity, context, memory, retrieval, context compilation, provenance, sessions, authentication boundaries, permissions, configuration, events, audit logging, module lifecycle, capability registration, and stable local/cloud extension contracts.

Core remains valuable on its own. A person or agent can use Brain without enabling Planning, GitHub, notifications, or any other workflow module. Extensibility must not turn Core into a universal issue tracker, source host, CI system, or collection of every possible workflow.

## Brain Cloud

Brain Cloud provides cloud-native Brain projects, hosted context and memory, users, organizations, teams, access control, retrieval, compilation, conversations, revisions, hybrid synchronization, Hive Mind, agent APIs, module management and configuration, cloud module execution, background work, hosted service operation, and self-hosting.

Cloud-native projects are first-class knowledge spaces rather than backups. They can begin without a repository and remain exportable to a human-readable Brain-compatible structure.\n\nHuman access begins with owner approval and recipient-held credentials. The current API supports member-only, time-bounded invitations whose one-time acceptance creates the membership and first credential atomically; delivery and interactive identity remain later product layers rather than hidden infrastructure assumptions.

## Hive Mind

Hive Mind remains a core Brain Cloud capability. It resolves identity and scope, selects authorized projects, retrieves within each project, reranks across project results, analyzes relationships and contradictions, compiles bounded context, and attributes every source.

Modules may contribute searchable sources, project relationships, domain metadata, contradiction candidates, dependencies, specialized retrieval, and agent tools. They may not bypass project permissions, content visibility, provenance, query scope, or tenant isolation.

## Official and community modules

Official modules are maintained by the Brain project and use the same formal contracts available to trusted third-party modules. Expected directions include Planning, Git and GitHub integration, agent or MCP access, notifications, secrets/redaction, import/export providers, and selected adapters. This list is directional, not a first-release commitment.

Brain Cloud initially hosts official modules as supervised Elixir/OTP applications implementing explicit behaviours. This runtime choice does not make the eventual community contract language-specific; community modules remain external processes.

Community modules may add company workflows, context and search providers, memory types, domain models, tools, jobs, web surfaces, approval flows, infrastructure integrations, documentation publishers, importers, and enterprise systems.

Modules declare identity, compatibility, runtimes, capabilities, permissions, configuration, migrations, network/secret access, provenance, publisher identity, and integrity data. They are executable applications—not harmless configuration—and must be mediated by Brain Core.

## Optional Planning

Planning is an official optional Brain module, not a separate cloud platform. Brain can run:

- without Planning;
- with the official Planning module;
- with external planning-context modules;
- with Brain Planning connected to an external execution system.

Planning must use stable Brain module interfaces, receive no private internal exceptions, and have permissions separate from context and memory. It must operate locally, in Brain Cloud, and in hybrid mode without requiring GitHub or another tracker. When enabled in Brain Cloud, its cloud data and UI live inside the Brain Cloud platform.

The standalone `plan` repository continues during migration. A separate effort will define the Planning domain, storage, CLI, compatibility, and migration contract. GitHub support remains temporarily useful for collaboration and publication; it becomes an optional integration over time. Official Linear integration is not a product direction.

## Operating and deployment modes

- **Local:** durable knowledge and enabled local modules can remain entirely on-device.
- **Cloud:** Brain Cloud hosts projects, core capabilities, and enabled cloud modules.
- **Hybrid:** selected durable core and module data synchronize under explicit policies.

Official hosted Brain Cloud and self-hosted Brain Cloud implement one public, versioned, base-URL-configurable protocol. No hosted-only private API defines compatibility.

## One frontend and SDK family

Brain Cloud will have one unified web application. Core surfaces cover projects, context, memory, search, conversations, Hive Mind, revisions, proposals, teams, agents, modules, and administration. Enabled modules may add constrained surfaces. Planning navigation, brainstorms, specs, roadmaps, queues, approvals, and guidance appear only when Planning is enabled.

Each language has one Brain Cloud SDK family. `brain-cloud-sdk-go` exposes core and optional clients after capability discovery. An absent `planning` capability is valid. SDKs contain neither local `.brain/` or `.plan/` behavior nor module implementation code.

## Trust, provenance, and portability

Permissions are enforced before indexing, retrieval, compilation, or model invocation. Durable changes remain explicit, revisioned, attributable, and auditable. Module installation and upgrades require clear permissions and provenance; full sandboxing is not claimed.

Users control visibility and portability. Core and module-owned durable data must have documented ownership and export paths. Users can move between hosted, self-hosted, hybrid, and local-only operation without a private protocol or mandatory external planning system.
