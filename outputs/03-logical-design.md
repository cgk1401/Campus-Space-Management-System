# 03 — Logical Database Design

## 1. Relational Schema

### 1.1. `[User]`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| UserID | INT | PK, NOT NULL | Identity column |
| FullName | VARCHAR(100) | NOT NULL | |
| Email | VARCHAR(100) | NOT NULL, UNIQUE | |
| PhoneNumber | VARCHAR(20) | NULL | |
| Role | VARCHAR(30) | NOT NULL, CHECK( Role IN ('Student','Lecturer','TeachingAssistant','FacilityStaff','DepartmentAdministrator','FacilityManager') ) | |
| Department | VARCHAR(100) | NULL | |
| AccountStatus | VARCHAR(20) | NOT NULL, DEFAULT 'Active', CHECK( AccountStatus IN ('Active','Inactive','Suspended') ) | |

**Candidate Keys:** UserID (PK), Email (UK)

---

### 1.2. `[Space]`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| SpaceCode | VARCHAR(20) | PK, NOT NULL | |
| SpaceName | VARCHAR(100) | NOT NULL | |
| SpaceType | VARCHAR(30) | NOT NULL, CHECK( SpaceType IN ('Auditorium','Classroom','ComputerLab','ProjectLab','MeetingRoom','StudentWorkspace') ) | |
| Building | VARCHAR(50) | NOT NULL | |
| Floor | INT | NOT NULL | |
| RoomNumber | VARCHAR(20) | NOT NULL | |
| Capacity | INT | NOT NULL, CHECK( Capacity > 0 ) | |
| CurrentStatus | VARCHAR(20) | NOT NULL, DEFAULT 'Available', CHECK( CurrentStatus IN ('Available','InUse','UnderMaintenance','TemporarilyClosed','Retired') ) | |
| UsagePolicy | TEXT | NULL | |

**Candidate Keys:** SpaceCode (PK)

---

### 1.3. `[Facility]`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| FacilityID | INT | PK, NOT NULL | Identity column |
| FacilityName | VARCHAR(50) | NOT NULL, CHECK( FacilityName IN ('Projector','Whiteboard','Microphone','Computer','LivestreamingEquipment','AirConditioner') ) | |
| SpaceCode | VARCHAR(20) | NOT NULL, FK → Space(SpaceCode) ON DELETE CASCADE | |

**Candidate Keys:** FacilityID (PK)

---

### 1.4. `[BookingRequest]`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| BookingID | INT | PK, NOT NULL | Identity column |
| RequesterID | INT | NOT NULL, FK → User(UserID) ON DELETE NO ACTION | |
| SpaceCode | VARCHAR(20) | NOT NULL, FK → Space(SpaceCode) ON DELETE NO ACTION | |
| RequestedStartTime | DATETIME2 | NOT NULL | |
| RequestedEndTime | DATETIME2 | NOT NULL, CHECK( RequestedEndTime > RequestedStartTime ) | |
| PurposeOfUse | VARCHAR(30) | NOT NULL, CHECK( PurposeOfUse IN ('Lecture','Examination','Seminar','Workshop','Meeting','StudentActivity','AdministrativeEvent') ) | |
| ExpectedParticipants | INT | NOT NULL, CHECK( ExpectedParticipants > 0 ) | |
| Status | VARCHAR(20) | NOT NULL, DEFAULT 'Pending', CHECK( Status IN ('Pending','Approved','Rejected','Cancelled','CheckedIn','Completed','NoShow') ) | |

**Candidate Keys:** BookingID (PK)

**Additional Constraint (application-level):**
- `CHECK` cannot express overlapping-interval validation in standard SQL directly; an indexed `AFTER INSERT/UPDATE` trigger or application logic must enforce that no two approved bookings overlap on the same SpaceCode.

---

