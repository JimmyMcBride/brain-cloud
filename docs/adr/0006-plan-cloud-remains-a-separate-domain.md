# 0006: Plan Cloud remains a separate domain

## Context

Brain knowledge improves planning, and completed plans can improve knowledge, but memory/retrieval and work coordination answer different questions.

## Decision

Plan and Plan Cloud remain separate products and domain models. Brain Cloud exposes contracts for context requests, Hive questions, Brain references, contradiction-driven work, and post-work memory proposals. Shared platform extraction waits for demonstrated need.

## Consequences

The systems integrate through stable identities and APIs rather than shared internal models. Some identity, organization, repository, authorization, and audit primitives may later move into a shared platform without making that commitment now.

## Alternatives considered

Implementing Plan Cloud inside Brain Cloud was rejected because it collapses distinct domains. Extracting a shared platform immediately was rejected as premature architecture without operational evidence.
