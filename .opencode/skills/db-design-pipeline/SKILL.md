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

Save to:
`outputs/02-erd-design.md`
The document must include:
<!-- YOUR SKILL DESCRIPTION HERE -->

# Step 3: Logical Design

Save to:
`outputs/03-logical-design.md`
The document must include:
<!-- YOUR SKILL DESCRIPTION HERE -->

# Step 4: Design Validation

Save to:
`outputs/04-design-validation.md`
The document must include:
<!-- YOUR SKILL DESCRIPTION HERE -->

# Step 5: Database Definition

Save to:
`outputs/05-db-definition.md`
The document must include:
<!-- YOUR SKILL DESCRIPTION HERE -->

# Step 6: Sample Data

Save to:
`outputs/06-sample-data.md`
The document must include:
<!-- YOUR SKILL DESCRIPTION HERE -->


# Step 7:

Save to:
`outputs/07-query-design.md`
The document must include:
<!-- YOUR SKILL DESCRIPTION HERE -->