### 1.5. `[Approval]`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| ApprovalID | INT | PK, NOT NULL | Identity column |
| BookingID | INT | NOT NULL, UNIQUE, FK → BookingRequest(BookingID) ON DELETE CASCADE | 1:1 with BookingRequest |
| ApproverID | INT | NOT NULL, FK → User(UserID) ON DELETE NO ACTION | |
| DecisionTime | DATETIME2 | NOT NULL | |
| DecisionNote | TEXT | NULL | |
| RejectionReason | TEXT | NULL | Populated only when BookingRequest.Status = 'Rejected' (application-enforced) |

**Candidate Keys:** ApprovalID (PK), BookingID (UK)

---

### 1.6. `[UsageSession]`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| BookingID | INT | PK, FK → BookingRequest(BookingID) ON DELETE CASCADE | 1:1 with BookingRequest |
| ActualStartTime | DATETIME2 | NOT NULL | |
| CheckInStaffID | INT | NOT NULL, FK → User(UserID) ON DELETE NO ACTION | |
| InitialCondition | TEXT | NULL | |
| ActualEndTime | DATETIME2 | NULL | NULL until check-out completed |
| FinalCondition | TEXT | NULL | |
| UsageNotes | TEXT | NULL | |

**Candidate Keys:** BookingID (PK)

---

### 1.7. `[MaintenanceRecord]`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| MaintenanceID | INT | PK, NOT NULL | Identity column |
| SpaceCode | VARCHAR(20) | NOT NULL, FK → Space(SpaceCode) ON DELETE CASCADE | |
| ReporterID | INT | NOT NULL, FK → User(UserID) ON DELETE NO ACTION | |
| AssignedStaffID | INT | NULL, FK → User(UserID) ON DELETE SET NULL | May be unassigned initially |
| ProblemDescription | TEXT | NOT NULL | |
| StartTime | DATETIME2 | NOT NULL | |
| CompletionTime | DATETIME2 | NULL | NULL until resolved |
| Status | VARCHAR(20) | NOT NULL, DEFAULT 'Reported', CHECK( Status IN ('Reported','InProgress','Completed','Cancelled') ) | |
| ResultNote | TEXT | NULL | |

**Candidate Keys:** MaintenanceID (PK)

---

## 2. Summary of Keys

| Table | Primary Key | Foreign Keys | Unique / Candidate Keys |
|-------|-------------|--------------|------------------------|
| User | UserID | — | Email |
| Space | SpaceCode | — | — |
| Facility | FacilityID | SpaceCode → Space | — |
| BookingRequest | BookingID | RequesterID → User, SpaceCode → Space | — |
| Approval | ApprovalID | BookingID → BookingRequest, ApproverID → User | BookingID |
| UsageSession | BookingID | BookingID → BookingRequest, CheckInStaffID → User | — |
| MaintenanceRecord | MaintenanceID | SpaceCode → Space, ReporterID → User, AssignedStaffID → User | — |

---

## 3. Referential Integrity Actions

| FK | Parent | Child | ON DELETE | ON UPDATE |
|----|--------|-------|-----------|-----------|
| Facility.SpaceCode → Space.SpaceCode | Space | Facility | CASCADE | CASCADE |
| BookingRequest.RequesterID → User.UserID | User | BookingRequest | NO ACTION | CASCADE |
| BookingRequest.SpaceCode → Space.SpaceCode | Space | BookingRequest | NO ACTION | CASCADE |
| Approval.BookingID → BookingRequest.BookingID | BookingRequest | Approval | CASCADE | CASCADE |
| Approval.ApproverID → User.UserID | User | Approval | NO ACTION | CASCADE |
| UsageSession.BookingID → BookingRequest.BookingID | BookingRequest | UsageSession | CASCADE | CASCADE |
| UsageSession.CheckInStaffID → User.UserID | User | UsageSession | NO ACTION | CASCADE |
| MaintenanceRecord.SpaceCode → Space.SpaceCode | Space | MaintenanceRecord | CASCADE | CASCADE |
| MaintenanceRecord.ReporterID → User.UserID | User | MaintenanceRecord | NO ACTION | CASCADE |
| MaintenanceRecord.AssignedStaffID → User.UserID | User | MaintenanceRecord | SET NULL | CASCADE |

