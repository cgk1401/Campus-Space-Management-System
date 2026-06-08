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

- `outputs/01-business-req-analysis.md`
- `outputs/02-erd-design.md`
- `outputs/03-logical-design.md`
- `outputs/04-design-validation.md`
- `outputs/05-db-definition.md`
- `outputs/06-sample-data.md`
- `outputs/07-query-design.md`

## DBMS

Use Microsoft SQL Server unless the user specifies another DBMS.

## Design Rules

- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement → entity → relationship → table → constraint.
- Use Mermaid `erDiagram` for ERD.
- Do not silently invent business rules.
