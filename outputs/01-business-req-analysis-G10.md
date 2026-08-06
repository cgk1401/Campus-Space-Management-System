# 01 — Business Requirement Analysis

**Sources:** `req/business-requirement.md` (original narrative) and `req/summary-business-requirement.md` (structured checklist, §1.1–§1.9).
Section references `§x.y` point to the structured summary; references in the business rules table point to both.

---

## 1. Business Purpose

The School of Computer Science wants to build a database system to manage the booking and usage of shared campus spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces). The current manual process (spreadsheets, shared calendars, email/phone/in-person requests) is no longer sustainable as the number of classes, student projects, workshops, seminars, and academic events grows. Requests, approval, check-in/check-out, maintenance, and incident reporting must move from manual coordination to a centralized database.

The system's main goals (§1.9):
- Manage shared campus spaces fairly and transparently.
- Avoid overlapping / conflicting bookings for the same space.
- Prevent the use of unavailable spaces (under maintenance, temporarily closed, or retired).
- Preserve usage, booking, and maintenance history for reporting.
- Enable facility staff to efficiently handle approvals, check-in/check-out, and maintenance tracking.

---

## 2. Actors (User Roles)

| Role | Description (from requirement) | Typical permissions |
|------|--------------------------------|---------------------|
| **Student** | Submits booking requests (student activities). | Create bookings |
| **Lecturer** | Submits booking requests for lectures, examinations, seminars. | Create bookings |
| **Teaching Assistant** | Submits booking requests on behalf of lecturers. | Create bookings |
| **Facility Staff** | Handles approvals, check-in/check-out, maintenance; views reports. | Approve, check-in, maintain, view reports |
| **Department Administrator** | Oversees department bookings; views reports. | View reports |
| **Facility Manager** | Full oversight: approvals, maintenance, reporting. | Approve, check-in, maintain, view all reports |

Each user must have a university account (§1.2). Users are identified by `UserID`; the stored information includes full name, email, phone number, role, department, and account status.

---

## 3. Entities & Attributes

### 3.1. User (§1.2)
| Attribute | Type | Notes |
|-----------|------|-------|
| UserID | PK | University account identifier |
| FullName | VARCHAR | Mandatory |
| Email | VARCHAR | Mandatory |
| PhoneNumber | VARCHAR | Optional |
| Role | ENUM | Student, Lecturer, TeachingAssistant, FacilityStaff, DepartmentAdministrator, FacilityManager |
| Department | VARCHAR | Optional |
| AccountStatus | ENUM/VARCHAR | e.g., Active, Disabled |

### 3.2. Space (§1.3)
| Attribute | Type | Notes |
|-----------|------|-------|
| SpaceCode | PK | Unique code (e.g., "B1-101") |
| SpaceName | VARCHAR | Mandatory |
| SpaceType | ENUM | Auditorium, Classroom, ComputerLaboratory, ProjectLaboratory, MeetingRoom, StudentWorkspace |
| Building | VARCHAR | Mandatory |
| Floor | INT | Mandatory |
| RoomNumber | VARCHAR | Mandatory |
| Capacity | INT | Must be > 0 |
| CurrentStatus | ENUM | Available, InUse, UnderMaintenance, TemporarilyClosed, Retired |
| UsagePolicy | TEXT | Free-form usage policy |

