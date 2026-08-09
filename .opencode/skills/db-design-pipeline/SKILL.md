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
15. `outputs/15-index-tuning-report-G10/` (folder containing `15-index-tuning-report-G10.md` + `benchmark_queries.sql`)
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

# Step 14: Data Generator
Save to: `outputs/14-data-generator-G10`

**Context & Role:**
You are a Database Engineer / Performance Tester. Your task is to create a large-scale synthetic data generator and workload queries.

**Instructions:**
- Create `generate_data.py` to generate 100,000 to 500,000 records for `BookingRequest` and related tables (`User`, `Space`, `Facility`, `MaintenanceRecord`, `Approval`, `UsageSession`, `BookingAcknowledgement`).
- Create `generate_queries.py` to generate a workload of 10,000 SQL queries with randomized parameters for index tuning.
- Package the generated SQL statements in structured chunk sizes (e.g. 5,000 rows per batch) under `sql_batches/` to avoid transaction log issues during execution.

# Step 15: Index Tuning Report
Save to: `outputs/15-index-tuning-report-G10/15-index-tuning-report-G10.md`
Benchmark script: `outputs/15-index-tuning-report-G10/benchmark_queries.sql`

**Context & Role:**
You are a Senior Database Administrator / Query Performance Analyst. Your task is to tune the booking conflict check, the room finder, and two selected reporting queries, and report the results.

**Analytical Directives:**
1. **Queries to tune:** (a) booking conflict check, (b) room finder (capacity + facility list + availability within a time period), and (c) two reporting queries from Phase 2 Section 1.3 (choose two other than the room finder, e.g., total approved booking hours per space, and approved bookings by weekday and hour).
2. **Deliverables:** the Markdown report AND a runnable `benchmark_queries.sql` that produces the measured numbers. Package both in the `outputs/15-index-tuning-report-G10/` folder (report file + benchmark script together).
3. **Verify the dataset scale FIRST.** The benchmark script must print the actual row count (`Dataset scale: N ... rows`) and the earliest booking date. Only trust the before/after numbers when `N ≈ 100,000` AND the earliest `StartTime` matches the generator range (`2023-09-01`). The generator is known to have produced duplicate IDs per batch before — if `COUNT(*)` is not ~100,000, regenerate the data (`generate_data.py`) and reload before benchmarking. Do not fill in numbers on an incomplete dataset.
4. **Correct "before" baseline.** The "before" run must be measured WITHOUT the Step 15 tuned indexes, but WITH the Phase 1 supporting indexes intact (they are the deployed Phase 1 baseline — do not drop them). Make the script idempotent: `DROP INDEX IF EXISTS` the tuned indexes at the top, and guard each `CREATE INDEX` with `IF NOT EXISTS`, so re-runs are correct.
5. **Measure properly.** Per query: warmup run (materialize into a `#temp` table to cache the plan) then the timed run under `SET STATISTICS TIME ON` / `SET STATISTICS IO ON`. Use unique temp-table names per section (`#warm_b1..b4` before, `#warm_a1..a4` after) and give every `SELECT ... INTO` column an explicit alias (avoids Msg 2714/1038). Compare execution plans (scan vs seek), logical reads, CPU time, and elapsed time before/after.
6. **Record execution plan and time BEFORE and AFTER indexing** on a generated dataset of at least 100,000 bookings, and describe the improvement (e.g., Scan -> Seek, reduced reads). If a query was already cheap before (e.g., the conflict check already served by the Phase 1 index), say so explicitly instead of inventing a gain.
7. **Report honestly.** If elapsed and CPU disagree (e.g., 134 ms elapsed with CPU 47 ms on 95 reads), report both and flag the elapsed as scheduling noise; CPU time and logical reads are the reliable indicators. Note any dataset-scale caveats.
8. **Normalization Validation:** As part of this step, identify the functional dependencies of the updated database and confirm that all relations satisfy at least Third Normal Form (3NF); document the verification and any decomposition rationale.

# Step 16: Analytical Queries
Save to: `outputs/16-analytical-queries-G10.sql`

**Context & Role:**
You are a Senior Database Developer. Implement all reporting queries required by Phase 2 Section 1.3 for the Facility Manager.

**Strict Directives (MUST FOLLOW):**
1. Implement and document all four reports:
   - Total approved booking hours of each space for a given semester.
   - Number of approved bookings by weekday and hour for a given semester.
   - Available spaces that satisfy a required capacity and a required facility list within a given time period (the "room finder").
   - Approved bookings affected when a maintenance record is escalated to out-of-service (overlap between approved bookings and the escalated maintenance period).
2. Use meaningful parameters (e.g., `@SemesterStart`, `@SemesterEnd`, `@RequiredCapacity`, `@RequiredFacility`, `@MaintenanceID`) at the top of each query so they can be re-run with different inputs.
3. **Parameters must hit the data.** Verify each default parameter value returns rows on the loaded 100,000-row dataset. In particular, the escalation report's `@MaintenanceID` must reference a record with `ImpactLevel = 'OutOfService'` and an open status — default it to `(SELECT TOP 1 MaintenanceID FROM MaintenanceRecord WHERE ImpactLevel = 'OutOfService' AND Status IN ('Open','InProgress') ORDER BY MaintenanceID)` so the report is never empty, and document that it can be overridden.
4. Ensure each query is valid T-SQL against the Phase 2 schema (including `MaintenanceRecord.ImpactLevel` and `BookingAcknowledgement` where relevant).
5. Keep the four reports consistent with the tuned queries in Step 15 (reports 1–3 are Q3/Q4/Q2 of the benchmark; report 4 is the optional Q5).

Provide ONLY valid SQL code, properly commented. Do not wrap it in markdown formatting if saving directly to a .sql file.

EOF
