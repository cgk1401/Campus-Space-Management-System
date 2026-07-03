# 01 — Business Requirement Analysis

## 1. Business Purpose

The School of Computer Science wants to build a database system to manage the booking and usage of shared campus spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces). The current manual process (spreadsheets, shared calendars, phone/email) is no longer sustainable as the volume of teaching, seminars, workshops, student projects, and academic events grows.

The system's main goals are:
- Manage shared campus spaces fairly and transparently.
- Avoid overlapping / conflicting bookings.
- Prevent the use of unavailable spaces (under maintenance, closed, or retired).
- Preserve usage, booking, and maintenance history.
- Enable facility staff to efficiently handle check-in/check-out, approvals, and maintenance tracking.

---

## 2. Actors (User Roles)

| Role | Description |
|------|-------------|
| **Student** | Submits booking requests for student activities. |
| **Lecturer** | Submits booking requests for lectures, exams, seminars. |
| **Teaching Assistant** | Submits booking requests on behalf of lecturers. |
| **Facility Staff** | Handles check-in/check-out, performs approvals, views reports. |
| **Department Administrator** | Oversees bookings for the department, views reports. |
| **Facility Manager** | Full access: approvals, maintenance, reports, system oversight. |

---

## 3. Entities & Attributes

### 3.1. User
| Attribute | Type | Notes |
|-----------|------|-------|
| UserID | PK | University account identifier |
| FullName | VARCHAR | |
| Email | VARCHAR | |
| PhoneNumber | VARCHAR | |
| Role | ENUM | Student, Lecturer, TeachingAssistant, FacilityStaff, DepartmentAdministrator, FacilityManager |
| Department | VARCHAR | |
| AccountStatus | VARCHAR | e.g., Active, Disabled |

### 3.2. Space
| Attribute | Type | Notes |
|-----------|------|-------|
| SpaceCode | PK | Unique identifier (e.g., "B1-101") |
| SpaceName | VARCHAR | |
| SpaceType | ENUM | Auditorium, Classroom, ComputerLaboratory, ProjectLaboratory, MeetingRoom, StudentWorkspace |
| Building | VARCHAR | |
| Floor | INT | |
| RoomNumber | VARCHAR | |
| Capacity | INT | Must be > 0 |
| CurrentStatus | ENUM | Available, InUse, UnderMaintenance, TemporarilyClosed, Retired |
| UsagePolicy | TEXT | |

### 3.3. FacilityType
| Attribute | Type | Notes |
|-----------|------|-------|
| FacilityName | PK | e.g., "Projector", "Whiteboard", "Microphone", "Computer", "LivestreamingEquipment", "AirConditioner" |

### 3.4. SpaceFacility (Assignment)
| Attribute | Type | Notes |
|-----------|------|-------|
| SpaceCode | PK, FK | References Space |
| FacilityName | PK, FK | References FacilityType |
- Composite PK: (SpaceCode, FacilityName).

### 3.5. BookingRequest
| Attribute | Type | Notes |
|-----------|------|-------|
| BookingID | PK | |
| RequesterID | FK | References User |
| SpaceCode | FK | References Space |
| StartTime | DATETIME | Requested start |
| EndTime | DATETIME | Requested end (must be > StartTime) |
| Purpose | ENUM | Lecture, Examination, Seminar, Workshop, Meeting, StudentActivity, AdministrativeEvent |
| ExpectedParticipants | INT | Must be > 0 |
| Status | ENUM | Pending, Approved, Rejected, Cancelled, CheckedIn, Completed, NoShow |

### 3.6. Approval
| Attribute | Type | Notes |
|-----------|------|-------|
| BookingID | PK, FK | References BookingRequest (1:1) |
| ApproverID | FK | References User (FacilityStaff or FacilityManager) |
| DecisionTime | DATETIME | |
| DecisionNote | TEXT | |
| RejectionReason | TEXT | NULL if approved |

### 3.7. UsageSession (Check-in / Check-out)
| Attribute | Type | Notes |
|-----------|------|-------|
| BookingID | PK, FK | References BookingRequest (1:1) |
| ActualStartTime | DATETIME | Recorded at check-in |
| CheckInStaffID | FK | References User |
| InitialCondition | TEXT | Space condition on arrival |
| ActualEndTime | DATETIME | Recorded at completion (nullable until session ends) |
| FinalCondition | TEXT | Space condition on departure |
| UsageNotes | TEXT | |

### 3.8. MaintenanceRecord
| Attribute | Type | Notes |
|-----------|------|-------|
| MaintenanceID | PK | |
| SpaceCode | FK | References Space |
| ReporterID | FK | References User (any role may report) |
| AssignedStaffID | FK | References User (FacilityStaff/FacilityManager) |
| ProblemDescription | TEXT | |
| StartTime | DATETIME | |
| CompletionTime | DATETIME | Nullable |
| Status | VARCHAR | e.g., Open, InProgress, Resolved, Closed |
| ResultNote | TEXT | |

