---
name: generate-trd-technical-design
description: Produce a review-ready and implementation-ready TRD (Technical Requirement/Design Document) from the user's PRD and the current codebase. The design must be grounded in real system state and requirement gaps, not abstract assumptions.
---

## 1. When to use

Use this skill when the user wants to:
- design a technical solution from a PRD
- evaluate impact on the existing system
- define scope, interfaces, data, and rollout strategy
- produce a TRD ready for engineering review

## 2. Core principles

- **Template first**: if a template is provided, follow it strictly (sections, order, fields).
- **Evidence first**: claims about current state must come from code or user-provided materials.
- **Gap-driven design**: analyze `requirements vs current state` before proposing solutions.
- **Implementation-first detail**: specify module/class/method level changes, not only concepts.
- **No fabrication**: do not invent code, metrics, dependencies, or call chains; mark unknowns as `To be confirmed`.

## 3. Inputs (priority order)

### 3.1 PRD (required)

Extract at minimum:
- business context and goals
- functional requirements and business rules
- core flows and user roles
- edge/error scenarios
- data and non-functional requirements (performance, compatibility, security)

If PRD content is ambiguous or conflicting, list open questions explicitly.

### 3.2 Codebase (strongly required)

Perform demand-driven discovery, not blind full-repo scanning:
- module and directory structure
- API/Controller → Service → Repository/DAO
- Entity/DTO/VO, SQL/schema, cache, MQ, RPC/HTTP dependencies
- config, scheduled/async jobs, transaction boundaries, error handling

### 3.3 TRD template (optional)

If provided, strictly follow:
- heading hierarchy
- field names and table structures
- section order and formatting rules

If data cannot be filled, write: `To be filled` or `No related implementation found in current codebase; further confirmation required`.

## 4. Standard workflow

### Step 1: Requirement understanding (before solution writing)

Output a short “requirement understanding” summary that answers:
- why this is needed, what is built, who uses it
- what capabilities are new/changed
- what are the key rules and boundary constraints

### Step 2: Code mapping and current-state discovery

Trace related implementation through:
`API → Controller → Service → Repository/DAO → DB/Redis/MQ/RPC`

Also identify:
- current business flow and state transitions
- data flow and call chain
- cache/message/transaction/error-handling mechanisms

### Step 3: Build the current-state model

Cover at least four views:
- **Architecture view**: actual components and interactions
- **Flow view**: request-to-response path
- **Data view**: entities, tables, indexes, relations, lifecycle
- **Dependency view**: upstream/downstream/third-party risk points

### Step 4: Gap analysis (critical)

Use a table:
`Requirement | Current implementation | Gap | Change direction | Risk`

Do not start detailed solution design before gaps are explicit.

### Step 5: Technical solution design

Cover only relevant parts:
- architecture and module changes
- core business flow (text or Mermaid)
- database design (fields/indexes/migration/compatibility)
- API design (contract, request/response, error codes, idempotency, auth)
- cache design (key, TTL, consistency, hot-key, invalidation)
- MQ design (topic, semantics, retry, DLQ, idempotency)
- concurrency and consistency (locks, transactions, CAS, eventual consistency)

Do not introduce Redis/MQ/distributed locks for show; justify necessity and benefit.

### Step 6: Exception, stability, and rollout design

Must include:
- exception/edge-case closure loop: `trigger → detection → handling → retry/compensation → convergence`
- performance/capacity assessment (mark unknown metrics explicitly)
- compatibility and release strategy (canary, rollback, irreversible-op safeguards)

### Step 7: Code change checklist

For key changes, provide executable granularity:
`module/file path → class/method → change details`

Prefer real file paths; never invent files or methods.

### Step 8: Testing and acceptance design

At minimum include:
- functional: happy path, error path, edge cases
- concurrency: duplicate requests, race conditions, idempotency
- data: consistency, migration, compatibility
- stability: dependency failure injection (DB/Redis/MQ/RPC)

## 5. Default TRD structure (when no template is provided)

1. Background and goals
2. In-scope and out-of-scope
3. Requirement understanding and key rules
4. Current system analysis
5. Gap analysis
6. Solution overview
7. Detailed design (flow/data/API/cache/MQ/consistency)
8. Exceptions and edge scenarios
9. Performance and stability evaluation
10. Release, canary, and rollback plan
11. Code change checklist
12. Test and acceptance plan
13. Risks and open items

## 6. Quality gates (self-check before final output)

Before delivering TRD, verify:
- Are key conclusions traceable to PRD or code?
- Is there a complete and explicit gap table?
- Is there an executable change checklist (file/class/method level)?
- Are exception handling, compatibility, rollback, and performance risks covered?
- Are speculative metrics or speculative code structures avoided?
- Are all unknowns clearly marked as `To be confirmed`?

## 7. Output style

- Summary first, then details.
- Use structured headings, tables, and checklists.
- Keep terminology aligned with the project.
- Stay focused on the current requirement; avoid irrelevant sections.

---

Goal: the final TRD should be directly usable by engineering, QA, architects, and product teams for review and execution.
