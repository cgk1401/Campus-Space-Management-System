# 03 — Logical Database Design (Relational Schema)

Converted from the conceptual ERD in `outputs/02-erd-design.md` (Step 2). The ERD has no M:N relationships, so the mapping is direct: each entity becomes a relation; each named relationship becomes a FK column (plain 1:N) or a dedicated 1:1 table that carries relationship attributes.

Target DBMS: **Microsoft SQL Server** (per AGENTS.md).

---

## 1. Relation Mapping (ERD → Schema)

| ERD Entity / Relationship | Relational Mapping |
|---------------------------|--------------------|
| User | Relation `User` |
| Space | Relation `Space` |
| Facility | Relation `Facility` (FK to Space for "houses") |
| BookingRequest | Relation `BookingRequest` (FKs for "submits", "targets") |
| Approval | Relation `Approval` (1:1 with BookingRequest; carries decision attributes) |
| UsageSession | Relation `UsageSession` (1:1 with BookingRequest; carries check-in/out attributes; FK to Approval) |
| MaintenanceRecord | Relation `MaintenanceRecord` (FKs for reports, assigned-to, affects, concerns) |

---

## 2. Relations

### 2.1. User
| Attribute | Domain | Nullable | Constraints |
|-----------|--------|----------|-------------|
| UserID | INT | NO | **PK** |
| FullName | NVARCHAR(100) | NO | |
| Email | NVARCHAR(255) | NO | **Candidate key (UNIQUE)** |
| PhoneNumber | NVARCHAR(20) | YES | |
| Role | NVARCHAR(30) | NO | **CHECK** — Student, Lecturer, TeachingAssistant, FacilityStaff, DepartmentAdministrator, FacilityManager |
| Department | NVARCHAR(100) | YES | |
| AccountStatus | NVARCHAR(20) | NO | **DEFAULT** 'Active'; **CHECK** — Active, Disabled |

**Candidate keys:** `Email` (UNIQUE).
**Notes:** Users are never hard-deleted (history preservation, BR10) — disable via `AccountStatus` instead.

### 2.2. Space
| Attribute | Domain | Nullable | Constraints |
|-----------|--------|----------|-------------|
| SpaceCode | NVARCHAR(20) | NO | **PK** |
| SpaceName | NVARCHAR(100) | NO | |
| SpaceType | NVARCHAR(30) | NO | **CHECK** — Auditorium, Classroom, ComputerLaboratory, ProjectLaboratory, MeetingRoom, StudentWorkspace |
| Building | NVARCHAR(100) | NO | |
| Floor | INT | NO | |
| RoomNumber | NVARCHAR(20) | NO | |
| Capacity | INT | NO | **CHECK** — Capacity > 0 |
| CurrentStatus | NVARCHAR(20) | NO | **DEFAULT** 'Available'; **CHECK** — Available, InUse, UnderMaintenance, TemporarilyClosed, Retired |
| UsagePolicy | NVARCHAR(MAX) | YES | |

**Candidate keys:** `(Building, Floor, RoomNumber)` (suggested, Assumption A9). `SpaceCode` is the declared PK (requirement states it is unique).

### 2.3. Facility
| Attribute | Domain | Nullable | Constraints |
|-----------|--------|----------|-------------|
| FacilityID | INT | NO | **PK** (surrogate for the individual physical unit) |
| FacilityName | NVARCHAR(50) | NO | **CHECK** — Projector, Whiteboard, Microphone, Computer, LivestreamingEquipment, AirConditioner |
| SpaceCode | NVARCHAR(20) | NO | **FK → Space(SpaceCode)**, ON DELETE NO ACTION |

**Candidate keys:** none (two units of the same type can exist in one space; `(SpaceCode, FacilityName)` is not unique).

### 2.4. BookingRequest
| Attribute | Domain | Nullable | Constraints |
|-----------|--------|----------|-------------|
| BookingID | INT | NO | **PK** |
| RequesterID | INT | NO | **FK → User(UserID)**, ON DELETE NO ACTION |
| SpaceCode | NVARCHAR(20) | NO | **FK → Space(SpaceCode)**, ON DELETE NO ACTION |
| StartTime | DATETIME2 | NO | |
| EndTime | DATETIME2 | NO | **CHECK** — EndTime > StartTime |
| Purpose | NVARCHAR(30) | NO | **CHECK** — Lecture, Examination, Seminar, Workshop, Meeting, StudentActivity, AdministrativeEvent |
| ExpectedParticipants | INT | NO | **CHECK** — ExpectedParticipants > 0 |
| Status | NVARCHAR(20) | NO | **DEFAULT** 'Pending'; **CHECK** — Pending, Approved, Rejected, Cancelled, CheckedIn, Completed, NoShow |

**Candidate keys:** none beyond `BookingID`.

