# Project: brain-cloud

Created: 2026-07-27T17:43:26Z

## Vision

Brain Cloud gives people, teams, and AI agents durable access to project knowledge from anywhere through one hosted and self-hostable protocol.

## Principles

- Local, cloud-native, hybrid, and self-hosted operation remain first-class.
- The public protocol is identical across deployments and base-URL configurable.
- Permissions precede retrieval; provenance and explicit durable writes are mandatory.
- Project boundaries remain intact in Hive Mind.
- Data remains portable.
- Brain and Plan stay separate, strongly integrated domains.

## Constraints

- This repository owns only the Brain Cloud server and eventual web application.
- Brain CLI/local behavior, SDKs, Plan Cloud, and autonomous agent execution remain external.
- Phase 0 uses the Go standard library and adds infrastructure only when implemented behavior needs it.

## Planning Rules

- Specs are the canonical execution contract.
- Brainstorms are discovery material; refine and challenge before promotion.
- In GitHub source mode, Plan owns planning artifacts. Never bypass it with raw `gh` issue/project commands.
- Each phase stays bounded by explicit acceptance criteria and exclusions.

## Current focus

Phase 0 establishes the repository and architecture. Next work is Phase 1 only: create a cloud project, store durable memory, retrieve it, and search it with persistence across restart.
