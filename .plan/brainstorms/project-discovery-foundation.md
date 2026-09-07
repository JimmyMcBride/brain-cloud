---
created_at: "2026-09-07T16:48:31Z"
project: brain-cloud
slug: project-discovery-foundation
status: active
title: Project discovery foundation
type: brainstorm
updated: "2026-09-07T16:49:53Z"
updated_at: "2026-09-07T16:49:30Z"
---
# Brainstorm: Project discovery foundation

## Focus Question

What is the smallest permission-safe project read surface needed before expanding the cloud-native project model?

## Vision

Recommendation, pending user confirmation: clients can discover accessible projects and fetch their basic details without retaining IDs from creation responses.

## Supporting Material

- docs/roadmap.md: Phase 3 cloud-native project model.
- apps/brain_cloud_web/lib/brain_cloud_web/router.ex: creation exists; project list/detail routes do not.
- apps/brain_cloud/lib/brain_cloud/projects.ex: existing owner, member, team, and agent access predicates.
- openapi/brain-cloud-v1.yaml: current public protocol.

## Refinement

### Problem

API clients can create projects but cannot list accessible projects or request project details.

### User / Value

Humans and agents gain permission-safe discovery. Future SDK and CLI workflows can build on this API.

### Appetite

One API-only list/detail slice, proposed as Phase 3A. Not approved for implementation.

### Candidate Approaches

Recommended: list and detail together. Detail alone is smaller but leaves discovery unresolved. Broader metadata/lifecycle work is deferred.

### Remaining Open Questions

- Explicit read scope policy and existing-token compatibility.
- Stable bounded cursor pagination and exact response/error contracts.
- Authorization freshness across pages and concurrent access revocation.
- Whether user accepts this as the next Phase 3 slice.

### Decision Snapshot

Draft recommendation only. Resolve the questions, refine and challenge the proposal, then promote a canonical GitHub spec for review. No implementation slices yet.

## Constraints

Preserve tenant isolation and existing owner/member/team/agent access semantics. Filter before pagination; never expose inaccessible rows or counts. Keep existing create responses unchanged.

## Challenge

### No-Gos

No rename, metadata expansion, archive/delete, revisions, import/export, browser product UI, Planning, or agent administration.

### Risks

Scope backfills could broaden credentials. Pagination could leak inaccessible projects or duplicate rows from team joins. Recheck authorization on every request.

### Verification Direction

Domain/controller tests for all principal types, direct/team overlap, tenant concealment, revoked access, malformed IDs/cursors, empty pages, stable ordering, and bounded limits; OpenAPI coverage and release smoke during implementation.
