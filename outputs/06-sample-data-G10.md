# 06 — Sample Data (SQL DML)

Realistic seed data for the schema in `outputs/05-db-definition.md`, designed to exercise **normal operations** and **important exceptional cases** (conflicting bookings, unavailable spaces, no-shows, maintenance, disabled accounts).

**Run on a fresh `CampusSpaceManagement` database.** Explicit IDs are used via `IDENTITY_INSERT` so the FK references below are self-documenting.

---

## 1. Data Coverage Map

| # | Case | Sample rows | Business rule exercised |
|---|------|-------------|-------------------------|
| 1 | Normal workflow — booking submitted → approved → checked in → completed | B1, B11 + approvals + sessions | BR5, BR6, BR7 |
| 2 | Overlapping request is rejected (conflict with an approved booking) | B3 (rejected) vs B2 (approved, same lab) | BR2 |
| 3 | Booking on an under-maintenance space is rejected | B8 + M1, M2 on `B2-301` | BR3, BR4 |
| 4 | Booking on a temporarily closed space is rejected | B9 on `B3-401` | BR3 |
| 5 | Booking on a retired space is rejected | B10 on `C1-101` | BR3 |
| 6 | No-show booking (approved, never checked in) | B7, no UsageSession | BR14 status flow |
| 7 | Cancelled booking without an approval record | B6 | Optional Approval participation |
| 8 | Pending booking awaiting a decision | B4, no Approval row | Optional Approval participation |
| 9 | Session in progress (checked in, not checked out) | B12, `ActualEndTime = NULL` | BR6, BR7, "InUse" |
| 10 | Disabled user account | User 11 (`Disabled`) | BR1 / account status |
| 11 | Maintenance referencing a specific facility unit | M1 (`FacilityID = 11`), M2 (`FacilityID = 12`) | BR9, A5/Q1 |
| 12 | Resolved / closed maintenance history | M3, M4, M5 | BR10 history preservation |

---

## 2. Insert Script

### 2.1. Users  (BR1, BR10)

```sql
USE CampusSpaceManagement;
GO

BEGIN TRANSACTION;

SET IDENTITY_INSERT [User] ON;

INSERT INTO [User]
    (UserID, FullName, Email, PhoneNumber, Role, Department, AccountStatus)
VALUES
    (1,  'Nguyen Van An',     'an.nguyen@uni.edu.vn',    '0912-345-678', 'Student',                 'Computer Science',    'Active'),
    (2,  'Tran Thi Binh',     'binh.tran@uni.edu.vn',    '0912-345-679', 'Student',                 'Computer Science',    'Active'),
    (3,  'Le Quang Minh',     'minh.le@uni.edu.vn',      '0912-345-680', 'Lecturer',                'Computer Science',    'Active'),
    (4,  'Pham Hoang Long',   'long.pham@uni.edu.vn',    '0912-345-681', 'TeachingAssistant',       'Computer Science',    'Active'),
    (5,  'Hoang Thi Mai',     'mai.hoang@uni.edu.vn',    '0912-345-682', 'FacilityStaff',           'Facilities',          'Active'),
    (6,  'Vu Duc Trung',      'trung.vu@uni.edu.vn',     '0912-345-683', 'FacilityStaff',           'Facilities',          'Active'),
    (7,  'Nguyen Thi Huong',  'huong.nguyen@uni.edu.vn', '0912-345-684', 'DepartmentAdministrator', 'Computer Science',    'Active'),
    (8,  'Phan Quoc Tuan',    'tuan.phan@uni.edu.vn',    '0912-345-685', 'FacilityManager',         'Facilities',          'Active'),
    (9,  'Do Thanh Nam',      'nam.do@uni.edu.vn',       '0912-345-686', 'Student',                 'Computer Science',    'Active'),
    (10, 'Hoang Thu Van',     'van.hoang@uni.edu.vn',    '0912-345-687', 'Lecturer',                'Information Systems', 'Active'),
    (11, 'Nguyen Xuan Hieu',  'hieu.nguyen@uni.edu.vn',  '0912-345-688', 'Student',                 'Computer Science',    'Disabled');

SET IDENTITY_INSERT [User] OFF;
GO
```

### 2.2. Spaces  (BR3, BR12, BR15)

```sql
INSERT INTO [Space]
    (SpaceCode, SpaceName, SpaceType, Building, Floor, RoomNumber, Capacity, CurrentStatus, UsagePolicy)
VALUES
    ('A1-101', 'Central Auditorium',    'Auditorium',         'Building A', 1, '101', 200, 'Available',        'Lectures and events only; no food or drink.'),
    ('B1-102', 'Classroom 102',         'Classroom',          'Building B', 1, '102',  50, 'Available',        'Standard teaching room.'),
    ('C2-201', 'Computer Lab 201',      'ComputerLaboratory', 'Building C', 2, '201',  40, 'Available',        '40 workstations; TA supervision required.'),
    ('B2-301', 'Project Lab 301',       'ProjectLaboratory',  'Building B', 3, '301',  25, 'UnderMaintenance', 'Under maintenance - not bookable.'),
    ('D1-105', 'Meeting Room 105',      'MeetingRoom',        'Building D', 1, '105',  12, 'Available',        'Internal meetings only.'),
    ('B3-401', 'Student Workspace 401', 'StudentWorkspace',   'Building B', 3, '401',  30, 'TemporarilyClosed','Temporarily closed for renovation.'),
    ('C1-101', 'Retired Lab',           'ComputerLaboratory', 'Building C', 1, '101',  40, 'Retired',          'Retired - decommissioned.');
GO
```