**Rationale:**
- **CASCADE** on child tables that are clearly dependent (Facility belongs to Space; Approval belongs to BookingRequest; UsageSession belongs to BookingRequest; MaintenanceRecord belongs to Space).
- **NO ACTION** on tables where the parent User record should not be deleted if it has dependent rows (e.g., past BookingRequests, Approvals).
- **SET NULL** on AssignedStaffID because a maintenance record can persist even if the assigned staff member leaves.

---

## 4. CHECK Constraints Summary

| Table | Constraint | Expression |
|-------|------------|-----------|
| User | CK_User_Role | Role IN ('Student','Lecturer','TeachingAssistant','FacilityStaff','DepartmentAdministrator','FacilityManager') |
| User | CK_User_AccountStatus | AccountStatus IN ('Active','Inactive','Suspended') |
| Space | CK_Space_SpaceType | SpaceType IN ('Auditorium','Classroom','ComputerLab','ProjectLab','MeetingRoom','StudentWorkspace') |
| Space | CK_Space_CurrentStatus | CurrentStatus IN ('Available','InUse','UnderMaintenance','TemporarilyClosed','Retired') |
| Space | CK_Space_Capacity | Capacity > 0 |
| Facility | CK_Facility_FacilityName | FacilityName IN ('Projector','Whiteboard','Microphone','Computer','LivestreamingEquipment','AirConditioner') |
| BookingRequest | CK_Booking_TimeRange | RequestedEndTime > RequestedStartTime |
| BookingRequest | CK_Booking_PurposeOfUse | PurposeOfUse IN ('Lecture','Examination','Seminar','Workshop','Meeting','StudentActivity','AdministrativeEvent') |
| BookingRequest | CK_Booking_ExpectedParticipants | ExpectedParticipants > 0 |
| BookingRequest | CK_Booking_Status | Status IN ('Pending','Approved','Rejected','Cancelled','CheckedIn','Completed','NoShow') |
| MaintenanceRecord | CK_Maintenance_Status | Status IN ('Reported','InProgress','Completed','Cancelled') |

---

## 5. DEFAULT Values

| Table | Column | Default |
|-------|--------|---------|
| User | AccountStatus | 'Active' |
| Space | CurrentStatus | 'Available' |
| BookingRequest | Status | 'Pending' |
| MaintenanceRecord | Status | 'Reported' |

---

## 6. Business Rule Enforcement Mapping

| Rule | Enforcement Mechanism |
|------|----------------------|
| BR1 — Unique Booking ID | PK on BookingRequest.BookingID |
| BR2 — No overlapping bookings | Application-level / trigger (cannot be expressed via declarative CHECK) |
| BR3 — Unavailable space cannot be booked | Application checks Space.CurrentStatus & active MaintenanceRecord before INSERT/UPDATE |
| BR4 — Approval tracking | Approval table with FK to User for approver, decision time, notes, rejection reason |
| BR5 — Check-in/Check-out recording | UsageSession table with actual start/end times, conditions, notes |
| BR6 — Maintenance blocks booking | Application checks for active (Reported/InProgress) MaintenanceRecord on the Space |
| BR7 — Historical records | All tables use status fields; no deletes of historical data |
| BR8 — University account required | User table is the anchor; RequesterID, ApproverID, CheckInStaffID all FK to User |
| BR9 — Status lifecycle | CHECK constraint on BookingRequest.Status limits valid values |

---

## 7. Denormalization Notes

- **Facility** is modeled as a separate child table of Space (normalized) rather than a comma-separated list attribute, to support querying and maintenance of individual facilities.
- **UsageSession** is kept as a separate table (not merged into BookingRequest) because it is populated at different times (check-in and check-out) and has a 1:1 optional participation from the Booking side.
- No denormalization is applied; all tables satisfy at least 3NF.
