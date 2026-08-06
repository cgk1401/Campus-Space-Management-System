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
