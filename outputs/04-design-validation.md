# 04 — Database Design Validation

## 1. ERD → Relational Schema Mapping

### 1.1. Entity Coverage

| ERD Entity | Logical Table | Status |
|------------|--------------|--------|
| User | [User] | ✅ Present |
| Space | [Space] | ✅ Present |
| Facility | [Facility] | ✅ Present |
| BookingRequest | [BookingRequest] | ✅ Present |
| Approval | [Approval] | ✅ Present |
| UsageSession | [UsageSession] | ✅ Present |
| MaintenanceRecord | [MaintenanceRecord] | ✅ Present |

All 7 entities from the ERD are mapped to relational tables with no omissions.

---

### 1.2. Relationship Mapping

| ERD Relationship | Logical Implementation | Status |
|-----------------|----------------------|--------|
| R1: User (1) → BookingRequest (N) | `BookingRequest.RequesterID` FK → `User.UserID` | ✅ |
| R2: Space (1) → BookingRequest (N) | `BookingRequest.SpaceCode` FK → `Space.SpaceCode` | ✅ |
| R3: BookingRequest (1) → Approval (1) | `Approval.BookingID` FK (UNIQUE) → `BookingRequest.BookingID` | ✅ |
| R4: User (1) → Approval (N) | `Approval.ApproverID` FK → `User.UserID` | ✅ |
| R5: Space (1) → Facility (N) | `Facility.SpaceCode` FK → `Space.SpaceCode` | ✅ |
| R6: Space (1) → MaintenanceRecord (N) | `MaintenanceRecord.SpaceCode` FK → `Space.SpaceCode` | ✅ |
| R7: User (1) → MaintenanceRecord (N) [reporter] | `MaintenanceRecord.ReporterID` FK → `User.UserID` | ✅ |
| R8: User (1) → MaintenanceRecord (N) [assigned] | `MaintenanceRecord.AssignedStaffID` FK (nullable) → `User.UserID` | ✅ |
| R9: User (1) → UsageSession (N) [check-in staff] | `UsageSession.CheckInStaffID` FK → `User.UserID` | ✅ |
| R10: BookingRequest (1) → UsageSession (1) | `UsageSession.BookingID` PK,FK → `BookingRequest.BookingID` | ✅ |

All 10 relationships from the ERD are correctly mapped.

---

### 1.3. Participation Constraint Verification

| Relationship | ERD Participation | Schema Enforcement | Status |
|-------------|-------------------|-------------------|--------|
| R1: User → BookingRequest | User: optional, Booking: mandatory | RequesterID = NOT NULL | ✅ |
| R2: Space → BookingRequest | Space: optional, Booking: mandatory | SpaceCode = NOT NULL | ✅ |
| R3: BookingRequest → Approval | Booking: optional, Approval: mandatory | BookingID in Approval = NOT NULL | ✅ |
| R4: User → Approval | User: optional, Approval: mandatory | ApproverID = NOT NULL | ✅ |
| R5: Space → Facility | Space: optional, Facility: mandatory | SpaceCode = NOT NULL | ✅ |
| R6: Space → MaintenanceRecord | Space: optional, Maintenance: mandatory | SpaceCode = NOT NULL | ✅ |
| R7: User → MaintenanceRecord [reporter] | User: optional, Maintenance: mandatory | ReporterID = NOT NULL | ✅ |
| R8: User → MaintenanceRecord [assigned] | User: optional, Maintenance: optional | AssignedStaffID = NULL | ✅ |
| R9: User → UsageSession | User: optional, Session: mandatory | CheckInStaffID = NOT NULL | ✅ |
| R10: BookingRequest → UsageSession | Booking: optional, Session: mandatory | BookingID = NOT NULL | ✅ |

All participation constraints are accurately enforced.

---

## 2. Business Rule Satisfaction

| ID | Rule | Enforcement | Status |
|----|------|-------------|--------|
| BR1 | Unique Booking ID | `BookingID` is PK on `BookingRequest` | ✅ PK |
| BR2 | No overlapping bookings | Noted as trigger/application-level constraint (beyond declarative CHECK) | ⚠️ Application-enforced |
| BR3 | Unavailable space cannot be booked | Application must check `CurrentStatus` and active `MaintenanceRecord` | ⚠️ Application-enforced |
| BR4 | Approval tracking | `Approval` table records `ApproverID`, `DecisionTime`, `DecisionNote`, `RejectionReason` | ✅ |
| BR5 | Check-in/Check-out recording | `UsageSession` with actual start/end times, conditions, notes | ✅ |
| BR6 | Maintenance blocks booking | Application checks active (Reported/InProgress) `MaintenanceRecord` | ⚠️ Application-enforced |
| BR7 | Historical records | All tables use status fields; no physical deletes | ✅ |
| BR8 | University account required | All user FKs reference `User` table | ✅ |
| BR9 | Status lifecycle | CHECK constraint limits `BookingRequest.Status` to valid values | ✅ |

