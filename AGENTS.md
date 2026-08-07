# AGENTS.md — cs486-demo

CS486 database systems teaching demo. This repository contains business requirements in the `req/` directory, and output design documents will be saved in `outputs/`

## Recurring context

- This is a demo project, not production.
- Run `ls -la` to detect new files before assuming anything exists.

# Database Design Agent Rules

This project transforms business requirements into database design artifacts.

<!---YOU COULD CHANGE THE FOLLOW SECTIONS --->
## Workflow Order
Always follow this order:

1. Analyze business requirements.
2. Produce conceptual ERD using Crow's Foot notation.

Do not jump directly to DDL. The documents from the prior steps should be followed in the later steps.

## Required Outputs

- `outputs/01-business-req-analysis-G10.md`
- `outputs/02-erd-design-G10.md`
- `outputs/03-logical-design-G10.md`
- `outputs/04-design-validation-G10.md`
- `outputs/05-db-definition-G10.md`
- `outputs/06-sample-data-G10.md`
- `outputs/07-query-design-G10.md`
- `outputs/08-requirement-change-analysis-G10.md`
- `outputs/09-updated-erd-and-logical-design-G10.md`
- `outputs/10-schema-migration-G10.sql`
- `outputs/11-concurrency-design-G10.md`
- `outputs/12-concurrency-implementation-G10.sql`
- `outputs/13-concurrency-tests-G10`
- `outputs/14-data-generator-G10`
- `outputs/15-index-tuning-report-G10.md`
- `outputs/16-analytical-queries-G10.sql`

## DBMS

Use Microsoft SQL Server unless the user specifies another DBMS.

## Design Rules

- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement → entity → relationship → table → constraint.
- Use Mermaid `erDiagram` for ERD.
- Do not silently invent business rules.
