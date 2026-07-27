# 0003: Cloud-native, local, and hybrid modes

## Context

Some users require device-only knowledge, some need remote-first collaboration, and others need both with selective synchronization.

## Decision

Local, cloud, and hybrid operation are equal product modes. Cloud projects may exist without a repository. Local Brain needs no Cloud account. Hybrid links stable project/document identities and synchronizes selected durable content with explicit conflicts.

## Consequences

Cloud cannot assume files as canonical storage. Sync needs revisions, hashes, cursors, idempotency, visibility policy, and conflict history. All cloud content must remain exportable to a Brain-compatible human-readable form.

## Alternatives considered

Treating cloud as backup was rejected because it excludes cloud-native workflows. Treating local as a cache was rejected because local-only use is foundational. Import/export-only hybrid was rejected because it cannot safely coordinate concurrent change.
