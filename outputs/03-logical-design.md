# 03 — Logical Design (Relational Schema)

---

## 1. Table: `User`

| Column | Type | Constraints |
|--------|------|-------------|
| UserID | `INT` | **PK**, IDENTITY(1,1) |
| FullName | `NVARCHAR(100)` | **NOT NULL** |
| Email | `NVARCHAR(255)` | **NOT NULL**, **UNIQUE** |
| PhoneNumber | `NVARCHAR(20)` | **NOT NULL** |
| Role | `NVARCHAR(30)` | **NOT NULL**, CHECK (Role IN ('Student','Lecturer','TeachingAssistant','FacilityStaff','DepartmentAdministrator','FacilityManager')) |
| Department | `NVARCHAR(100)` | **NOT NULL** |
| AccountStatus | `NVARCHAR(20)` | **NOT NULL**, DEFAULT **'Active'**, CHECK (AccountStatus IN ('Active','Disabled')) |

**Candidate keys:** `UserID` (PK), `Email` (UNIQUE)

---

## 2. Table: `Space`

| Column | Type | Constraints |
|--------|------|-------------|
| SpaceCode | `NVARCHAR(20)` | **PK** |
| SpaceName | `NVARCHAR(100)` | **NOT NULL** |
| SpaceType | `NVARCHAR(30)` | **NOT NULL**, CHECK (SpaceType IN ('Auditorium','Classroom','ComputerLaboratory','ProjectLaboratory','MeetingRoom','StudentWorkspace')) |
| Building | `NVARCHAR(100)` | **NOT NULL** |
| Floor | `INT` | **NOT NULL** |
| RoomNumber | `NVARCHAR(20)` | **NOT NULL** |
| Capacity | `INT` | **NOT NULL**, CHECK (Capacity > 0) |
| CurrentStatus | `NVARCHAR(20)` | **NOT NULL**, DEFAULT **'Available'**, CHECK (CurrentStatus IN ('Available','InUse','UnderMaintenance','TemporarilyClosed','Retired')) |
| UsagePolicy | `NVARCHAR(MAX)` | NULL allowed |

**Candidate keys:** `SpaceCode` (PK), UNIQUE(`Building`, `Floor`, `RoomNumber`)

---

## 3. Table: `FacilityType`

| Column | Type | Constraints |
|--------|------|-------------|
| FacilityName | `NVARCHAR(50)` | **PK** |

---

## 4. Table: `SpaceFacility`

| Column | Type | Constraints |
|--------|------|-------------|
| SpaceCode | `NVARCHAR(20)` | **PK, FK** → Space(SpaceCode) |
| FacilityName | `NVARCHAR(50)` | **PK, FK** → FacilityType(FacilityName) |

**Candidate keys:** (`SpaceCode`, `FacilityName`) — composite PK

---

## 5. Table: `BookingRequest`

| Column | Type | Constraints |
|--------|------|-------------|
| BookingID | `INT` | **PK**, IDENTITY(1,1) |
| RequesterID | `INT` | **NOT NULL**, **FK** → User(UserID) |
| SpaceCode | `NVARCHAR(20)` | **NOT NULL**, **FK** → Space(SpaceCode) |
| StartTime | `DATETIME2` | **NOT NULL** |
| EndTime | `DATETIME2` | **NOT NULL**, CHECK (EndTime > StartTime) |
| Purpose | `NVARCHAR(30)` | **NOT NULL**, CHECK (Purpose IN ('Lecture','Examination','Seminar','Workshop','Meeting','StudentActivity','AdministrativeEvent')) |
| ExpectedParticipants | `INT` | **NOT NULL**, CHECK (ExpectedParticipants > 0) |
| Status | `NVARCHAR(20)` | **NOT NULL**, DEFAULT **'Pending'**, CHECK (Status IN ('Pending','Approved','Rejected','Cancelled','CheckedIn','Completed','NoShow')) |

**Candidate keys:** `BookingID` (PK)

---

## 6. Table: `Approval`

| Column | Type | Constraints |
|--------|------|-------------|
| BookingID | `INT` | **PK, FK** → BookingRequest(BookingID) |
| ApproverID | `INT` | **NOT NULL**, **FK** → User(UserID) |
| DecisionTime | `DATETIME2` | **NOT NULL** |
| DecisionNote | `NVARCHAR(MAX)` | NULL allowed |
| RejectionReason | `NVARCHAR(MAX)` | NULL allowed |

**Candidate keys:** `BookingID` (PK)

---

## 7. Table: `UsageSession`

| Column | Type | Constraints |
|--------|------|-------------|
| BookingID | `INT` | **PK, FK** → BookingRequest(BookingID) |
| ActualStartTime | `DATETIME2` | **NOT NULL** |
| CheckInStaffID | `INT` | **NOT NULL**, **FK** → User(UserID) |
| InitialCondition | `NVARCHAR(MAX)` | NULL allowed |
| ActualEndTime | `DATETIME2` | NULL allowed (set at check-out) |
| FinalCondition | `NVARCHAR(MAX)` | NULL allowed |
| UsageNotes | `NVARCHAR(MAX)` | NULL allowed |

**Candidate keys:** `BookingID` (PK)

---

## 8. Table: `MaintenanceRecord`