### 2.3. Facilities  (BR9)

```sql
SET IDENTITY_INSERT Facility ON;

INSERT INTO Facility (FacilityID, FacilityName, SpaceCode)
VALUES
    (1,  'Projector',             'A1-101'),
    (2,  'Microphone',            'A1-101'),
    (3,  'LivestreamingEquipment','A1-101'),
    (4,  'Whiteboard',            'A1-101'),
    (5,  'Projector',             'B1-102'),
    (6,  'Whiteboard',            'B1-102'),
    (7,  'Computer',              'C2-201'),
    (8,  'Computer',              'C2-201'),
    (9,  'AirConditioner',        'C2-201'),
    (10, 'Projector',             'C2-201'),
    (11, 'Computer',              'B2-301'),
    (12, 'AirConditioner',        'B2-301'),
    (13, 'Whiteboard',            'D1-105'),
    (14, 'Microphone',            'D1-105'),
    (15, 'Computer',              'B3-401'),
    (16, 'Computer',              'C1-101');

SET IDENTITY_INSERT Facility OFF;
GO
```

### 2.4. Booking Requests  (BR2, BR11, BR14)

```sql
SET IDENTITY_INSERT BookingRequest ON;

INSERT INTO BookingRequest
    (BookingID, RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES
    -- Normal workflow: completed
    (1,  3,  'A1-101', '2026-07-20T08:00:00', '2026-07-20T10:00:00', 'Lecture',             180, 'Completed'),
    -- Normal workflow: approved, upcoming
    (2,  10, 'C2-201', '2026-08-10T09:00:00', '2026-08-10T11:00:00', 'Workshop',             35, 'Approved'),
    -- Exceptional: overlaps B2 in the same lab -> rejected (BR2)
    (3,  9,  'C2-201', '2026-08-10T09:30:00', '2026-08-10T11:30:00', 'StudentActivity',      30, 'Rejected'),
    -- Normal workflow: pending approval
    (4,  7,  'D1-105', '2026-08-12T14:00:00', '2026-08-12T15:00:00', 'AdministrativeEvent', 10, 'Pending'),
    -- Normal workflow: approved, upcoming
    (5,  1,  'B1-102', '2026-08-14T13:00:00', '2026-08-14T17:00:00', 'Meeting',             20, 'Approved'),
    -- Exceptional: cancelled before any decision (no Approval row)
    (6,  3,  'A1-101', '2026-07-25T09:00:00', '2026-07-25T12:00:00', 'Seminar',            150, 'Cancelled'),
    -- Exceptional: approved but nobody showed up (no UsageSession)
    (7,  10, 'B1-102', '2026-07-28T10:00:00', '2026-07-28T12:00:00', 'Examination',         45, 'NoShow'),
    -- Exceptional: space under maintenance -> rejected (BR3/BR4)
    (8,  9,  'B2-301', '2026-08-15T09:00:00', '2026-08-15T11:00:00', 'Workshop',            20, 'Rejected'),
    -- Exceptional: space temporarily closed -> rejected (BR3)
    (9,  2,  'B3-401', '2026-08-16T08:00:00', '2026-08-16T10:00:00', 'StudentActivity',     25, 'Rejected'),
    -- Exceptional: space retired -> rejected (BR3)
    (10, 1,  'C1-101', '2026-08-17T09:00:00', '2026-08-17T10:00:00', 'Meeting',             10, 'Rejected'),
    -- Normal workflow: completed (past)
    (11, 4,  'C2-201', '2026-08-08T13:00:00', '2026-08-08T16:00:00', 'Lecture',             40, 'Completed'),
    -- Normal workflow: checked in, session in progress
    (12, 3,  'A1-101', '2026-08-05T09:00:00', '2026-08-05T12:00:00', 'Lecture',            180, 'CheckedIn');

SET IDENTITY_INSERT BookingRequest OFF;
GO
```

### 2.5. Approvals  (BR5)