### 2.5. Approval
| Attribute | Domain | Nullable | Constraints |
|-----------|--------|----------|-------------|
| BookingID | INT | NO | **PK**, **FK → BookingRequest(BookingID)**, ON DELETE NO ACTION (1:1 — parent PK reused as child PK) |
| ApproverID | INT | NO | **FK → User(UserID)**, ON DELETE NO ACTION |
| DecisionTime | DATETIME2 | NO | |
| DecisionNote | NVARCHAR(MAX) | NO | |
| RejectionReason | NVARCHAR(MAX) | YES | Required when the booking was rejected — enforced at application level (see BR5) |

**Candidate keys:** `BookingID` (PK).

### 2.6. UsageSession
| Attribute | Domain | Nullable | Constraints |
|-----------|--------|----------|-------------|
| BookingID | INT | NO | **PK**, **FK → BookingRequest(BookingID)**, ON DELETE NO ACTION (1:1) |
| ApprovalID | INT | NO | **FK → Approval(BookingID)**, ON DELETE NO ACTION (BR8: session only after valid approval) |
| ActualStartTime | DATETIME2 | NO | |
| CheckInStaffID | INT | NO | **FK → User(UserID)**, ON DELETE NO ACTION |
| InitialCondition | NVARCHAR(MAX) | NO | |
| ActualEndTime | DATETIME2 | YES | **CHECK** — ActualEndTime > ActualStartTime (when not NULL) |
| FinalCondition | NVARCHAR(MAX) | YES | |
| UsageNotes | NVARCHAR(MAX) | YES | |

**Candidate keys:** `BookingID` (PK).

### 2.7. MaintenanceRecord
| Attribute | Domain | Nullable | Constraints |
|-----------|--------|----------|-------------|
| MaintenanceID | INT | NO | **PK** |
| SpaceCode | NVARCHAR(20) | NO | **FK → Space(SpaceCode)**, ON DELETE NO ACTION |
| FacilityID | INT | YES | **FK → Facility(FacilityID)**, ON DELETE NO ACTION (Assumption A5 / Q1) |
| ReporterID | INT | NO | **FK → User(UserID)**, ON DELETE NO ACTION |
| AssignedStaffID | INT | YES | **FK → User(UserID)**, ON DELETE NO ACTION |
| ProblemDescription | NVARCHAR(MAX) | NO | |
| StartTime | DATETIME2 | NO | |
| CompletionTime | DATETIME2 | YES | **CHECK** — CompletionTime > StartTime (when not NULL) |
| Status | NVARCHAR(20) | NO | **DEFAULT** 'Open'; **CHECK** — Open, InProgress, Resolved, Closed |
| ResultNote | NVARCHAR(MAX) | YES | |

**Candidate keys:** `MaintenanceID` (PK).

---

## 3. Foreign Key ON DELETE Actions

| FK | Action | Justification |
|----|--------|---------------|
| BookingRequest.RequesterID → User | **NO ACTION** | Booking history must be preserved (BR10); users are disabled, not deleted. Deleting a user must not cascade-delete bookings. |
| BookingRequest.SpaceCode → Space | **NO ACTION** | Booking history must be preserved; spaces are retired via `CurrentStatus`, not hard-deleted. |
| Facility.SpaceCode → Space | **NO ACTION** | Maintenance records reference facilities; removing a space must not silently delete its facility units. |
| Approval.BookingID → BookingRequest | **NO ACTION** | A booking and its approval decision are historical records; they must be preserved together, but removing one must never cascade the other unexpectedly. |
| Approval.ApproverID → User | **NO ACTION** | Approval history must be preserved even if a user's account is disabled. |
| UsageSession.BookingID → BookingRequest | **NO ACTION** | Session history must be preserved (BR10). |
| UsageSession.ApprovalID → Approval | **NO ACTION** | A session proves a validated booking; the approval record must remain for auditability. |
| UsageSession.CheckInStaffID → User | **NO ACTION** | Session history must be preserved. |
| MaintenanceRecord.SpaceCode → Space | **NO ACTION** | Maintenance history must be preserved. |
| MaintenanceRecord.FacilityID → Facility | **NO ACTION** | Per-unit maintenance history must be preserved. |
| MaintenanceRecord.ReporterID → User | **NO ACTION** | Historical reporting records must be preserved. |
| MaintenanceRecord.AssignedStaffID → User | **NO ACTION** | Historical assignment records must be preserved. |

**Overall policy:** no hard-deletes anywhere in the schema — parents are soft-deactivated (space status, account status), so every FK uses NO ACTION to protect historical integrity (BR10).

---

## 4. Candidate Keys Summary

| Relation | Candidate Key(s) | Role |
|----------|------------------|------|
| User | Email | UNIQUE |
| Space | SpaceCode (declared PK); (Building, Floor, RoomNumber) — suggested, Assumption A9 | UNIQUE |
| Facility | FacilityID | PK |
| BookingRequest | BookingID | PK |
| Approval | BookingID | PK |
| UsageSession | BookingID | PK |
| MaintenanceRecord | MaintenanceID | PK |

---

