# 04 — Database Design Validation

Validates the relational schema (`outputs/03-logical-design.md`) against the conceptual ERD (`outputs/02-erd-design.md`) and the business rules (`outputs/01-business-req-analysis.md`).

---

## 1. Schema ↔ ERD Conformance

### 1.1. Entity coverage
Every ERD entity maps to exactly one relation — no entities lost, merged, or invented.

| ERD Entity | Relation | Result |
|------------|----------|--------|
| User | User | ✓ |
| Space | Space | ✓ |
| Facility | Facility | ✓ |
| BookingRequest | BookingRequest | ✓ |
| Approval | Approval | ✓ |
| UsageSession | UsageSession | ✓ |
| MaintenanceRecord | MaintenanceRecord | ✓ |

### 1.2. Relationship coverage
All 12 ERD relationships are represented explicitly by FK columns.

| Relationship (ERD §3) | Representation in schema | Cardinality preserved | Result |
|------------------------|--------------------------|----------------------|--------|
| Submits | `BookingRequest.RequesterID` → User | 1:N ✓ | ✓ |
| Targets | `BookingRequest.SpaceCode` → Space | N:1 ✓ | ✓ |
| Approves | `Approval.ApproverID` → User | 1:N ✓ | ✓ |
| Decides-on | `Approval.BookingID` = PK + FK → BookingRequest | 1:1 ✓ | ✓ |
| Records | `UsageSession.BookingID` = PK + FK → BookingRequest | 1:1 ✓ | ✓ |
| Validates | `UsageSession.ApprovalID` → Approval | 1:1 ✓ | ✓ |
| Checks-in | `UsageSession.CheckInStaffID` → User | 1:N ✓ | ✓ |
| Houses | `Facility.SpaceCode` → Space | 1:N ✓ | ✓ |
| Reports | `MaintenanceRecord.ReporterID` → User | 1:N ✓ | ✓ |
| Assigned-to | `MaintenanceRecord.AssignedStaffID` → User | 1:N ✓ | ✓ |
| Affects | `MaintenanceRecord.SpaceCode` → Space | 1:N ✓ | ✓ |
| Concerns | `MaintenanceRecord.FacilityID` → Facility | 1:N ✓ | ✓ |

### 1.3. Participation constraints
- Mandatory participants are NOT NULL FKs: `RequesterID`, `BookingRequest.SpaceCode`, `Approval.ApproverID`, `Facility.SpaceCode`, `UsageSession.ApprovalID`, `UsageSession.CheckInStaffID`, `MaintenanceRecord.SpaceCode`, `MaintenanceRecord.ReporterID`. ✓
- Optional participants are nullable: `AssignedStaffID`, `FacilityID`, and the completion columns (`ActualEndTime`, `FinalCondition`, `UsageNotes`, `CompletionTime`, `ResultNote`). ✓
- 1:1 relationships reuse the parent PK as the child PK (`Approval.BookingID`, `UsageSession.BookingID`) — no surrogate keys added, per the modeling rule. ✓
- Relationship attributes are not folded into participating entities: decision data lives in `Approval`, check-in/check-out data in `UsageSession`. ✓

**Verdict: schema is a faithful representation of the ERD.**

---

## 2. Business Rule Satisfaction

| # | Rule | Satisfied? | Where / How |
|---|------|-----------|-------------|
| BR1 | University account required to book | ✓ (partial DDL) | FK `BookingRequest.RequesterID` NOT NULL; requester-role validation at application level |
| BR2 | No overlapping approved bookings for same space | ⚠ Application | No DDL equivalent; enforced by validation query + transaction isolation (risk 4.1) |
| BR3 | Under-maintenance / closed / retired space not bookable | ⚠ Application | Depends on `Space.CurrentStatus`; no DDL trigger |
| BR4 | Space with active unresolved maintenance not bookable | ⚠ Application | Depends on live `MaintenanceRecord` rows |
| BR5 | Approval records approver, decision time, note; rejection reason on rejection | ✓ (partial DDL) | NOT NULL on ApproverID/DecisionTime/DecisionNote; conditional rejection reason at application level |
| BR6 | Check-in records actual start, staff, initial condition | ✓ DDL | NOT NULL on `ActualStartTime`, `CheckInStaffID`, `InitialCondition` |
| BR7 | Check-out records actual end, final condition, usage notes | ✓ | Nullable columns written at completion |
| BR8 | UsageSession only after a valid approval | ✓ (structural) | NOT NULL FK `UsageSession.ApprovalID` (see risk 4.2) |
| BR9 | Facilities are individual units in one space | ✓ DDL | Surrogate `FacilityID` PK + NOT NULL FK `Facility.SpaceCode` |
| BR10 | Preserve historical records, no hard deletes | ✓ | All FKs NO ACTION; status flags instead of deletes |
| BR11–15 | Domain + numeric + ordering constraints | ✓ DDL | CHECK constraints listed in §3/03 |
| BR16 | Only FacilityStaff/Manager approve, check in, are assigned | ⚠ Application | Role-based access checks (not expressible in DDL) |
| BR17 | Overlap/status prevention via application logic | ✓ | Documented as application-level |

