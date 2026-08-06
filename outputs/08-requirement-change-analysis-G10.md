# 08 — Requirement Change Analysis (Phase 2)

**Role:** Senior Database Architect
**Basis:** Phase 1 conceptual design (`outputs/01`–`outputs/07`) vs. `req/business_requirement_phase_2.md` (§1.1 Maintenance impact levels, §1.2 Concurrent booking & approval, §1.3 New reporting needs).
**Target DBMS:** Microsoft SQL Server (per AGENTS.md).

This document identifies which Phase 1 entities, relationships, and business rules are affected by the Phase 2 changes, and — using the skill's analytical directives — distinguishes what truly requires schema changes from what is better solved by queries, a system actor, or database-level concurrency control.

---

## 1. Summary of Phase 2 Requirement Changes

| ID | Phase 2 change | Source |
|----|----------------|--------|
| C1 | Maintenance gets **impact levels**: `out-of-service` (space unbookable while open, exactly as Phase 1) vs. `advisory` (space remains bookable, requester must be notified and acknowledgement recorded). | §1.1 |
| C2 | A space may have **several active maintenance records simultaneously** with different impact levels. | §1.1 |
| C3 | Impact level may be **escalated or downgraded** while open; escalation must identify already-approved overlapping bookings so staff can contact requesters. | §1.1 |
| C4 | **Instant (auto) approval** at submission time for selected space types that satisfy the usage policy; other requests keep the staff-approval workflow. | §1.2 |
| C5 | **Concurrency correctness:** two approved bookings must never overlap on the same space, regardless of instant booking vs. staff approval and regardless of simultaneous operations. | §1.2 |
| C6 | **New reports:** (a) total approved booking hours per space per semester, (b) approved bookings by weekday & hour per semester, (c) room finder by capacity + facility list + time range, (d) approved bookings affected by an out-of-service escalation. | §1.3 |

---

## 2. Change C1 — Maintenance Impact Levels

### 2.1. Analysis

Phase 1 modeled a single boolean-ish notion: "space under maintenance cannot be booked" (BR3/BR4). Phase 2 splits maintenance into two impact levels that behave differently:

- **Out-of-service** → identical to Phase 1: the space cannot be booked for any overlapping period while the record is open.
- **Advisory** → the space **can** be booked; the system must (1) notify the requester of all active advisories at booking time and (2) **record the acknowledgement with the booking**.

### 2.2. Schema change needed: YES — new attribute

| Decision | Detail |
|----------|--------|
| New attribute | `MaintenanceRecord.ImpactLevel` — required, no sensible NULL. |
| Domain (CHECK) | `Advisory`, `OutOfService`. |
| Default | `OutOfService` (safest default: preserves Phase 1 behaviour when no level is supplied). |
| Rationale | The two levels have different *business consequences* (bookable vs. not), so they must be queryable and constraint-checkable as a first-class attribute. |

### 2.3. Schema change needed: YES — new associative entity

Recording "the requester was informed" requires a **who-was-acknowledged-what** trace, which is inherently M:N data:

- A **booking** must be associated with **every active advisory** on its space at booking time.
- One advisory can be acknowledged by **many bookings**.
- One booking can acknowledge **many advisories**.

| Decision | Detail |
|----------|--------|
| New entity | `BookingAcknowledgement` (associative / junction) |
| PK | Composite `(BookingID, MaintenanceID)` |
| Attributes | `AcknowledgedAt` (DATETIME2, NOT NULL), optional `AcknowledgedByUserID` (FK → User; see Assumption A-P2-3) |
| Relationships | `BookingRequest (1) — (N) BookingAcknowledgement (N) — (1) MaintenanceRecord` (M:N resolved) |
| Rationale | Folding "acknowledged" onto `BookingRequest` or `MaintenanceRecord` would be wrong: an acknowledgement belongs to the **pair** (booking, maintenance). The skill directive: relationship data with its own identity gets its own table. |

> **Design note (directive 1 applied):** The acknowledgement is *not* a mere status flag on `BookingRequest`. A booking may coexist with one advisory (`Acknowledged = true`) and another (`Acknowledged = true`) — both need their own rows. `BookingAcknowledgement` is the only correct shape.

### 2.4. Affected business rules

| Rule | Status | Impact |
|------|--------|--------|
| BR3 / BR4 | **Modified** | Only maintenance with `ImpactLevel = 'OutOfService'` and status `Open/InProgress` blocks booking. Advisory maintenance no longer blocks; it triggers notification + acknowledgement. |
| BR4 | **Replaced by** BR18 | "A space with an active *out-of-service* maintenance record cannot be booked (overlapping periods)." |

