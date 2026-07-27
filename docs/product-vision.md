# Product vision

> Brain Cloud gives people, teams, and AI agents durable access to project knowledge from anywhere.

## Product model

Brain is the durable context and memory layer. It answers what a project knows, how it works, why decisions were made, which context matters, and which patterns connect projects. Local Brain remains fully useful without an account or server.

Brain Cloud is the cloud platform: cloud-native storage and access, hosted retrieval and context compilation, collaboration, synchronization coordination, identity, permissions, agent access, and multi-project intelligence. Cloud-native projects are first-class knowledge spaces, not backups. They can begin in the cloud, have no repository, and later export into a human-readable Brain-compatible structure.

Hive Mind is Brain Cloud's cross-project intelligence. It consults authorized projects independently, retains provenance and permissions, then finds patterns, dependencies, duplication, stale knowledge, and contradictions. Hive Memory records how projects relate; project memory records how one project works.

Plan is a separate planning companion. Brain and Hive Mind provide context; Plan and Plan Cloud coordinate what happens next. Plan Cloud may reference Brain sources, create work from contradictions, and propose memories after decisions, but its planning model does not live in this repository.

## Equal operating modes

- **Local:** context and memory never need to leave the device.
- **Cloud:** projects and knowledge live in Brain Cloud and are accessible to web, ChatGPT, IDE, CI, and remote-agent clients.
- **Hybrid:** local and cloud projects link through selective, explicit synchronization policies.

Neither cloud nor hybrid mode diminishes local Brain. Hybrid is a supported product mode with stable identities, revisions, cursors, conflicts, and auditable resolution—not an improvised backup workflow.

## Deployment and trust

Official hosted Brain Cloud and self-hosted Brain Cloud implement one public, versioned protocol. Clients discover protocol versions and capabilities from any configured base URL. No feature depends on a private hosted-service protocol or managed-cloud vendor.

Durable changes are explicit and auditable. Agents may retrieve and propose by default; authorized reviewers decide whether proposals become revisions. Every durable revision preserves actor, time, rationale, and evidence. Permissions are enforced before retrieval so unauthorized content never reaches model context.

Users control portability and visibility. Durable content exports to human-readable Brain-compatible files; users can move between hosted, self-hosted, hybrid, and local-only operation. Server-readable encryption enables hosted retrieval; future end-to-end encryption will carry explicit feature tradeoffs rather than make false promises about server-side search.
