# 0013: Elixir and Phoenix are the Brain Cloud server runtime

## Status

Accepted.

## Context

Brain Cloud needs a long-lived server, supervised domain processes, database-backed readiness, a unified web application, and a future official-module runtime. The Phase 0 Go skeleton proved the public compatibility endpoints but had separate placeholder API and worker binaries and no web foundation.

## Decision

Brain Cloud uses an Elixir/Phoenix umbrella. `brain_cloud` owns Ecto/PostgreSQL access, domain services, release migrations, and OTP supervision. `brain_cloud_web` owns Phoenix, Bandit, LiveView, and the public HTTP transport.

The Go server is replaced rather than run alongside Phoenix. OTP supervision owns future background processes; no worker-only application or queue is added until implemented jobs require one. Official cloud modules will be supervised OTP applications implementing explicit lifecycle, capability, permission, configuration, event, migration, discovery, and audit behaviours. Community modules remain deferred external processes.

The public `/v1` protocol is independent of this runtime choice. Existing health and system-discovery responses remain compatible, while readiness now verifies PostgreSQL.

## Consequences

Brain Cloud gains one runtime for the API, web application, domain supervision, and future official modules. Releases use Phoenix runtime configuration, Ecto migrations, and standard OTP shutdown semantics. Operators move from the former `BRAIN_CLOUD_*` settings and port `8080` to Phoenix environment variables and port `4000`.

`brain-cloud-sdk-go` remains the external Go client repository. The server does not import an SDK.

## Alternatives considered

- Keep the Go API and add Phoenix only for the web UI: rejected because it creates two server runtimes and duplicated transport/domain boundaries before product features exist.
- Preserve a separate empty worker service: rejected because OTP supervision already provides the process model and there are no jobs.
- Load community code into the BEAM: rejected because third-party execution still requires a language-neutral, isolated process contract.

## Migration implications

The Go module, API and worker entrypoints, internal server packages, Go CI, and Go container are removed in the same draft PR. Documentation and planning references to compiled official Go packages are superseded by supervised OTP applications. Phase 1 remains the first persistent project/memory vertical slice.