### 2.5. Affected Phase 1 artifacts

- `02-erd-design-G10.md` — add `ImpactLevel` to `MaintenanceRecord`; add `BookingAcknowledgement` entity and its two relationships.
- `03-logical-design-G10.md` — new table `BookingAcknowledgement`; new column + CHECK on `MaintenanceRecord`.
- `05-db-definition-G10.md` — DDL for the new table, column, constraints, and index on `(MaintenanceID)` and `(BookingID)`.
- `06-sample-data-G10.md` / `07-query-design-G10.md` — advisory-acknowledgement sample rows and queries.

---

## 3. Change C2 — Multiple Simultaneous Active Maintenance Records

### 3.1. Analysis

Phase 1 did not forbid several open records on one space, but the schema neither helped nor documented it. Phase 2 now **requires** it (a space may have an `advisory` for the projector and an `out-of-service` for the floor at the same time).

### 3.2. Schema change needed: NO

The Phase 1 `MaintenanceRecord` already keys on `MaintenanceID` with `SpaceCode` as a plain FK; nothing prevents multiple open records on the same space. No uniqueness constraint should be added.

### 3.3. Enforcement impact

The booking-blocking rule must be evaluated per-record (any *open, out-of-service* record overlapping the requested window), not per-space "has any open maintenance". This is a **query logic** change (C1), not a schema change.

---

## 4. Change C3 — Escalation / Downgrade of Impact Level

### 4.1. Analysis

- Escalation `advisory → out-of-service` may occur while the maintenance is still open and while bookings are already approved.
- Downgrade `out-of-service → advisory` removes the blocking effect for future bookings.
- Both are simply **updates to `ImpactLevel`** on an existing row. Historical correctness is preserved because overlapping approved bookings are discovered from the stored time ranges at the moment of escalation.

### 4.2. Schema change needed: NO

Per directive 2, escalation requires **no new tables, columns, or constraints**. What is needed is an **Impact Analysis Query**:

- JOIN `MaintenanceRecord` (escalated record: `SpaceCode`, `StartTime`, `CompletionTime` or open → `GETUTCDATE()`) with `BookingRequest` (`SpaceCode`, `StartTime`, `EndTime`, `Status = 'Approved'`) on **overlapping time ranges**:
  `Booking.StartTime < Maintenance.End AND Booking.EndTime > Maintenance.Start`
- Result: the contact list of affected requesters (User → Booking → Requester) so staff can reach out.

### 4.3. Affected business rules

| New rule | Content |
|----------|---------|
| BR19 | A booking may be created on a space with advisory maintenance, provided the requester acknowledges each active advisory (`BookingAcknowledgement` row). |
| BR20 | Escalation/downgrade of `ImpactLevel` on an open maintenance record is allowed; on escalation to `OutOfService`, all already-approved bookings overlapping the maintenance period must be identifiable via the impact-analysis query. |

---

## 5. Change C4 — Instant (Auto) Approval

### 5.1. Analysis

Phase 2 introduces *instant booking*: for selected space types, requests satisfying the usage policy are approved automatically at submission time; everything else keeps the staff-approval workflow. Two sub-problems arise:

1. **Auditability:** `Approval.ApproverID` is NOT NULL (BR5). An instant approval has no human approver.
2. **Concurrency:** instant approvals happen at the exact moment of submission, exactly when many requests arrive simultaneously.

### 5.2. Schema change needed: NO new column, NO FK relaxation

Per directive 3:

- **Do NOT** remove the `ApproverID` FK / make it nullable.
- **Do NOT** add an `IsAutoApproved` flag column.
- **Instead:** insert a **Non-human System Actor** — a dedicated `User` row (e.g., `UserID = -1`, `FullName = 'System Auto-Approval', Role = 'FacilityManager', AccountStatus = 'Active'`) that instant-approval writes as `Approval.ApproverID`.

This preserves referential integrity, keeps the audit trail uniform ("who decided" always resolves to a user row), and makes auto-approval indistinguishable from human approval at the schema level — exactly what the business rule "record the staff member who made the decision" intends for auditability.

> **Design note (directive 3 applied):** the system actor is **data, not a schema trick**. Every `Approval` row still satisfies `FK_Approval_Approver`; reporting on "approvals by approver" continues to work unchanged.

### 5.3. Which requests qualify for instant approval

