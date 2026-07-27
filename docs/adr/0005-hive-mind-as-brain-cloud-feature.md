# 0005: Hive Mind as a Brain Cloud feature

## Context

Cross-project retrieval depends on Brain Cloud identity, permissions, revisions, search, provenance, and project knowledge.

## Decision

Hive Mind is a flagship Brain Cloud domain, not a separate product. It retrieves within authorized projects, reranks across project results, analyzes relationships, and returns bounded answers with provenance. Hive Memory describes relationships between projects and remains distinct from project memory.

## Consequences

Hive Mind inherits Brain Cloud authorization and audit controls. Project boundaries cannot be flattened into an undifferentiated global index. Hive Memory changes normally use reviewed proposals.

## Alternatives considered

A standalone Hive service was rejected as premature duplication of platform concerns. A single global document pool was rejected because it erases permission, ownership, and provenance boundaries.
