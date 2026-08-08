cat > .opencode/skills/db-design-pipeline/SKILL.md <<'EOF'
---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, and DDL documents step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Important behavior

Before assuming anything, inspect the project:

1. Run `ls -la`.
2. Locate requirement files under `req/`, `docs/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.

## Required output files

Create or update the following files:

1. `outputs/01-business-req-analysis-G10.md`
2. `outputs/02-erd-design-G10.md`
3. `outputs/03-logical-design-G10.md`
4. `outputs/04-design-validation-G10.md`
5. `outputs/05-db-definition-G10.md`
6. `outputs/06-sample-data-G10.md`
7. `outputs/07-query-design-G10.md`
8. `outputs/08-requirement-change-analysis-G10.md`
9. `outputs/09-updated-erd-and-logical-design-G10.md`
10. `outputs/10-schema-migration-G10.sql`
11. `outputs/11-concurrency-design-G10.md`
12. `outputs/12-concurrency-implementation-G10.sql`
13. `outputs/13-concurrency-tests-G10`
14. `outputs/14-data-generator-G10`
15. `outputs/15-index-tuning-report-G10.md`
16. `outputs/16-analytical-queries-G10.sql`


Do not skip any Markdown file.

---

# Step 1: Business Requirement Analysis

Save to:
`outputs/01-business-req-analysis-G10.md`
The document must include:
Analyze the requirements to identify the business purpose, actors, entities, attributes, relationships, cardinalities, and business rules.

# Step 2: Conceptual Design / ERD

Design an ERD that should be based on the document from the prior step: Step 1: Business Requirement Analysis.

Save to:
`outputs/02-erd-design-G10.md`
The document must include:
An ERD showing the main entities, attributes, relationships, cardinalities, and participation constraints.

If different actors have different permissions (e.g. only certain roles can approve, check in, or be assigned),
note these as role-based access constraints in the relationship details section.

## Modeling Rules

- Each named relationship must be represented explicitly in the schema.
- For 1:1 relationships, use the parent PK as the child PK (no new surrogate key).
- Avoid folding relationship attributes (e.g., decision info, assignment info) into one of the participating entity tables. If a relationship has its own attributes, give it its own table.
- Exception: if a relationship has no attributes and is 1:N, a FK column on the child table is sufficient. Only create a junction table for M:N or when the relationship itself carries attributes.

# Step 3: Logical Design

Convert the ERD from Step 2 (Conceptual Design) into a relational schema

Save to:
`outputs/03-logical-design-G10.md`
The document must include:
A relational schema with relations, attributes, primary keys, foreign keys, candidate keys, and key constraints.

The relational schema must explicitly document for each table:
- Primary key
- Foreign keys with ON DELETE justification
- Candidate keys (UNIQUE constraints)
- NOT NULL constraints on mandatory attributes
- CHECK constraints for enum/domain columns (list valid values)
- CHECK constraints for numeric rules (e.g. Capacity > 0, EndTime > StartTime)
- DEFAULT values where a sensible default exists

For each foreign key, state the ON DELETE action and justify it briefly. Consider:
- Whether the child record has independent meaning without its parent
- Whether the parent should be soft-deleted (status field) rather than hard-deleted

Role-based access constraints should be listed in the Business Rule Enforcement table as application-level rules, not SQL constraints

Clearly distinguish between constraints enforceable via DDL (CHECK, UNIQUE, NOT NULL) and those requiring application logic. 
Do not list DDL-enforceable constraints as application-level.


# Step 4: Design Validation

The ERD and the schema be based on the document from the prior step: Step 2 and Step 3

Save to:
`outputs/04-design-validation-G10.md`
The document must include:
Evaluate whether the relational schema correctly represents the ERD, satisfies the business rules, and uses appropriate keys, relationships, and constraints.


# Step 5: Database Definition

Implement the database using SQL DDL with tables,
keys, constraints, checks, and default values where appropriate.

Save to:
`outputs/05-db-definition-G10.md`
The document must include:
The database using SQL DDL with tables, keys, constraints, checks, and default values where appropriate.


# Step 6: Sample Data

Save to:
`outputs/06-sample-data-G10.md`
The document must include:
Insert realistic sample data to support testing of normal 
operations and important exceptional cases.


# Step 7:

Save to:
`outputs/07-query-design-G10.md`

The document must include:
Design and execute at 20 meaningful SQL 
queries that are valid for the database and useful for answering business questions 
in the given context. Each query must include: Business question, target user(s) that would use the query, short explanation of why the query is useful, SQL statement.

# Step 8: Requirement Change Analysis (Agent Skill)

Save to: `outputs/08-requirement-change-analysis-G10.md`

**Context & Role:**
You are a Senior Database Architect. Your task is to analyze the Phase 2 requirement changes (Maintenance Impact Levels and Concurrent Booking/Approval) against the Phase 1 conceptual design. 

**Analytical Directives (How you must think):**
When analyzing the requirements, you MUST apply advanced database design principles. Do not blindly propose schema changes if physical implementation solves the problem better. Follow these specific logic rules:
1. **Maintenance Impact Levels:** Recognize that `Advisory` vs. `Out-of-service` requires a new attribute (`ImpactLevel`). For recording user acknowledgement of advisories, deduce that a new associative entity (e.g., `BOOKING_ACKNOWLEDGEMENT`) is required to track exactly which maintenance record was acknowledged by which booking.
2. **Escalation Logic:** Understand that escalating an impact level does *not* require schema changes. It requires an "Impact Analysis Query" (JOIN logic based on overlapping time ranges) to identify affected bookings.
3. **Auto-approval:** DO NOT propose removing the `ApproverID` foreign key constraint or adding an `IsAutoApproved` column. Instead, propose using a "Non-human System Actor" (e.g., a System User ID) to maintain referential integrity and auditability.
4. **Concurrency Control:** Explicitly state that application-level (Backend) time-checks are insufficient due to "Race Conditions". Recommend Database-level enforcement (e.g., Transaction Locking, Serializable Isolation, or PostgreSQL Exclusion Constraints) as the single source of truth.


# Step 9: Updated ERD & Logical Design

Save to: `outputs/09-updated-erd-and-logical-design-G10.md`

**Context & Role:**
You are a Senior Database Designer. Based on the decisions made in `08-requirement-change-analysis-G10.md`, you will update the Phase 1 ERD and logical schema.

**Analytical Directives:**
1. **Mermaid Generation:** Output the complete, updated ERD using Mermaid.js `erDiagram` syntax (Crow's foot notation). 
2. **Minimal Changes:** Only add the elements approved in Step 8 (e.g., `BookingAcknowledgement` entity, `ImpactLevel` attribute). Leave all other Phase 1 entities exactly as they were.
3. **Relationships:** Ensure the new M:N associative entity (`BookingAcknowledgement`) is correctly connected to `BookingRequest` and `MaintenanceRecord` with 1:N identifying relationships.
4. **Logical Schema Documentation:** Provide a brief updated text definition of the Relational Schema, clearly highlighting the *[NEW]* tables and *[UPDATED]* columns.

# Step 10: Schema Migration
Save to: `outputs/10-schema-migration-G10.sql`

**Context & Role:**
You are a Senior Database Administrator (DBA). Your task is to write a SQL Migration script for Microsoft SQL Server to transition the Phase 1 database to Phase 2.

**Strict Directives (MUST FOLLOW):**
1. **NO DATA LOSS:** You are writing a *Migration Script* for a live production database. You are STRICTLY FORBIDDEN to use `DROP TABLE` or rewrite `CREATE TABLE` for existing Phase 1 tables.
2. **Additive Changes Only:** Use `ALTER TABLE` to add the new `ImpactLevel` column to `MaintenanceRecord` (ensure you set a `DEFAULT 'OutOfService'` so existing rows don't break).
3. **New Tables:** Write the `CREATE TABLE` statement ONLY for the new `BookingAcknowledgement` table.
4. **System Data Insertion:** Write the `INSERT` statement to create the System Actor in the `User` table (e.g., UserID = -1, Role = 'FacilityManager') to support the Auto-approval feature.
5. **Syntax:** Ensure all SQL is valid T-SQL (Microsoft SQL Server syntax).

Provide ONLY valid SQL code, properly commented. Do not wrap it in markdown formatting if saving directly to a .sql file.

# Step 11: Concurrency Design

Save to: `outputs/11-concurrency-design-G10.md`

**Context & Role:**
You are a Senior Database Designer. Based on the schema in `09-updated-erd-and-logical-design-G10.md`,
define 2 concurrency conflict scenarios and propose a solution for each.

**Analytical Directives:**
1. **Distinct sources**: The 2 scenarios must arise from different transaction types per §1.2 of the Phase 2 spec — 
   e.g. (a) two manual staff-approval operations racing on the same space, and (b) an auto-approval (instant booking) racing a manual approval, 
   or two auto-approvals racing each other.
2. **Explicit interleaving**: Each scenario must show the actual read/write timeline of the two transactions (T1, T2) — 
   what each reads, when, and how both pass the overlap check before either commits — not just a prose description.
3. **Schema-grounded**: Reference the actual columns/index involved (BookingRequest.Status, StartTime/EndTime, SpaceCode, IX_BookingRequest_SpaceTime) 
   — analysis must be specific to this schema, not generic.
4. **No Code, Analytical Only**: No T-SQL at this stage — sequence/timeline tables are fine, executable code is not.
5. **BR21 traceability**: Both scenarios must show BR21 ('No two approved bookings overlap on the same space') is violated if unmitigated, 
   and the proposed solution must be shown to restore it.
6. **Tradeoff justification**: For each solution (SERIALIZABLE isolation, UPDLOCK/HOLDLOCK hints, or both), state the tradeoff — 
   blocking/deadlock risk vs. throughput — and why it's the right choice for that specific scenario.

# Step 12: Concurrency Implementation

Save to: `outputs/12-concurrency-implementation-G10/`

**Context & Role:**
You are a Senior Database Administrator (DBA).

# Step 13: Concurrency Tests

Save to: `outputs/13-concurrency-tests-G10.md`

**Context & Role:**
You are a Senior Database Administrator (DBA).