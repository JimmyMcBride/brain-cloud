# Brain Cloud

Brain Cloud is the hosted and self-hostable cloud platform for Brain: durable project context and memory available to people, teams, and AI agents from anywhere.

Brain is designed around three equal operating modes:

- **Local:** knowledge remains on the user's machine; no account or server is required.
- **Cloud:** cloud-native projects store context, memory, search, conversations, and collaboration without requiring a local repository or `.brain/` directory.
- **Hybrid:** a local Brain project links to a cloud project and synchronizes only user-selected durable content.

The official hosted service and self-hosted installations use the same public HTTP protocol. Compatible clients select a server by base URL; the official service has no privileged protocol.

## Repository boundary

This repository owns the Brain Cloud server, HTTP API, cloud project knowledge, hosted retrieval, sync coordination, Hive Mind, agent APIs, workers, auditability, deployment support, and eventually its web application.

It does not own the Brain CLI or local filesystem behavior, language-specific SDKs, Plan's planning domain, Plan Cloud, or autonomous coding-agent execution. The future Go client belongs in `brain-cloud-sdk-go`; this server will not depend on it.

## Status

Phase 0 foundation only. The repository currently provides configuration, structured logging, graceful shutdown, health/readiness checks, compatibility discovery, tests, CI, and development deployment scaffolding. Projects, memory, persistence, authentication, search, sync, Hive Mind, and the web application are roadmap work—not implemented features.

## Local development

Requirements: Go 1.26 or newer. Docker is optional.

```bash
make check
make run
```

Configuration:

| Variable | Default | Purpose |
| --- | --- | --- |
| `BRAIN_CLOUD_ADDRESS` | `:8080` | API listen address |
| `BRAIN_CLOUD_LOG_LEVEL` | `INFO` | structured log level |
| `BRAIN_CLOUD_SHUTDOWN_TIMEOUT` | `10s` | graceful shutdown deadline |

Docker development:

```bash
docker compose up --build
```

The Compose file starts the API and PostgreSQL; persistence is intentionally not wired into the Phase 0 API.

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
curl http://localhost:8080/v1/system/info
```

## Project documents

- [Product vision](docs/product-vision.md)
- [Architecture](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Security direction](docs/security.md)
- [Self-hosting direction](docs/self-hosting.md)
- [Architecture decisions](docs/adr/)