| Column | Type | Constraints |
|--------|------|-------------|
| MaintenanceID | `INT` | **PK**, IDENTITY(1,1) |
| SpaceCode | `NVARCHAR(20)` | **NOT NULL**, **FK** → Space(SpaceCode) |
| ReporterID | `INT` | **NOT NULL**, **FK** → User(UserID) |
| AssignedStaffID | `INT` | NULL allowed, **FK** → User(UserID) |
| ProblemDescription | `NVARCHAR(MAX)` | **NOT NULL** |
| StartTime | `DATETIME2` | **NOT NULL** |
| CompletionTime | `DATETIME2` | NULL allowed |
| Status | `NVARCHAR(20)` | **NOT NULL**, DEFAULT **'Open'**, CHECK (Status IN ('Open','InProgress','Resolved','Closed')) |
| ResultNote | `NVARCHAR(MAX)` | NULL allowed |

**Candidate keys:** `MaintenanceID` (PK)

---

## 9. Foreign Key Summary

| FK Column(s) | Parent Table | ON DELETE | Justification |
|-------------|-------------|-----------|---------------|
| BookingRequest.RequesterID | User | **NO ACTION** | Historical preservation (BR10). Disabling a user (soft-delete via AccountStatus) should not destroy their booking history. |
| BookingRequest.SpaceCode | Space | **NO ACTION** | Historical preservation. Spaces are soft-deleted via CurrentStatus = 'Retired'. Past bookings for retired spaces must remain. |
| Approval.BookingID | BookingRequest | **CASCADE** | Approval has no independent meaning without its parent booking. If a booking is removed, its approval record is meaningless. |
| Approval.ApproverID | User | **NO ACTION** | Historical preservation. The approver's identity must be preserved even if the user is later disabled. |
| UsageSession.BookingID | BookingRequest | **CASCADE** | UsageSession has no independent meaning without its parent booking. |
| UsageSession.CheckInStaffID | User | **NO ACTION** | Historical preservation. The check-in staff identity must be preserved. |
| SpaceFacility.SpaceCode | Space | **CASCADE** | A space's facility list is a current configuration detail. If a space is retired/removed, its facility assignments are no longer relevant. |
| SpaceFacility.FacilityName | FacilityType | **NO ACTION** | Deleting a facility type should not be allowed while any space references it (referential integrity). |
| MaintenanceRecord.SpaceCode | Space | **NO ACTION** | Historical preservation. Maintenance records for a space must persist even if the space is retired. |
| MaintenanceRecord.ReporterID | User | **NO ACTION** | Historical preservation. |
| MaintenanceRecord.AssignedStaffID | User | **SET NULL** | Optional FK. If a staff member leaves, the maintenance record can remain without an assignee. |

---

## 10. DDL-Enforceable Constraints vs. Application-Level Rules

### DDL-Enforceable (CHECK, UNIQUE, NOT NULL)

| Constraint | Location | SQL Enforcement |
|-----------|----------|---------------|
| Capacity > 0 | Space | CHECK (Capacity > 0) |
| EndTime > StartTime | BookingRequest | CHECK (EndTime > StartTime) |
| ExpectedParticipants > 0 | BookingRequest | CHECK (ExpectedParticipants > 0) |
| Role must be a valid value | User | CHECK (Role IN (...)) |
| AccountStatus must be valid | User | CHECK (AccountStatus IN (...)) |
| SpaceType must be valid | Space | CHECK (SpaceType IN (...)) |
| CurrentStatus must be valid | Space | CHECK (CurrentStatus IN (...)) |
| Purpose must be valid | BookingRequest | CHECK (Purpose IN (...)) |
| Booking Status must be valid | BookingRequest | CHECK (Status IN (...)) |
| Maintenance Status must be valid | MaintenanceRecord | CHECK (Status IN (...)) |
| Email uniqueness | User | UNIQUE (Email) |
| Room uniqueness | Space | UNIQUE (Building, Floor, RoomNumber) |

### Application-Level Rules

| Rule | Description |
|------|-------------|
| No overlapping bookings | The system must prevent two Approved/CheckedIn bookings for the same space with overlapping time intervals. Requires checking (StartTime, EndTime) ranges programmatically. |
| Blocked spaces cannot be booked | If Space.CurrentStatus is 'UnderMaintenance', 'TemporarilyClosed', or 'Retired', the system must reject new booking requests for that space. |
| Active maintenance blocks bookings | If a space has any MaintenanceRecord with Status != 'Resolved' or 'Closed', the system should warn or block booking. |
| Rejection reason is required when rejected | Application logic: if Approval.Status implies rejection (based on BookingRequest.Status), the RejectionReason should be non-null. |
| Role-based access control | Only FacilityStaff/FacilityManager may be set as ApproverID or CheckInStaffID. Only FacilityStaff/FacilityManager may be set as AssignedStaffID. This is enforced by application logic, not FK constraints. |
| Status transitions | BookingRequest.Status follows a lifecycle: Pending → Approved/Rejected/Cancelled → CheckedIn → Completed/NoShow. Invalid transitions must be rejected by the application. |
| Preserve history | DELETE operations on User or Space should be disallowed or replaced with status changes to 'Disabled'/'Retired'. |