Eligibility is a business/policy decision (`SpaceType` in a configured set + request satisfies `UsagePolicy`). This is **application logic**, stored either in configuration or in the usage policy text; it does not require a new column on `Space` or `BookingRequest` in this analysis (see Open Question Q-P2-4).

---

## 6. Change C5 — Concurrency Control for Concurrent Booking & Approval

### 6.1. The conflict

Phase 1 relied on **application-level** time-window checks (BR2/BR17) to prevent overlapping approved bookings. Under Phase 2's "many requests at semester start" workload, that design is unsafe:

**Race condition scenario:**
1. Two users submit requests for the same space, overlapping window, at ~the same time.
2. Both application threads run the availability check (no overlap found — neither booking committed yet).
3. Both proceed to approval (one instant, one staff).
4. Both commit → **two approved bookings overlap**. The database never rejected them because no DB-level mechanism was involved.

Even with an application-level `SELECT` under default (READ COMMITTED) isolation, the two checks can read stale/absent rows and both pass. A backend-only time check is therefore insufficient (directive 4).

### 6.2. Schema change needed: not purely a schema change — database-level enforcement required

The fix must make the database the **single source of truth** for the invariant "no two approved bookings overlap on one space."

| Approach | Verdict |
|----------|---------|
| Application time-check only | **Rejected** — suffers the race above. |
| Serialized transaction + range/row lock (e.g., `UPDLOCK, HOLDLOCK` on the `Space` row, or `SERIALIZABLE` isolation) around check-then-insert | **Recommended** for SQL Server. Locking a parent row (`Space.SpaceCode`) serializes all booking/approval writers on that space so the overlap check + insert + approval commit atomically. |
| SQL Server **unique index on computed/overlap condition** | Not directly available (no exclusion constraints in SQL Server; that is a PostgreSQL feature). The locking/serializable approach is the SQL Server equivalent and is the correct DB-level guarantee. |
| Snapshot isolation (read committed snapshot / RCSI) | Helps read-write blocking but alone does **not** prevent the two-writer race; must be combined with the locking strategy. |

> **Design note (directive 4 applied):** the constraint is enforced in the DBMS transaction engine, not in the API. The application still performs the friendly checks, but the database enforces the invariant as the final gate.

### 6.3. Affected business rules

| Rule | Status | Impact |
|------|--------|--------|
| BR2 | **Strengthened** → BR21 | No two **approved** bookings may overlap on the same space; now guaranteed at the database level under concurrency, for both instant and staff-approved bookings. |
| BR17 | **Updated** | "Overlap prevention is application logic" is amended: final enforcement moves to the DB transaction engine (locking/serializable), application checks remain as a first-line filter. |

---

## 7. Change C6 — New Reporting Needs

### 7.1. Analysis

Four new reports (§1.3) must be supported:

| Report | Nature | Schema change needed? |
|--------|--------|------------------------|
| (a) Total approved booking hours per space per semester | Aggregation over `BookingRequest` (Status Approved) | **NO** |
| (b) Approved bookings by weekday & hour per semester | Aggregation over `BookingRequest` | **NO** |
| (c) Room finder: available spaces meeting capacity + required facility list in a time window | Multi-way JOIN: `Space` ⋈ `Facility` ⋈ anti-join against `BookingRequest` + `MaintenanceRecord` (out-of-service) | **NO** — but needs good indexes (handled in Step 15) |
| (d) Approved bookings affected by out-of-service escalation | Impact-analysis query from §4.2 (JOIN on overlapping ranges) | **NO** |

All four are expressible over the Phase 2 schema. They do **not** drive schema changes; they drive **query design (Step 16) and index tuning (Step 15)**.

### 7.2. Note on report (d) reusing C3

Report (d) is exactly the escalation impact query from §4.2. This confirms the design decision: no table for "affected bookings" — it is derived on demand from overlapping time ranges.

---

## 8. Consolidated Impact Matrix

### 8.1. Entities / Relationships

| Phase 1 element | Change type | Phase 2 action |
|-----------------|-------------|----------------|
| `MaintenanceRecord` | Attribute added | `ImpactLevel` (CHECK `Advisory`,`OutOfService`, DEFAULT `OutOfService`) |
| `BookingAcknowledgement` | **New entity** | Associative M:N between `BookingRequest` and `MaintenanceRecord`; PK `(BookingID, MaintenanceID)` |
| `BookingRequest` ⋈ `MaintenanceRecord` | **New relationship** (M:N) | Via `BookingAcknowledgement` (1:N each side) |
| `Approval` | No structural change | `ApproverID` keeps NOT NULL FK; system actor row supplies auto-approval identity |
| All other Phase 1 entities | No change | — |

