# 06 — Sample Data

**DBMS:** Microsoft SQL Server (T-SQL)

---

## 1. Users

```sql
INSERT INTO [User] (FullName, Email, PhoneNumber, [Role], Department, AccountStatus)
VALUES
-- Facility Manager
('John Smith',           'john.smith@university.edu',     '555-0101', 'FacilityManager',         'ComputerScience', 'Active'),
-- Facility Staff
('Sarah Johnson',        'sarah.johnson@university.edu',  '555-0102', 'FacilityStaff',           'ComputerScience', 'Active'),
('David Martinez',       'david.martinez@university.edu', '555-0107', 'FacilityStaff',           'ComputerScience', 'Active'),
-- Lecturer
('Dr. Emily Brown',      'emily.brown@university.edu',    '555-0103', 'Lecturer',                'ComputerScience', 'Active'),
('Dr. James Taylor',     'james.taylor@university.edu',   '555-0109', 'Lecturer',                'Mathematics',     'Active'),
-- Teaching Assistant
('Lisa Wilson',          'lisa.wilson@university.edu',    '555-0105', 'TeachingAssistant',       'ComputerScience', 'Active'),
-- Department Administrator
('Robert Chen',          'robert.chen@university.edu',    '555-0106', 'DepartmentAdministrator', 'ComputerScience', 'Active'),
-- Students
('Michael Davis',        'michael.davis@university.edu',  '555-0104', 'Student',                 'ComputerScience', 'Active'),
('Anna Kowalski',        'anna.kowalski@university.edu',  '555-0108', 'Student',                 'ComputerScience', 'Active');
GO
```

---

## 2. Spaces

```sql
INSERT INTO Space (SpaceCode, SpaceName, SpaceType, Building, Floor, RoomNumber, Capacity, CurrentStatus, UsagePolicy)
VALUES
('CS-101', 'Room 101',         'Classroom',          'CS Building',       1, '101', 40,  'Available',        'General teaching. Max 40 people.'),
('CS-201', 'Computer Lab A',   'ComputerLaboratory',  'CS Building',       2, '201', 25,  'Available',        'Computer lab. Only for enrolled CS courses. No food or drinks.'),
('CS-301', 'Meeting Room A',   'MeetingRoom',        'CS Building',       3, '301', 10,  'Available',        'Staff and TA meetings only. Max 10 people.'),
('AUDI-A', 'Main Auditorium',  'Auditorium',         'Main Building',     1, 'A',   200, 'Available',        'Large events, seminars, examinations. Must have facilities staff present.'),
('LAB-B',  'Project Lab B',    'ProjectLaboratory',  'Engineering Bldg',  2, 'B',   16,  'Available',        'Project work. Booking requires advisor approval.'),
('WRK-01', 'Study Nook 1',     'StudentWorkspace',   'CS Building',       1, 'WN01', 8,  'UnderMaintenance', 'Individual study. Currently under maintenance.'),
('WRK-02', 'Study Nook 2',     'StudentWorkspace',   'CS Building',       1, 'WN02', 8,  'Available',        'Individual study. First-come first-served booking.'),
('CS-001', 'Room 001',         'Classroom',          'CS Building',       0, '001', 30,  'TemporarilyClosed', 'Closed for renovation until September.');
GO
```

---

## 3. Facility Types

```sql
INSERT INTO FacilityType (FacilityName)
VALUES
('Projector'),
('Whiteboard'),
('Microphone'),
('Computer'),
('LivestreamingEquipment'),
('AirConditioner');
GO
```

---

## 4. Space-Facility Assignments

```sql
INSERT INTO SpaceFacility (SpaceCode, FacilityName)
VALUES
('CS-101', 'Projector'),
('CS-101', 'Whiteboard'),
('CS-101', 'AirConditioner'),
('CS-201', 'Computer'),
('CS-201', 'Projector'),
('CS-201', 'Whiteboard'),
('CS-201', 'AirConditioner'),
('CS-301', 'Projector'),
('CS-301', 'Whiteboard'),
('CS-301', 'Microphone'),
('AUDI-A', 'Projector'),
('AUDI-A', 'Microphone'),
('AUDI-A', 'LivestreamingEquipment'),
('AUDI-A', 'AirConditioner'),
('LAB-B',  'Computer'),
('LAB-B',  'Projector'),
('LAB-B',  'Whiteboard'),
('LAB-B',  'AirConditioner'),
('WRK-01', 'Whiteboard'),
('WRK-02', 'Whiteboard'),
('WRK-02', 'AirConditioner'),
('CS-001', 'Whiteboard');
GO
```

---

## 5. Booking Requests

```sql
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES
-- (1) Full lifecycle: Pending → Approved → CheckedIn → Completed
(8, 'CS-201', '2026-06-02 09:00', '2026-06-02 11:00', 'StudentActivity',      20,  'Completed'),
-- (2) Checked in, session in progress (no check-out yet)
(4, 'CS-101', '2026-06-02 08:00', '2026-06-02 10:00', 'Lecture',              35,  'CheckedIn'),
-- (3) Pending — awaiting approval
(8, 'WRK-02', '2026-06-03 14:00', '2026-06-03 17:00', 'StudentActivity',       5,  'Pending'),
-- (4) Approved, waiting for check-in
(6, 'CS-301', '2026-06-04 13:00', '2026-06-04 14:30', 'Meeting',               8,  'Approved'),
-- (5) Full lifecycle: Completed
(4, 'AUDI-A', '2026-06-05 10:00', '2026-06-05 12:00', 'Seminar',             150,  'Completed'),
-- (6) Rejected — capacity exceeded
(9, 'CS-101', '2026-06-06 09:00', '2026-06-06 10:30', 'StudentActivity',      50,  'Rejected'),
-- (7) Approved then cancelled
(7, 'CS-301', '2026-06-07 10:00', '2026-06-07 12:00', 'AdministrativeEvent',   5,  'Cancelled'),
-- (8) No-show — never checked in
(8, 'CS-101', '2026-06-08 09:00', '2026-06-08 11:00', 'StudentActivity',      10,  'NoShow');
GO
```