**Key Observation:** Rules BR2, BR3, and BR6 require application-layer or trigger-based enforcement because they involve:
- Temporal overlap detection (BR2) — not expressible as a simple CHECK constraint
- Cross-table state validation (BR3, BR6) — queries must check Space statuses and active maintenance records at booking time

These are correctly identified in the logical design as requiring application-level enforcement.

---

## 3. Key & Constraint Analysis

### 3.1. Primary Keys

| Table | PK | Assessment |
|-------|----|-----------|
| User | `UserID` (INT) | ✅ Surrogate key; Email is alternate candidate |
| Space | `SpaceCode` (VARCHAR(20)) | ✅ Natural unique code; appropriate |
| Facility | `FacilityID` (INT) | ✅ Surrogate key; dependent on Space |
| BookingRequest | `BookingID` (INT) | ✅ Surrogate key |
| Approval | `ApprovalID` (INT) | ✅ Surrogate key; `BookingID` is alternate unique |
| UsageSession | `BookingID` (INT) | ✅ Shares PK with BookingRequest for 1:1 |
| MaintenanceRecord | `MaintenanceID` (INT) | ✅ Surrogate key |

### 3.2. Foreign Keys — Referential Integrity

| FK | ON DELETE | Assessment |
|----|-----------|-----------|
| Facility.SpaceCode → Space | CASCADE | ✅ Correct — facility is existence-dependent on space |
| BookingRequest.RequesterID → User | NO ACTION | ✅ Correct — prevents orphaned bookings on user deletion |
| BookingRequest.SpaceCode → Space | NO ACTION | ✅ Correct — prevents orphaned bookings on space deletion |
| Approval.BookingID → BookingRequest | CASCADE | ✅ Correct — approval is existence-dependent on booking |
| Approval.ApproverID → User | NO ACTION | ✅ Correct — preserves audit trail |
| UsageSession.BookingID → BookingRequest | CASCADE | ✅ Correct — session is existence-dependent on booking |
| UsageSession.CheckInStaffID → User | NO ACTION | ✅ Correct — preserves audit trail |
| MaintenanceRecord.SpaceCode → Space | CASCADE | ✅ Correct — record is existence-dependent on space |
| MaintenanceRecord.ReporterID → User | NO ACTION | ✅ Correct — preserves audit trail |
| MaintenanceRecord.AssignedStaffID → User | SET NULL | ✅ Correct — record persists if assignee leaves |

### 3.3. CHECK Constraints

| Table | Constraint | Assessment |
|-------|-----------|-----------|
| User | Role | ✅ Covers all 6 roles |
| User | AccountStatus | ✅ Covers Active, Inactive, Suspended |
| Space | SpaceType | ✅ Covers all 6 space types |
| Space | CurrentStatus | ✅ Covers all 5 statuses |
| Space | Capacity > 0 | ✅ Prevents invalid capacity |
| Facility | FacilityName | ✅ Covers all 6 facility types (hardcoded — note: adding a new type requires schema change) |
| BookingRequest | RequestedEndTime > RequestedStartTime | ✅ Prevents zero/negative duration |
| BookingRequest | PurposeOfUse | ✅ Covers all 7 purposes |
| BookingRequest | ExpectedParticipants > 0 | ✅ Prevents invalid participant count |
| BookingRequest | Status | ✅ Covers all 7 statuses |
| MaintenanceRecord | Status | ✅ Covers all 4 statuses |

### 3.4. Candidate Keys

| Table | Candidate Keys | Status |
|-------|---------------|--------|
| User | UserID (PK), Email (UK) | ✅ |
| Space | SpaceCode (PK) | ✅ — (Building, Floor, RoomNumber) could serve as natural composite key but surrogate is acceptable |
| Facility | FacilityID (PK) | ✅ |
| BookingRequest | BookingID (PK) | ✅ |
| Approval | ApprovalID (PK), BookingID (UK) | ✅ |
| UsageSession | BookingID (PK) | ✅ |
| MaintenanceRecord | MaintenanceID (PK) | ✅ |

---

## 4. Normalization Assessment