### 3.3. Facility (§1.3 — individual physical units)
| Attribute | Type | Notes |
|-----------|------|-------|
| FacilityID | PK | Surrogate key for the individual unit (e.g., the specific projector #12) |
| FacilityName | VARCHAR | Type indicator, e.g., Projector, Whiteboard, Microphone, Computer, LivestreamingEquipment, AirConditioner |
| SpaceCode | FK → Space | Belongs to exactly one Space (1:N); mandatory |

> **Modeling decision (from §1.3):** A facility is an individual physical unit, not a type. Each unit gets its own `FacilityID`, a `FacilityName` indicating its type, and belongs to exactly one space. This allows a specific unit to be referenced in maintenance records.

### 3.4. BookingRequest (§1.4)
| Attribute | Type | Notes |
|-----------|------|-------|
| BookingID | PK | |
| RequesterID | FK → User | User who submitted the request |
| SpaceCode | FK → Space | Space requested |
| StartTime | DATETIME | Requested start |
| EndTime | DATETIME | Requested end; must be > StartTime |
| Purpose | ENUM | Lecture, Examination, Seminar, Workshop, Meeting, StudentActivity, AdministrativeEvent |
| ExpectedParticipants | INT | Must be > 0 |
| Status | ENUM | Pending, Approved, Rejected, Cancelled, CheckedIn, Completed, NoShow |

### 3.5. Approval (§1.5)
| Attribute | Type | Notes |
|-----------|------|-------|
| BookingID | PK, FK → BookingRequest | 1:1 with BookingRequest (no new surrogate key) |
| ApproverID | FK → User | FacilityStaff or FacilityManager who decided |
| DecisionTime | DATETIME | Mandatory |
| DecisionNote | TEXT | Mandatory |
| RejectionReason | TEXT | Required (NOT NULL) only when decision is Rejected |

### 3.6. UsageSession (§1.6)
| Attribute | Type | Notes |
|-----------|------|-------|
| BookingID | PK, FK → BookingRequest | 1:1 with BookingRequest (no new surrogate key) |
| ApprovalID | FK → Approval | Additional FK; a session may only exist if a valid approval exists |
| ActualStartTime | DATETIME | Recorded at check-in |
| CheckInStaffID | FK → User | Staff who performed check-in |
| InitialCondition | TEXT | Space condition on arrival |
| ActualEndTime | DATETIME | Recorded at completion; NULL until the session ends |
| FinalCondition | TEXT | Space condition on departure; NULL until completion |
| UsageNotes | TEXT | Free-form notes; NULL until completion |

> **Modeling decision (from §1.6):** UsageSession uses `BookingID` as both PK and FK to preserve the 1:1 relationship with BookingRequest, plus an additional `ApprovalID` FK to Approval. This guarantees a UsageSession exists only when a valid Approval exists for the booking, while keeping direct traceability to the original booking request.

### 3.7. MaintenanceRecord (§1.7)
| Attribute | Type | Notes |
|-----------|------|-------|
| MaintenanceID | PK | |
| SpaceCode | FK → Space | Related space; mandatory |
| FacilityID | FK → Facility | Optional reference to the specific faulty unit (§1.3 rationale) — see Assumption A5 |
| ReporterID | FK → User | Any user role may report a problem |
| AssignedStaffID | FK → User | Assigned staff (FacilityStaff/FacilityManager) |
| ProblemDescription | TEXT | Mandatory |
| StartTime | DATETIME | Mandatory |
| CompletionTime | DATETIME | NULL until resolved |
| Status | ENUM/VARCHAR | e.g., Open, InProgress, Resolved, Closed |
| ResultNote | TEXT | Result of the maintenance; optional |

---

## 4. Relationships & Cardinalities

| Relationship | Entity A | Entity B | Cardinality | Participation |
|--------------|----------|----------|-------------|---------------|
| Submits | User (Requester) | BookingRequest | 1:N | User: optional; BookingRequest: mandatory |
| Targets | BookingRequest | Space | N:1 | BookingRequest: mandatory; Space: optional |
| Approves | User (Approver) | Approval | 1:N | User: optional; Approval: mandatory |
| Decides-on | Approval | BookingRequest | 1:1 | Approval: mandatory; BookingRequest: optional |
| Records (check-in) | BookingRequest | UsageSession | 1:1 | UsageSession: mandatory; BookingRequest: optional |
| Validates | Approval | UsageSession | 1:1 | Approval: optional; UsageSession: mandatory |
| Checks-in | User (Staff) | UsageSession | 1:N | User: optional; UsageSession: mandatory |
| Houses | Space | Facility | 1:N | Space: optional; Facility: mandatory |
| Reports | User (Reporter) | MaintenanceRecord | 1:N | User: optional; MaintenanceRecord: mandatory |
| Assigned-to | User (Staff) | MaintenanceRecord | 1:N | User: optional; MaintenanceRecord: optional |
| Affects | Space | MaintenanceRecord | 1:N | Space: optional; MaintenanceRecord: mandatory |
| Concerns | Facility | MaintenanceRecord | 1:N | Facility: optional; MaintenanceRecord: optional (Assumption A5) |

**Notes on participation:**
- "Optional" on the User side means not every user must have a booking, approval, check-in, or maintenance record.
- "Optional" on the Space side means a space may have zero bookings, zero facilities, or zero maintenance records.
- BookingRequest → UsageSession: optional because cancelled/rejected/no-show bookings never reach check-in; a UsageSession only exists after a successful check-in of an approved booking.
- Approval → UsageSession: optional because an approval does not force a check-in; UsageSession → Approval is mandatory to enforce "session only after valid approval."

---

## 5. Business Rules

| # | Rule | Source |
|---|------|--------|
| BR1 | Each user must have a university account (UserID) to submit a booking request. | §1.2 |
| BR2 | The same space cannot have two approved/active bookings with overlapping time periods (conflict prevention). | §1.4 |
| BR3 | A space with status `UnderMaintenance`, `TemporarilyClosed`, or `Retired` cannot be booked. | §1.4 |
| BR4 | A space with an active (unresolved) maintenance record cannot be booked. | §1.7 |
| BR5 | Approvals/rejections must record the approver, decision time, and decision note. If rejected, a rejection reason is required. | §1.5 |
| BR6 | Check-in records the actual start time, the staff member who checked in, and the initial condition of the space. | §1.6 |
| BR7 | Check-out (completion) records the actual end time, the final condition of the space, and usage notes. | §1.6 |
| BR8 | A usage session can only exist for a booking that has a valid approval (UsageSession carries `ApprovalID` FK). | §1.6 |
| BR9 | Facilities are individual physical units: each unit has a surrogate `FacilityID`, a `FacilityName` type, and belongs to exactly one space. | §1.3 |
| BR10 | The system must preserve historical records of bookings and maintenance — no hard-deletion of past records. | §1.8 |
| BR11 | Purpose of use is one of: Lecture, Examination, Seminar, Workshop, Meeting, StudentActivity, AdministrativeEvent. | §1.4 |
| BR12 | Space capacity must be a positive integer (Capacity > 0). | §1.3 (implied) |
| BR13 | Booking end time must be after start time (EndTime > StartTime). | §1.4 (implied) |
| BR14 | Booking status is one of: Pending, Approved, Rejected, Cancelled, CheckedIn, Completed, NoShow. | §1.4 |
| BR15 | Space status is one of: Available, InUse, UnderMaintenance, TemporarilyClosed, Retired. | §1.3 |
| BR16 | Only users with role FacilityStaff or FacilityManager may approve/reject bookings, check in bookings, or be assigned maintenance work. **Enforcement: application-level (role-based access), not DDL.** | §1.5, §1.6, §1.7 (implied) |
| BR17 | Overlap prevention (BR2) and "no booking while under maintenance" (BR3/BR4) must be enforced by application logic against time-interval and status data; they cannot be expressed purely as DDL constraints. | §1.4 |

---

## 6. Assumptions

| # | Assumption |
|---|-----------|
| A1 | Approval is modeled as a separate 1:1 table that is created when a decision is made; a booking request may exist without an Approval (e.g., still pending). |
| A2 | The `InUse` space status is set at check-in and cleared at check-out; it may alternatively be derived from active sessions. Treated as a status field for now. |
| A3 | Only FacilityStaff or FacilityManager act as approvers and check-in staff (see BR16). |
| A4 | Maintenance may be reported by any user role; only FacilityStaff or FacilityManager can be assigned as the responsible staff. |
| A5 | `MaintenanceRecord.FacilityID` is an optional reference to the specific faulty unit; this is justified by the §1.3 statement that per-unit modeling exists "so individual units can be referenced in maintenance records." The requirement's maintenance field list (§1.7) does not explicitly name it, so this is treated as an assumption and a target for confirmation. |
| A6 | `AccountStatus` allows disabling a user (e.g., graduated, suspended) without deleting historical records. |
| A7 | A facility unit has no tracked status/condition field in the requirements; if per-unit availability is needed (e.g., projector broken), it would be derived from maintenance records rather than stored on Facility. |
| A8 | "Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings" (§1.8) is a reporting/query concern; no extra entities are needed beyond the ones listed. |

---

## 7. Open Questions

| # | Question |
|---|----------|
| Q1 | Should MaintenanceRecord carry an explicit `FacilityID` (per-unit reference) as modeled in A5, or is the related space sufficient? |
| Q2 | Should certain space types be bookable only by certain roles (e.g., only lecturers can book auditoriums)? |
| Q3 | Is there a maximum lead time or minimum notice period for booking requests? |
| Q4 | Can a booking request be edited after submission, or must the user cancel and re-submit? |
| Q5 | Should the system support recurring bookings (e.g., a lecture series for the whole semester)? |
| Q6 | Are there limits on the maximum duration of a single booking session? |
| Q7 | What is the exact definition of the space status `InUse` — set automatically on check-in, or manually? |
| Q8 | Is a facility unit reusable/movable across spaces, or is it permanently attached to one space (affects the 1:N Space→Facility constraint)? |
| Q9 | Does a rejected booking need a record even when no approval was ever created, or only when a decision was actually made? |