---

## 6. Approvals

```sql
INSERT INTO Approval (BookingID, ApproverID, DecisionTime, DecisionNote, RejectionReason)
VALUES
(1, 2, '2026-06-01 10:00', 'Approved for student lab session.',                                              NULL),
(2, 1, '2026-06-01 09:00', 'Approved for lecture.',                                                         NULL),
(4, 2, '2026-06-03 11:00', 'Approved for TA meeting.',                                                      NULL),
(5, 1, '2026-06-03 14:00', 'Approved for seminar. Remind requester to arrive 15 min early.',                 NULL),
(6, 2, '2026-06-05 15:00', 'Rejected due to capacity constraints.',                                          'Capacity exceeds room limit (max 40, requested 50).'),
(7, 2, '2026-06-06 09:00', 'Approved for administrative meeting.',                                           NULL),
(8, 2, '2026-06-07 10:00', 'Approved — student activity.',                                                  NULL);
GO
```

---

## 7. Usage Sessions (Check-in / Check-out)

```sql
INSERT INTO UsageSession (BookingID, ActualStartTime, CheckInStaffID, InitialCondition, ActualEndTime, FinalCondition, UsageNotes)
VALUES
-- Booking 1: completed session
(1, '2026-06-02 09:05', 2, 'All computers functional, room clean.',
    '2026-06-02 11:10', 'All OK. One keyboard missing a keycap.',            'Session completed on time. Students were working on database project.'),
-- Booking 2: checked in, not yet completed
(2, '2026-06-02 07:55', 2, 'Room tidy. Projector and whiteboard ready.',
    NULL,                NULL,                                                NULL),
-- Booking 5: completed session
(5, '2026-06-05 09:55', 7, 'Auditorium clean. All microphones working. Livestream equipment set up.',
    '2026-06-05 12:05', 'Auditorium in good condition. No issues reported.', 'Seminar on AI ethics ran smoothly. 150 attendees.');
GO
```

---

## 8. Maintenance Records

```sql
INSERT INTO MaintenanceRecord (SpaceCode, ReporterID, AssignedStaffID, ProblemDescription, StartTime, CompletionTime, Status, ResultNote)
VALUES
-- Resolved: AC fixed
('WRK-01', 8,  2, 'Air conditioner not cooling. Room temperature reaching 32°C.',
    '2026-05-28 09:00', '2026-05-30 16:00', 'Resolved',  'Replaced coolant. AC working normally.'),
-- In progress: network issue
('WRK-01', 6,  7, 'Network port by window not providing connectivity.',
    '2026-06-01 10:00', NULL,               'InProgress', 'Waiting for network infrastructure team.'),
-- Open: projector issue
('AUDI-A', 4,  2, 'Projector displaying dim, yellowish image. Bulb may need replacement.',
    '2026-06-06 14:00', NULL,               'Open',       NULL),
-- Open, no staff assigned: keyboard issues
('CS-201', 8,  NULL, 'Several keyboards in Row C have sticky or unresponsive keys.',
    '2026-06-03 11:00', NULL,               'Open',       NULL);
GO
```

---

## 9. Scenario Coverage Summary

| Scenario | Covered By | Tables Involved |
|----------|-----------|----------------|
| **Full lifecycle** (Pending → Approved → CheckedIn → Completed) | Booking 1 | BookingRequest, Approval, UsageSession |
| **In-progress session** (checked in, not yet completed) | Booking 2 | BookingRequest, Approval, UsageSession |
| **Pending — awaiting approval** | Booking 3 | BookingRequest |
| **Approved — awaiting check-in** | Booking 4 | BookingRequest, Approval |
| **Rejected with reason** | Booking 6 | BookingRequest, Approval |
| **Cancelled after approval** | Booking 7 | BookingRequest, Approval |
| **No-show** (never checked in) | Booking 8 | BookingRequest, Approval |
| **Space under maintenance** | WRK-01 (UnderMaintenance) with active maintenance records | Space, MaintenanceRecord |
| **Temporarily closed space** | CS-001 (TemporarilyClosed) | Space |
| **Resolved maintenance** | WRK-01 AC issue | MaintenanceRecord |
| **In-progress maintenance** | WRK-01 network issue | MaintenanceRecord |
| **Open maintenance (unassigned)** | CS-201 keyboard issue | MaintenanceRecord |
| **Multiple facility types per space** | AUDI-A has 4 facilities | SpaceFacility |
| **User disabled (not shown but schema supports)** | AccountStatus = 'Disabled' | User |
| **Overlap scenario (data only)** | Bookings 1 and 9 (conceptual) | BookingRequest |

**Note:** The overlap prevention rule (BR2) and the rule blocking bookings for spaces under maintenance (BR3, BR4) must be enforced by application logic. The sample data above only demonstrates the data structures; it does not attempt to violate these rules, but the database DDL alone cannot prevent overlapping time ranges.
