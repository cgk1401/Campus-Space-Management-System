# 04 — Design Validation

---

## 1. ERD-to-Schema Mapping Verification

| ERD Entity | Relational Table | Status |
|-----------|-----------------|--------|
| User | `User` | ✓ |
| Space | `Space` | ✓ |
| FacilityType | `FacilityType` | ✓ |
| SpaceFacility | `SpaceFacility` | ✓ |
| BookingRequest | `BookingRequest` | ✓ |
| Approval | `Approval` | ✓ |
| UsageSession | `UsageSession` | ✓ |
| MaintenanceRecord | `MaintenanceRecord` | ✓ |

| ERD Relationship | Mapping | Status |
|-----------------|---------|--------|
| User —o{ BookingRequest ("submits") | FK `BookingRequest.RequesterID` | ✓ |
| BookingRequest }o—|| Space ("targets") | FK `BookingRequest.SpaceCode` | ✓ |
| BookingRequest ||—o| Approval ("has") | PK/FK `Approval.BookingID` | ✓ |
| User —o{ Approval ("decides") | FK `Approval.ApproverID` | ✓ |
| BookingRequest ||—o| UsageSession ("records") | PK/FK `UsageSession.BookingID` | ✓ |
| User —o{ UsageSession ("checks-in") | FK `UsageSession.CheckInStaffID` | ✓ |
| Space —o{ SpaceFacility ("contains") | FK `SpaceFacility.SpaceCode` | ✓ |
| FacilityType —o{ SpaceFacility ("typed-by") | FK `SpaceFacility.FacilityName` | ✓ |
| User —o{ MaintenanceRecord ("reports") | FK `MaintenanceRecord.ReporterID` | ✓ |
| User —o{ MaintenanceRecord ("assigned-to") | FK `MaintenanceRecord.AssignedStaffID` | ✓ |
| Space —o{ MaintenanceRecord ("undergoes") | FK `MaintenanceRecord.SpaceCode` | ✓ |

**All 8 entities and 11 relationships from the ERD are correctly represented in the relational schema.** ✓

---

## 2. Business Rules Compliance

| # | Rule | Enforceable via DDL? | Mechanism | Status |
|---|------|---------------------|-----------|--------|
| BR1 | Users must have a university account. | Yes | `User.UserID` as PK; all user fields are NOT NULL | ✓ |
| BR2 | No overlapping bookings for same space. | No (interval overlap) | Application-level validation | ⚠️ *see §7* |
| BR3 | Blocked spaces (Maint/Closed/Retired) cannot be booked. | Partial | `Space.CurrentStatus` CHECK constraint; application enforces check at booking time | ✓ |
| BR4 | Active maintenance blocks booking. | No | Application-level check against unresolved `MaintenanceRecord` rows | ⚠️ *see §7* |
| BR5 | Approval records approver, time, note, rejection reason. | Yes | `Approval` table includes all four columns | ✓ |
| BR6 | Check-in records start time, staff, initial condition. | Yes | `UsageSession` has `ActualStartTime`, `CheckInStaffID`, `InitialCondition` | ✓ |
| BR7 | Check-out records end time, final condition, notes. | Yes | `UsageSession` has `ActualEndTime`, `FinalCondition`, `UsageNotes` | ✓ |
| BR8 | Facility types as lookup list, not individual units. | Yes | `FacilityType` table as controlled vocabulary | ✓ |
| BR9 | Space-facility keyed by (SpaceCode, FacilityName). | Yes | Composite PK on `SpaceFacility` | ✓ |
| BR10 | Preserve historical records. | Yes (design) | NO ACTION on historical FKs; soft-delete via status fields | ✓ |
| BR11 | Purpose of use restricted to enumerated values. | Yes | CHECK on `BookingRequest.Purpose` | ✓ |
| BR12 | Capacity > 0. | Yes | CHECK on `Space.Capacity` | ✓ |
| BR13 | EndTime > StartTime. | Yes | CHECK on `BookingRequest.EndTime > BookingRequest.StartTime` | ✓ |

**11 of 13 rules are fully DDL-enforceable. Rules BR2 and BR4 require application logic.** ✓

---

## 3. Key and Constraint Validation

### 3.1. Primary Keys

| Table | PK | Rationale | Status |
|-------|----|-----------|--------|
| User | `UserID` (surrogate) | Natural keys (Email) are mutable; surrogate avoids cascading changes. | ✓ |
| Space | `SpaceCode` (natural) | Business-provided unique code, stable identifier. | ✓ |
| FacilityType | `FacilityName` (natural) | Short controlled vocabulary, no surrogate needed. | ✓ |
| SpaceFacility | `(SpaceCode, FacilityName)` composite | Per BR9 — no surrogate needed. | ✓ |
| BookingRequest | `BookingID` (surrogate) | No meaningful natural key; identity simplifies references. | ✓ |
| Approval | `BookingID` (PK = parent FK) | 1:1 relationship; parent PK used as child PK per modeling rules. | ✓ |
| UsageSession | `BookingID` (PK = parent FK) | 1:1 relationship; parent PK used as child PK per modeling rules. | ✓ |
| MaintenanceRecord | `MaintenanceID` (surrogate) | No meaningful natural key. | ✓ |

### 3.2. Foreign Keys

| FK | Child Table | Parent Table | ON DELETE | Appropriate? |
|----|------------|-------------|-----------|-------------|
| RequesterID | BookingRequest | User | NO ACTION | ✓ History preservation |
| SpaceCode | BookingRequest | Space | NO ACTION | ✓ History preservation |
| BookingID | Approval | BookingRequest | CASCADE | ✓ No independent meaning |
| ApproverID | Approval | User | NO ACTION | ✓ History preservation |
| BookingID | UsageSession | BookingRequest | CASCADE | ✓ No independent meaning |
| CheckInStaffID | UsageSession | User | NO ACTION | ✓ History preservation |
| SpaceCode | SpaceFacility | Space | CASCADE | ✓ Current config only |
| FacilityName | SpaceFacility | FacilityType | NO ACTION | ✓ Prevents orphaned refs |
| SpaceCode | MaintenanceRecord | Space | NO ACTION | ✓ History preservation |
| ReporterID | MaintenanceRecord | User | NO ACTION | ✓ History preservation |
| AssignedStaffID | MaintenanceRecord | User | SET NULL | ✓ Optional FK; preserves record if staff leaves |

### 3.3. Candidate Keys (UNIQUE constraints)

| Table | Candidate Key | Status |
|-------|--------------|--------|
| User | `Email` | ✓ |
| Space | `(Building, Floor, RoomNumber)` | ✓ |

### 3.4. CHECK Constraints

| Constraint | Table | Status |
|-----------|-------|--------|
| Role IN (...) | User | ✓ |
| AccountStatus IN ('Active','Disabled') | User | ✓ |
| SpaceType IN (...) | Space | ✓ |
| CurrentStatus IN (...) | Space | ✓ |
| Capacity > 0 | Space | ✓ |
| Purpose IN (...) | BookingRequest | ✓ |
| Booking Status IN (...) | BookingRequest | ✓ |
| EndTime > StartTime | BookingRequest | ✓ |
| ExpectedParticipants > 0 | BookingRequest | ✓ |
| Maintenance Status IN (...) | MaintenanceRecord | ✓ |

---

## 4. Normalization Analysis

### 4.1. Unnormalized Form (UNF) check
No repeating groups or multi-valued attributes exist in any table. Every cell is atomic (1NF). ✓

### 4.2. Second Normal Form (2NF) check
- All tables with single-column PKs: all non-key attributes depend on the whole PK. ✓
- `SpaceFacility` has a composite PK but zero non-key attributes, so 2NF is trivially satisfied. ✓

### 4.3. Third Normal Form (3NF) check
- No transitive dependencies exist in any table. All non-key attributes are directly dependent on the PK. ✓

### 4.4. Boyce-Codd Normal Form (BCNF) check
- Every determinant in every table is a candidate key. The schema is in BCNF. ✓

**Conclusion: The schema satisfies BCNF.** ✓

---

## 5. Modeling Rules Compliance

| Rule from Skill | Compliance | Evidence |
|----------------|-----------|----------|
| Each named relationship represented explicitly | ✓ | 11 relationships, all with explicit FK/PK mappings |
| 1:1 uses parent PK as child PK | ✓ | `Approval.BookingID` and `UsageSession.BookingID` |
| Relationship attributes get their own table | ✓ | Approval (decision info), UsageSession (check-in/out info) |
| Only junction table for M:N or attributed relationships | ✓ | SpaceFacility junction table for M:N; Approval/UsageSession for attributed 1:1 |
| 1:N without attributes: FK on child table | ✓ | All 1:N relationships use FK on child |

---

## 6. Role-Based Access Constraint Coverage

| Constraint | Documented in Step 3? | Enforceable via DDL? |
|-----------|----------------------|---------------------|
| Only FacilityStaff/Manager can approve | ✓ (application-level) | No — role check requires application logic |
| Only FacilityStaff/Manager can check-in | ✓ (application-level) | No — role check requires application logic |
| Only FacilityStaff/Manager can be assigned maintenance | ✓ (application-level) | No — role check requires application logic |
| Any role can report maintenance | ✓ (application-level) | No — no restriction needed |

---

## 7. Identified Limitations & Notes

| Issue | Description | Mitigation |
|-------|-------------|------------|
| Overlap prevention (BR2) | SQL CHECK cannot reference other rows. DDL alone cannot prevent overlapping time intervals for the same SpaceCode. | Must be enforced via a transactional application-level check or a schedule-based exclusion constraint (e.g., a trigger or indexed view with `UNIQUE` on `(SpaceCode, time_slot)` — though SQL Server does not natively support exclusion constraints). |
| Active maintenance blocks booking (BR4) | Requires checking if any unresolved `MaintenanceRecord` exists for a SpaceCode at the time of booking. | Application-level validation before insert/update. |
| Rejection reason required when rejected (BR5) | A CHECK constraint cannot conditionally require a column based on another table's value. | Application-level validation. |
| Status transition integrity | Schema allows invalid transitions (e.g., 'Pending' → 'Completed' without 'CheckedIn'). | Application-level state machine enforcement. |
| `InUse` space status | The `CurrentStatus` on `Space` is denormalized — it can be derived from active `UsageSession` records. Kept for query convenience but requires synchronization. | Application must update `Space.CurrentStatus` when sessions start/end, or derive it via a view. |
| No upper bound on `Capacity` or `ExpectedParticipants` | Reasonable but not constrained. | Optional: add `CHECK (Capacity <= 1000)` or similar. |