## 5. Domain & CHECK Constraints Summary

| Constraint | Applies to | Valid values / condition |
|------------|-----------|--------------------------|
| User.Role | User | Student, Lecturer, TeachingAssistant, FacilityStaff, DepartmentAdministrator, FacilityManager |
| User.AccountStatus | User | Active, Disabled |
| Space.SpaceType | Space | Auditorium, Classroom, ComputerLaboratory, ProjectLaboratory, MeetingRoom, StudentWorkspace |
| Space.CurrentStatus | Space | Available, InUse, UnderMaintenance, TemporarilyClosed, Retired |
| Space.Capacity > 0 | Space | Capacity ≥ 1 |
| Facility.FacilityName | Facility | Projector, Whiteboard, Microphone, Computer, LivestreamingEquipment, AirConditioner |
| BookingRequest.Purpose | BookingRequest | Lecture, Examination, Seminar, Workshop, Meeting, StudentActivity, AdministrativeEvent |
| BookingRequest.Status | BookingRequest | Pending, Approved, Rejected, Cancelled, CheckedIn, Completed, NoShow |
| BookingRequest.EndTime > StartTime | BookingRequest | EndTime after StartTime |
| BookingRequest.ExpectedParticipants > 0 | BookingRequest | ≥ 1 |
| UsageSession.ActualEndTime > ActualStartTime | UsageSession | enforced when ActualEndTime is not NULL |
| MaintenanceRecord.CompletionTime > StartTime | MaintenanceRecord | enforced when CompletionTime is not NULL |
| MaintenanceRecord.Status | MaintenanceRecord | Open, InProgress, Resolved, Closed |

**DEFAULT values:** User.AccountStatus = 'Active'; Space.CurrentStatus = 'Available'; BookingRequest.Status = 'Pending'; MaintenanceRecord.Status = 'Open'.

---

## 6. Business Rule Enforcement (DDL vs Application Logic)

| # | Rule | Enforceable via DDL? | Enforcement |
|---|------|----------------------|-------------|
| BR1 | Users must have a university account to book | Partial | FK `BookingRequest.RequesterID` (reference integrity); role of requester checked at application level |
| BR2 | No overlapping approved bookings for the same space | **No** | Application-level query over (SpaceCode, StartTime, EndTime, Status) at booking/approval time |
| BR3 | Under-maintenance / closed / retired spaces cannot be booked | **No** | Application-level check of `Space.CurrentStatus` before booking |
| BR4 | Space with active unresolved maintenance cannot be booked | **No** | Application-level check against active `MaintenanceRecord` rows |
| BR5 | Approval must record approver, decision time, note; rejection reason required on rejection | Partial | NOT NULL on ApproverID/DecisionTime/DecisionNote (DDL); "reason required only if rejected" is application-level (depends on booking Status) |
| BR6 | Check-in records actual start time, staff, initial condition | Yes | NOT NULL on ActualStartTime, CheckInStaffID, InitialCondition |
| BR7 | Check-out records actual end time, final condition, usage notes | Partial | Columns exist; mandatory on completion enforced at application level |
| BR8 | UsageSession only after valid Approval | Yes | NOT NULL FK `UsageSession.ApprovalID` |
| BR9 | Facilities are individual units in exactly one space | Yes | Surrogate PK `FacilityID` + NOT NULL FK `Facility.SpaceCode` |
| BR10 | Preserve historical records, no hard deletes | Policy | All FKs NO ACTION; status flags instead of deletion |
| BR11 | Purpose of use domain | Yes | CHECK on Purpose |
| BR12 | Capacity > 0 | Yes | CHECK |
| BR13 | EndTime > StartTime | Yes | CHECK |
| BR14 | Booking status domain | Yes | CHECK on Status |
| BR15 | Space status domain | Yes | CHECK on CurrentStatus |
| BR16 | Only FacilityStaff/Manager approve, check in, or are assigned maintenance | **No** | Application-level role-based access (see ERD Section 4) |
| BR17 | Overlap/status prevention enforced in application logic | **No** | Application-level (BR2/BR3/BR4) |

**Application-level rules are NOT SQL constraints:** BR2, BR3, BR4, BR16, the "rejection reason required" part of BR5, and the "mandatory fields on completion" part of BR7. Everything else is enforceable directly in DDL.

---

## 7. Assumptions & Open Questions Carried Forward

| # | Item | Status |
|---|------|--------|
| A5 / Q1 | `MaintenanceRecord.FacilityID` optional per-unit reference | Open — confirm with stakeholder |
| A9 | `(Building, Floor, RoomNumber)` is unique per Space (candidate key) | New assumption — confirm; otherwise SpaceCode alone guarantees uniqueness |
| A2 | `InUse` space status maintained manually or derived from sessions | Open (Q7) |
| Q2–Q6, Q8, Q9 | Role-based space access, lead times, edit-after-submit, recurring bookings, duration limits, facility movability, rejected-booking records | Open — do not affect schema shape currently |