### 8.2. Business rules

| Rule | Status | Summary of change |
|------|--------|-------------------|
| BR2 / BR17 | **Strengthened (BR21)** | Overlap invariant enforced at DB level under concurrency |
| BR4 | **Replaced (BR18)** | Only open *out-of-service* maintenance blocks overlapping bookings |
| BR5 | **Unchanged structurally** | Instant approvals use the system actor as `ApproverID` |
| (new) BR19 | Added | Advisory acknowledgement recorded per (booking, advisory) pair |
| (new) BR20 | Added | Escalation/downgrade allowed; escalation triggers impact query |

### 8.3. Phase 1 documents to update (upstream of later Phase 2 steps)

| Document | Update |
|----------|--------|
| `02-erd-design-G10.md` | `BookingAcknowledgement` entity, `ImpactLevel` attribute, new relationships, updated cardinalities |
| `03-logical-design-G10.md` | New relation + FKs (NO ACTION), new column/CHECK; updated BR enforcement table |
| `05-db-definition-G10.md` | DDL: `BookingAcknowledgement` table, `ImpactLevel`, indexes; concurrency notes |
| `06/07` sample data & queries | Advisory acknowledgements, impact-analysis query, report queries |

---

## 9. New Assumptions (Phase 2)

| # | Assumption |
|---|-----------|
| A-P2-1 | A maintenance record has **exactly one impact level** at any moment; escalation/downgrade is an in-place `UPDATE` (no audit history required in this step). |
| A-P2-2 | `BookingAcknowledgement.AcknowledgedAt` defaults to submission time; the acknowledgement is a **prerequisite** to creating the booking, not a later opt-in. |
| A-P2-3 | `BookingAcknowledgement.AcknowledgedByUserID` is recorded (the requester) for traceability; derivable from the booking if omitted. |
| A-P2-4 | The **set of instant-bookable space types** and the usage-policy conditions are configuration; no schema change (confirmed assumption — see Q-P2-4). |
| A-P2-5 | "Approved" for reporting means `BookingRequest.Status IN ('Approved','CheckedIn','Completed','NoShow')` — statuses that were approved and whose overlap blocks the space; `Rejected/Cancelled/Pending` are excluded. |

---

## 10. Open Questions

| # | Question |
|---|----------|
| Q-P2-1 | Should escalation history be preserved (e.g., an `ImpactLevelHistory`/log table), or is in-place update acceptable per A-P2-1? |
| Q-P2-2 | When a booking request is rejected **because** of an out-of-service overlap found at approval time, must the acknowledgement rows be retained for audit? |
| Q-P2-3 | Does the system actor need its own `User` row per environment, or is a fixed sentinel `UserID` acceptable? |
| Q-P2-4 | Which exact `SpaceType` values and usage-policy clauses qualify a request for instant approval? |
| Q-P2-5 | For concurrency enforcement, is `SERIALIZABLE` on the whole transaction acceptable for the expected booking volume, or should a narrower `UPDLOCK/HOLDLOCK` on the `Space` row be the standard? (Performance addressed in Step 15.) |

---

## 11. Design Decisions Summary (Traceability to Directives)

| # | Phase 2 issue | Decision | Directive |
|---|---------------|----------|-----------|
| D1 | Advisory vs. out-of-service | New attribute `MaintenanceRecord.ImpactLevel` | 1 |
| D2 | Recording "requester informed" | New associative entity `BookingAcknowledgement` | 1 |
| D3 | Escalation identifies affected bookings | Impact Analysis Query (overlapping-range JOIN); **no schema change** | 2 |
| D4 | Auto-approval auditability | Non-human System Actor `User` as `ApproverID`; **no new column, no FK relaxation** | 3 |
| D5 | Concurrent overlap prevention | **DB-level** enforcement (SERIALIZABLE / UPDLOCK+HOLDLOCK); application checks are only a first-line filter | 4 |

---

## 12. Next Steps (not executed in this step)

1. **Step 9 — Updated ERD & Logical Design** (`09-updated-erd-and-logical-design-G10.md`): apply C1–C5 to the ERD and relational schema.
2. **Step 10 — Schema Migration** (`10-schema-migration-G10.sql`): additive migration (new column with default, new table, new indexes; system actor row).
3. **Step 11/12/13 — Concurrency design, implementation, tests**.
4. **Step 14 — Data generator** (≥100,000 bookings, 3 academic years, including acknowledgements).
5. **Steps 15/16 — Index tuning & analytical queries** for C6 reports.
