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

1. `outputs/01-business-req-analysis.md`
2. `outputs/02-erd-design.md`
3. `outputs/03-logical-design.md`
4. `outputs/04-design-validation.md`
5. `outputs/05-db-definition.md`
6. `outputs/06-sample-data.md`
7. `outputs/07-query-design.md`

Do not skip any Markdown file.

---

# Step 1: Business Requirement Analysis

Save to:
`outputs/01-business-req-analysis.md`
The document must include:
Analyze the requirements to identify the business purpose, actors, entities, attributes, relationships, cardinalities, and business rules.

# Step 2: Conceptual Design / ERD

Design an ERD that should be based on the document from the prior step: Step 1: Business Requirement Analysis.

Save to:
`outputs/02-erd-design.md`
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
`outputs/03-logical-design.md`
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
`outputs/04-design-validation.md`
The document must include:
Evaluate whether the relational schema correctly represents the ERD, satisfies the business rules, and uses appropriate keys, relationships, and constraints.


# Step 5: Database Definition

Implement the database using SQL DDL with tables,
keys, constraints, checks, and default values where appropriate.

Save to:
`outputs/05-db-definition.md`
The document must include:
The database using SQL DDL with tables, keys, constraints, checks, and default values where appropriate.


# Step 6: Sample Data

Save to:
`outputs/06-sample-data.md`
The document must include:
Insert realistic sample data to support testing of normal 
operations and important exceptional cases.


# Step 7:

Save to:
`outputs/07-query-design.md`
The document must include:
Design and execute at 20 meaningful SQL 
queries that are valid for the database and useful for answering business questions 
in the given context. Each query must include: Business question, target user(s) that would use the query, short explanation of why the query is useful, SQL statement.