| Table | NF | Assessment |
|-------|----|-----------|
| User | 3NF | ✅ No repeating groups, no partial/transitive dependencies |
| Space | 3NF | ✅ All attributes depend only on SpaceCode |
| Facility | 3NF | ✅ Dependent on SpaceCode via FK |
| BookingRequest | 3NF | ✅ All attributes depend only on BookingID |
| Approval | 3NF | ✅ All attributes depend only on ApprovalID |
| UsageSession | 3NF | ✅ All attributes depend only on BookingID |
| MaintenanceRecord | 3NF | ✅ All attributes depend only on MaintenanceID |

All tables satisfy at least **Third Normal Form (3NF)**. No denormalization was applied unnecessarily.

---

## 5. Validation Against Summary Business Requirements Checklist

| Section | Requirement | Coverage | Status |
|---------|------------|----------|--------|
| 1.2 | User attributes (ID, Name, Email, Phone, Role, Dept, Status) | All present in [User] | ✅ |
| 1.2 | User roles (6 types) | CHECK constraint covers all 6 | ✅ |
| 1.3 | Space attributes (code, name, type, building, floor, room, capacity, status, policy) | All present in [Space] | ✅ |
| 1.3 | Space statuses (5 values) | CHECK constraint covers all 5 | ✅ |
| 1.3 | Facilities list (6 items) | [Facility] entity with CHECK constraint | ✅ |
| 1.4 | Booking attributes (space, times, purpose, participants, status) | All present in [BookingRequest] | ✅ |
| 1.4 | Booking statuses (7 values) | CHECK constraint covers all 7 | ✅ |
| 1.4 | Conflict prevention (BR2) | Noted as application-enforced | ⚠️ |
| 1.4 | Unavailable space restriction (BR3) | Noted as application-enforced | ⚠️ |
| 1.5 | Approval tracking (approver, time, note, rejection reason) | All present in [Approval] | ✅ |
| 1.6 | Check-in (start time, staff, initial condition) | All in [UsageSession] | ✅ |
| 1.6 | Check-out (end time, final condition, notes) | All in [UsageSession] | ✅ |
| 1.7 | Maintenance attributes (space, reporter, assignee, description, times, status, result) | All present in [MaintenanceRecord] | ✅ |
| 1.7 | Maintenance blocks booking (BR6) | Noted as application-enforced | ⚠️ |
| 1.8 | Historical records, booking history, upcoming bookings, maintenance view, no-show view | All data preserved; queryable via SELECT | ✅ |

---

## 6. Identified Observations & Potential Improvements

| # | Observation | Severity | Suggestion |
|---|------------|----------|------------|
| 1 | `Facility.FacilityName` CHECK is hardcoded to specific values | Low | Consider a lookup table (`FacilityType`) if extensibility is needed |
| 2 | No `CheckOutStaffID` in `UsageSession` — staff completing the session is not recorded | Low | Not explicitly required, but could be useful for audit |
| 3 | No CHECK ensuring `Approval.RejectionReason` IS NOT NULL when status is Rejected | Medium | Noted as "application-enforced" — a trigger could enforce this at DB level |
| 4 | No CHECK ensuring `ExpectedParticipants` ≤ `Space.Capacity` | Low | Application-level validation is reasonable; not an error |
| 5 | Overlapping booking prevention (BR2) relies entirely on application/trigger | Medium | An indexed view with unique constraint on (SpaceCode, time range) is an alternative in MS SQL Server |
| 6 | Space status 'InUse' vs 'UnderMaintenance' — no explicit DB rule prevents booking when status is 'TemporarilyClosed' or 'Retired' | Medium | Application-enforced; noted correctly |
| 7 | `BookingRequest.Status` values include both requester-driven ('Cancelled') and system-driven states — no constraint prevents illegal transitions (e.g., Rejected → Approved) | Low | Application should enforce state machine logic |

---

## 7. Validation Conclusion

| Criterion | Result |
|-----------|--------|
| Correctly represents the ERD | ✅ All entities, relationships, cardinalities, and participations are faithfully mapped |
| Satisfies all business rules | ✅ All 9 business rules are addressed; 3 require application-layer enforcement (correctly identified) |
| Appropriate keys, relationships, and constraints | ✅ PKs, FKs, UKs, CHECK constraints, DEFAULT values, and referential actions are correctly specified |
| Normalization | ✅ All tables are in 3NF |
| DBMS compatibility | ✅ Design uses MS SQL Server–compatible types (DATETIME2, VARCHAR, INT, TEXT) |

**Overall: The logical design is valid and ready to proceed to implementation (DDL).**