---

## 4. Relationships & Cardinalities

| Relationship | Entity A | Entity B | Cardinality | Participation |
|-------------|----------|----------|-------------|---------------|
| Submits | User (Requester) | BookingRequest | 1:N | User: optional; BookingRequest: mandatory |
| Targets | BookingRequest | Space | N:1 | BookingRequest: mandatory; Space: optional |
| Decides | Approval | BookingRequest | 1:1 | Approval: mandatory; BookingRequest: optional |
| Approves | User (Approver) | Approval | 1:N | User: optional; Approval: mandatory |
| Records | BookingRequest | UsageSession | 1:1 | UsageSession: mandatory; BookingRequest: optional |
| ChecksIn | User (Staff) | UsageSession | 1:N | User: optional; UsageSession: mandatory |
| Contains | Space | FacilityType (via SpaceFacility) | M:N | Both: optional |
| Reports | User (Reporter) | MaintenanceRecord | 1:N | User: optional; MaintenanceRecord: mandatory |
| AssignedTo | User (Staff) | MaintenanceRecord | 1:N | User: optional; MaintenanceRecord: optional |
| Affects | MaintenanceRecord | Space | N:1 | MaintenanceRecord: mandatory; Space: optional |

**Notes on participation:**
- "Optional" on the User side means not every user must have a booking/maintenance/approval record.
- "Optional" on the Space side means a space may have zero bookings or zero maintenance records.
- BookingRequest → UsageSession: mandatory because every completed check-in creates a UsageSession record. However, if a booking is cancelled/rejected before check-in, it may not have a UsageSession — so the participation from BookingRequest side is optional.

---

## 5. Business Rules

| # | Rule | Source |
|---|------|--------|
| BR1 | Users must have a university account to submit bookings. | §1.2 |
| BR2 | A space CANNOT have two approved/checked-in bookings with overlapping time periods. | §1.4 (conflict prevention) |
| BR3 | Spaces with status `UnderMaintenance`, `TemporarilyClosed`, or `Retired` CANNOT be booked. | §1.4, §1.7 |
| BR4 | A space under an active (unresolved) maintenance record CANNOT be booked. | §1.7 |
| BR5 | Booking approvals/rejections must record the approver, decision time, and decision note. If rejected, a rejection reason is required. | §1.5 |
| BR6 | Check-in records the actual start time, staff member who performed check-in, and initial condition. | §1.6 |
| BR7 | Check-out (completion) records the actual end time, final condition, and usage notes. | §1.6 |
| BR8 | Facility types are modeled as a lookup/list, not as individual physical asset units. | §1.3 |
| BR9 | A space-facility assignment is uniquely identified by (SpaceCode, FacilityName). No surrogate FacilityID is needed. | §1.3 |
| BR10 | The system must preserve historical records (bookings and maintenance) — no hard-deletion of past records. | §1.8 |
| BR11 | The purpose of use is one of: Lecture, Examination, Seminar, Workshop, Meeting, StudentActivity, AdministrativeEvent. | §1.4 |
| BR12 | Space capacity must be a positive integer (Capacity > 0). | §1.3 (implied) |
| BR13 | Booking end time must be after start time (EndTime > StartTime). | §1.4 (implied) |

---

## 6. Assumptions

| # | Assumption |
|---|-----------|
| A1 | A booking request may optionally skip the approval step (direct approval) if it does not require it, but the Approval entity will still exist with a nullable reference or the status indicates no approval needed. For simplicity, we model Approval as a separate 1:1 table that is created when a decision is made. |
| A2 | The `InUse` space status is set when a check-in occurs and cleared when check-out completes. Alternatively, it may be derived from active booking sessions. We will treat it as a derived/status field. |
| A3 | Only users with role `FacilityStaff` or `FacilityManager` can act as approvers or check-in staff. |
| A4 | Maintenance records can be reported by any user role, but only `FacilityStaff` or `FacilityManager` can be assigned as the responsible person. |
| A5 | The system prevents overlapping bookings via application logic (since DDL alone cannot enforce time-interval overlap constraints). |
| A6 | The `AccountStatus` field allows disabling a user (e.g., graduated, suspended) without deleting their historical records. |

---

## 7. Open Questions

| # | Question |
|---|----------|
| Q1 | Should certain space types only be bookable by certain roles (e.g., only lecturers can book auditoriums)? |
| Q2 | Is there a maximum lead time or minimum notice period for booking requests? |
| Q3 | Can a booking request be edited after submission, or must the user cancel and re-submit? |
| Q4 | Should the system support recurring bookings (e.g., a lecture series for the whole semester)? |
| Q5 | Are there any limits on the maximum duration of a single booking session? |
| Q6 | Should notifications be sent when a booking is approved/rejected or when check-in is due? (Out of scope for DB design, but affects requirements) |
| Q7 | What is the exact definition of "In Use" status for a space — is it set automatically upon check-in? |