**Verdict: all business rules are either enforced by DDL or explicitly assigned to application logic; none are silently dropped.**

---

## 3. Normalization Check

Functional dependencies per relation (PK → all attributes):

| Relation | Candidate keys | Normal form |
|----------|----------------|-------------|
| User | UserID; Email | 3NF / BCNF |
| Space | SpaceCode; (Building, Floor, RoomNumber)* | 3NF / BCNF |
| Facility | FacilityID | 3NF / BCNF |
| BookingRequest | BookingID | 3NF / BCNF |
| Approval | BookingID | 3NF / BCNF |
| UsageSession | BookingID | 3NF / BCNF |
| MaintenanceRecord | MaintenanceID | 3NF / BCNF |

- No partial dependencies (all PKs are single-column).
- No transitive dependencies (no non-key attribute determines another non-key attribute).
- No multi-valued attributes; no repeating groups.

**Verdict: every relation is in at least 3NF (BCNF).** No decomposition required.
*(A9: the second candidate key for Space is contingent on the assumption that no two rooms share the same building+floor+room number.)*

---

## 4. Identified Risks & Design Notes

### 4.1. Overlap prevention is application-level (BR2)
There is no DDL construct in SQL Server that enforces "no two approved bookings for the same space with overlapping intervals" (a CHECK cannot read other rows/tables).
**Mitigation:** validate on insert/update within a transaction using `UPDLOCK`/`HOLDLOCK` on the Space row or a serializable scan of `BookingRequest` for the same `SpaceCode` + overlapping `[StartTime, EndTime)` and active status (`Approved`, `CheckedIn`). Acceptance test required (Step 6).

### 4.2. `UsageSession.ApprovalID` guarantees *an* approval, not *an approval* (BR8 nuance)
An Approval row is created for both approved and rejected decisions (RejectionReason on rejected). The FK therefore ensures a decision record exists, but does not by itself prove the decision was **Approved**.
**Mitigation:** the application must additionally require `BookingRequest.Status IN (Approved, CheckedIn)` before creating a UsageSession. Optionally, add a `Decision` column to `Approval` (Approved/Rejected) — open question Q9. Recorded so it is not silently relied upon.

### 4.3. `Space.CurrentStatus = 'InUse'` can drift
`InUse` may be maintained manually or derived from active sessions (A2/Q7). If maintained manually, it can disagree with actual UsageSessions.
**Mitigation:** prefer deriving "in use" from open UsageSessions (`ActualEndTime IS NULL`) and treat `InUse` as informational; confirm in Q7.

### 4.4. Facility permanence assumption (Q8)
`Facility.SpaceCode` is NOT NULL, modeling permanent attachment to one space. If units may be relocated, this becomes a nullable/audited attribute.
**Mitigation:** confirmed assumption; revisit if movability is required.

### 4.5. Rejection reason conditionality (BR5)
Cannot be a CHECK (depends on `BookingRequest.Status` across tables).
**Mitigation:** application-level validation on decision write; optionally a stored procedure wrapping approval creation.

---

## 5. Key, Relationship & Constraint Appropriateness

| Decision | Assessment |
|----------|-----------|
| Surrogate `UserID` PK + `Email` UNIQUE | ✓ Appropriate; handles university-account identity without email churn |
| Natural `SpaceCode` PK | ✓ Requirement states it is unique; stable business identifier |
| Surrogate `FacilityID` (unit-level) | ✓ Required to reference individual physical units in maintenance (BR9) |
| Surrogate `BookingID` | ✓ Standard for transactional records |
| `BookingID` reused as PK in Approval & UsageSession | ✓ Correct for mandatory 1:1; prevents a second approval/session per booking |
| All FKs `NO ACTION` | ✓ Consistent with no-hard-delete history policy (BR10) |
| CHECK constraints for all enum domains + numeric rules | ✓ Matches requirement domains exactly (BR11–15) |
| NOT NULL on mandatory FK/columns | ✓ Matches ERD mandatory participation |

---

## 6. Residual Open Questions (from Step 1/3)

| # | Question | Impact if unconfirmed |
|---|----------|----------------------|
| Q1/A5 | Optional `FacilityID` in MaintenanceRecord | Schema already optional — low risk |
| A9 | Unique (Building, Floor, RoomNumber) | Only an extra UNIQUE constraint — low risk |
| Q2 | Role-restricted space types | Application logic only |
| Q3/Q5/Q6 | Lead time, recurring bookings, max duration | Application logic only |
| Q4 | Edit-after-submit bookings | Application logic only |
| Q7 | Definition of `InUse` | Affects 4.3 |
| Q8 | Facility movability | Affects `Facility.SpaceCode` nullability (4.4) |
| Q9 | Record approval for rejected bookings / Decision column | Affects 4.2 |

---

## 7. Overall Verdict

The relational schema **correctly represents the ERD**, **satisfies all business rules** (by DDL or explicitly assigned application logic), and **uses appropriate keys, relationships, and constraints**. Relations are normalized to 3NF/BCNF. The two points requiring discipline in the application layer are interval-overlap prevention (BR2) and the "approved, not merely decided" check before check-in (4.2); both are documented and testable rather than silently assumed.

**Result: PASS — proceed to Step 5 (Database Definition / DDL).**