```sql
INSERT INTO Approval (BookingID, ApproverID, DecisionTime, DecisionNote, RejectionReason)
VALUES
    (1,  8, '2026-07-18T10:00:00', 'Approved for lecture.',             NULL),
    (2,  5, '2026-08-08T09:00:00', 'Workshop approved.',                NULL),
    (3,  5, '2026-08-08T09:15:00', 'Rejected.',                         'Time conflicts with an approved workshop in the same lab (BR2).'),
    (5,  5, '2026-08-11T09:00:00', 'Approved.',                         NULL),
    (7,  8, '2026-07-26T10:00:00', 'Approved for examination.',         NULL),
    (8,  6, '2026-08-14T09:00:00', 'Rejected.',                         'Space is under maintenance and cannot be booked (BR3/BR4).'),
    (9,  6, '2026-08-15T09:00:00', 'Rejected.',                         'Space is temporarily closed (BR3).'),
    (10, 8, '2026-08-16T09:00:00', 'Rejected.',                         'Space is retired (BR3).'),
    (11, 8, '2026-08-06T10:00:00', 'Approved.',                         NULL),
    (12, 5, '2026-08-04T09:00:00', 'Approved.',                         NULL);
GO
```

> Bookings 4 (pending) and 6 (cancelled) intentionally have **no** Approval row — verifying the optional participation of the 1:1 relationship.

### 2.6. Usage Sessions  (BR6, BR7, BR8)

```sql
INSERT INTO UsageSession
    (BookingID, ApprovalID, ActualStartTime, CheckInStaffID, InitialCondition, ActualEndTime, FinalCondition, UsageNotes)
VALUES
    -- Completed session
    (1,  1,  '2026-07-20T07:55:00', 5, 'Clean and ready.',  '2026-07-20T10:05:00', 'Clean; projector working.', 'Lecture delivered; no issues.'),
    -- Completed session
    (11, 11, '2026-08-08T12:50:00', 6, 'Normal condition.', '2026-08-08T16:10:00', 'Normal condition.',         'TA-supervised lab session.'),
    -- Session in progress (check-out fields still NULL)
    (12, 12, '2026-08-05T08:55:00', 5, 'Clean and ready.',  NULL,                  NULL,                        NULL);
GO
```

> Booking 7 (NoShow) deliberately has no UsageSession; booking 12's `ActualEndTime` is NULL to represent an ongoing session.

### 2.7. Maintenance Records  (A5/Q1, BR4, BR10)

```sql
SET IDENTITY_INSERT MaintenanceRecord ON;

INSERT INTO MaintenanceRecord
    (MaintenanceID, SpaceCode, FacilityID, ReporterID, AssignedStaffID, ProblemDescription, StartTime, CompletionTime, Status, ResultNote)
VALUES
    (1, 'B2-301', 11, 4, 6, 'Computer C-201 fails to boot; network cable damaged.', '2026-08-01T09:00:00', NULL,                'Open',     NULL),
    (2, 'B2-301', 12, 1, 6, 'Air conditioning not cooling.',                       '2026-08-02T10:00:00', NULL,                'Open',     NULL),
    (3, 'D1-105', 13, 7, 5, 'Whiteboard surface damaged.',                        '2026-06-15T09:00:00', '2026-06-18T15:00:00', 'Resolved', 'Whiteboard replaced.'),
    (4, 'B1-102', NULL, 3, 6, 'Cleaning issue: rubbish not collected.',            '2026-07-10T08:00:00', '2026-07-10T16:00:00', 'Closed',   'Cleaned.'),
    (5, 'C2-201', NULL, 3, 5, 'Network problems in the lab reported.',             '2026-07-29T09:00:00', '2026-07-30T11:00:00', 'Resolved', 'Network switch replaced.');

SET IDENTITY_INSERT MaintenanceRecord OFF;
GO

COMMIT TRANSACTION;
GO
```

---

## 3. What Each Exceptional Case Tests

| Sample data | Expected behavior | Test objective |
|-------------|-------------------|----------------|
| B3 rejected against B2 (same `C2-201`, overlapping) | B3 must never become `Approved` | BR2 overlap prevention (application check) |
| B8 on `B2-301` (status `UnderMaintenance`, active M1/M2) | Rejected at submit / approval | BR3 + BR4 |
| B9 on `B3-401` (`TemporarilyClosed`) | Rejected | BR3 |
| B10 on `C1-101` (`Retired`) | Rejected | BR3 |
| B7 `NoShow` with no session | Session must not be creatable | No-show flow (§1.8 report) |
| B6 `Cancelled` with no Approval | Allowed (approval optional) | Optional participation |
| B4 `Pending` with no Approval | Allowed (decision pending) | Optional participation |
| B12 session with `ActualEndTime = NULL` | Space considered "in use" | BR6/BR7, InUse handling |
| User 11 `Disabled` | Cannot submit bookings | BR1 / account status |
| M1/M2 reference `FacilityID` 11/12 | Per-unit maintenance traceability | BR9, A5/Q1 |
| M3/M4/M5 completed records | Persist for history/reporting | BR10 |

---

## 4. Notes

- The script does **not** insert two simultaneously `Approved` overlapping bookings, because BR2 is an application-level rule: the data instead records the rejected attempt (B3). To test the guard itself, run the overlap check from `outputs/05-db-definition.md` §4 against B2 and B3.
- All inserts are wrapped in a single transaction; on error the whole batch rolls back.
- Dates use `DATETIME2` literals around the assumed "current" date (2026-08-05) so upcoming/history reports behave realistically.