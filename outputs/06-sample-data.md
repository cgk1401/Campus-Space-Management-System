# 06 — Sample Data Preparation

## DBMS

Microsoft SQL Server

## Sample Data INSERT Statements

```sql
-- ============================================================
-- Sample Data: Campus Space Management System
-- DBMS: Microsoft SQL Server
-- ============================================================

-- ============================================================
-- 1. [User]
-- ============================================================
INSERT INTO [User] (FullName, Email, PhoneNumber, Role, Department, AccountStatus)
VALUES
    -- Facility Staff & Managers
    ('Nguyen Van An',    'an.nguyen@university.edu.vn', '0901-123-456', 'FacilityStaff',          'School of Computer Science', 'Active'),
    ('Tran Thi Binh',    'binh.tran@university.edu.vn',  '0902-234-567', 'FacilityManager',        'School of Computer Science', 'Active'),
    ('Le Van Cuong',     'cuong.le@university.edu.vn',   '0903-345-678', 'FacilityStaff',          'School of Computer Science', 'Active'),

    -- Lecturers
    ('Pham Thi Dung',    'dung.pham@university.edu.vn',  '0904-456-789', 'Lecturer',               'School of Computer Science', 'Active'),
    ('Hoang Van Em',     'em.hoang@university.edu.vn',   '0905-567-890', 'Lecturer',               'School of Computer Science', 'Active'),
    ('Ngo Thi Phuong',   'phuong.ngo@university.edu.vn', '0906-678-901', 'Lecturer',               'School of Computer Science', 'Active'),

    -- Teaching Assistants
    ('Do Van Giang',     'giang.do@university.edu.vn',   '0907-789-012', 'TeachingAssistant',      'School of Computer Science', 'Active'),
    ('Vu Thi Hoa',       'hoa.vu@university.edu.vn',     '0908-890-123', 'TeachingAssistant',      'School of Computer Science', 'Active'),

    -- Students
    ('Ly Van Khanh',     'khanh.ly@university.edu.vn',   '0909-901-234', 'Student',                'School of Computer Science', 'Active'),
    ('Ta Thi Lan',       'lan.ta@university.edu.vn',     '0910-012-345', 'Student',                'School of Computer Science', 'Active'),
    ('Dang Van Minh',    'minh.dang@university.edu.vn',  '0911-123-456', 'Student',                'School of Computer Science', 'Active'),
    ('Bui Thi Ngoc',     'ngoc.bui@university.edu.vn',   '0912-234-567', 'Student',                'School of Computer Science', 'Active'),

    -- Department Administrator
    ('Huynh Van Phuc',   'phuc.huynh@university.edu.vn', '0913-345-678', 'DepartmentAdministrator', 'School of Computer Science', 'Active'),

    -- Inactive / Suspended users for edge cases
    ('Quach Thi Quynh',  'quynh.quach@university.edu.vn','0914-456-789', 'Student',                'School of Computer Science', 'Inactive'),
    ('La Van Son',       'son.la@university.edu.vn',     '0915-567-890', 'Lecturer',               'School of Computer Science', 'Suspended');


-- ============================================================
-- 2. [Space]
-- ============================================================
INSERT INTO [Space] (SpaceCode, SpaceName, SpaceType, Building, Floor, RoomNumber, Capacity, CurrentStatus, UsagePolicy)
VALUES
    -- Available spaces
    ('AUD-101', 'Auditorium A1',   'Auditorium',       'Building A', 1, '101', 200, 'Available',        'No food or drinks. Max booking: 4 hours.'),
    ('CLS-201', 'Classroom C2',    'Classroom',        'Building A', 2, '201', 60,  'Available',        'Standard classroom rules apply.'),
    ('CLS-202', 'Classroom C3',    'Classroom',        'Building A', 2, '202', 40,  'Available',        'Standard classroom rules apply.'),
    ('CLS-301', 'Classroom C4',    'Classroom',        'Building B', 3, '301', 50,  'Available',        'Whiteboard available.'),
    ('LAB-101', 'Computer Lab B1', 'ComputerLab',       'Building B', 1, '101', 40,  'Available',        'Food and drinks prohibited. No software installation without prior approval.'),
    ('LAB-102', 'Computer Lab B2', 'ComputerLab',       'Building B', 1, '102', 30,  'Available',        'Food and drinks prohibited.'),
    ('LAB-201', 'Project Lab P1',  'ProjectLab',        'Building B', 2, '201', 20,  'Available',        'Only authorized project members allowed after 6 PM.'),

    -- Meeting rooms
    ('MTG-101', 'Meeting Room M1', 'MeetingRoom',       'Building A', 3, '301', 15,  'Available',        'Bookings limited to 2 hours.'),
    ('MTG-102', 'Meeting Room M2', 'MeetingRoom',       'Building A', 3, '302', 10,  'Available',        'Bookings limited to 2 hours.'),

    -- Student workspace
    ('WRK-001', 'Student Hub',     'StudentWorkspace',  'Building A', 1, 'G01', 30,  'Available',        'Open for all students. First-come, first-served.'),

    -- Spaces with non-available statuses (for edge cases)
    ('LAB-103', 'Computer Lab B3', 'ComputerLab',       'Building B', 1, '103', 35,  'UnderMaintenance', 'Under maintenance until further notice.'),
    ('AUD-102', 'Auditorium A2',   'Auditorium',       'Building A', 1, '102', 150, 'TemporarilyClosed', 'Closed for renovation.'),
    ('CLS-401', 'Classroom C5',    'Classroom',        'Building B', 4, '401', 45,  'Retired',           'This room has been decommissioned.');


-- ============================================================
-- 3. [Facility]
-- ============================================================
INSERT INTO [Facility] (FacilityName, SpaceCode)
VALUES
    -- AUD-101: Auditorium A1
    ('Projector',             'AUD-101'),
    ('Microphone',            'AUD-101'),
    ('LivestreamingEquipment','AUD-101'),
    ('AirConditioner',        'AUD-101'),

    -- CLS-201: Classroom C2
    ('Projector',             'CLS-201'),
    ('Whiteboard',            'CLS-201'),
    ('AirConditioner',        'CLS-201'),

    -- CLS-202: Classroom C3
    ('Whiteboard',            'CLS-202'),
    ('AirConditioner',        'CLS-202'),

    -- CLS-301: Classroom C4
    ('Projector',             'CLS-301'),
    ('Whiteboard',            'CLS-301'),
    ('Computer',              'CLS-301'),
    ('AirConditioner',        'CLS-301'),

    -- LAB-101: Computer Lab B1
    ('Projector',             'LAB-101'),
    ('Whiteboard',            'LAB-101'),
    ('Computer',              'LAB-101'),
    ('AirConditioner',        'LAB-101'),

    -- LAB-102: Computer Lab B2
    ('Projector',             'LAB-102'),
    ('Computer',              'LAB-102'),
    ('AirConditioner',        'LAB-102'),

    -- LAB-201: Project Lab P1
    ('Whiteboard',            'LAB-201'),
    ('Computer',              'LAB-201'),
    ('AirConditioner',        'LAB-201'),

    -- MTG-101: Meeting Room M1
    ('Projector',             'MTG-101'),
    ('Whiteboard',            'MTG-101'),
    ('AirConditioner',        'MTG-101'),

    -- MTG-102: Meeting Room M2
    ('Whiteboard',            'MTG-102'),

    -- LAB-103 (UnderMaintenance)
    ('Projector',             'LAB-103'),
    ('Computer',              'LAB-103'),
    ('AirConditioner',        'LAB-103'),

    -- AUD-102 (TemporarilyClosed)
    ('Projector',             'AUD-102'),
    ('Microphone',            'AUD-102'),
    ('AirConditioner',        'AUD-102'),

    -- CLS-401 (Retired)
    ('Whiteboard',            'CLS-401');


-- ============================================================
-- 4. [BookingRequest]
-- ============================================================
INSERT INTO [BookingRequest] (RequesterID, SpaceCode, RequestedStartTime, RequestedEndTime, PurposeOfUse, ExpectedParticipants, Status)
VALUES
    -- Booking 1: Lecturer Pham Thi Dung (4) books AUD-101 for a Lecture → Approved → CheckedIn → Completed
    (4,  'AUD-101', '2026-06-15 07:30:00', '2026-06-15 09:30:00', 'Lecture',            180, 'Completed'),

    -- Booking 2: Lecturer Hoang Van Em (5) books CLS-201 for a Seminar → Approved → CheckedIn → Completed
    (5,  'CLS-201', '2026-06-15 08:00:00', '2026-06-15 10:00:00', 'Seminar',            50,  'Completed'),

    -- Booking 3: Student Ly Van Khanh (9) books LAB-101 for Student Activity → Approved → CheckedIn → NoShow
    (9,  'LAB-101', '2026-06-16 13:00:00', '2026-06-16 16:00:00', 'StudentActivity',    25,  'NoShow'),

    -- Booking 4: Teaching Assistant Do Van Giang (7) books CLS-202 for a Workshop → Approved → CheckedIn → Completed
    (7,  'CLS-202', '2026-06-17 09:00:00', '2026-06-17 12:00:00', 'Workshop',           35,  'Completed'),

    -- Booking 5: Student Ta Thi Lan (10) books MTG-101 for a Meeting → Approved → (awaiting check-in)
    (10, 'MTG-101', '2026-06-20 14:00:00', '2026-06-20 15:30:00', 'Meeting',            10,  'Approved'),

    -- Booking 6: Student Dang Van Minh (11) books LAB-201 for StudentActivity → Approved → CheckedIn → Completed
    (11, 'LAB-201', '2026-06-18 10:00:00', '2026-06-18 13:00:00', 'StudentActivity',    15,  'Completed'),

    -- Booking 7: Lecturer Ngo Thi Phuong (6) books CLS-301 for an Examination → Pending (not yet approved)
    (6,  'CLS-301', '2026-06-22 08:00:00', '2026-06-22 11:00:00', 'Examination',        45,  'Pending'),

    -- Booking 8: Student Bui Thi Ngoc (12) books WRK-001 for StudentActivity → Rejected
    (12, 'WRK-001', '2026-06-19 09:00:00', '2026-06-19 17:00:00', 'StudentActivity',    25,  'Rejected'),

    -- Booking 9: Teaching Assistant Vu Thi Hoa (8) books CLS-201 for a Workshop → Cancelled by requester
    (8,  'CLS-201', '2026-06-21 13:00:00', '2026-06-21 16:00:00', 'Workshop',           40,  'Cancelled'),

    -- Booking 10: Lecturer Pham Thi Dung (4) books CLS-301 for a Lecture → Approved → CheckedIn → Completed
    (4,  'CLS-301', '2026-06-10 08:00:00', '2026-06-10 10:00:00', 'Lecture',            45,  'Completed'),

    -- Booking 11: Department Admin Huynh Van Phuc (13) books MTG-102 for AdministrativeEvent → Pending
    (13, 'MTG-102', '2026-06-25 10:00:00', '2026-06-25 12:00:00', 'AdministrativeEvent', 8,  'Pending'),

    -- Booking 12: Student Ly Van Khanh (9) books AUD-101 for a Workshop → Approved → CheckedIn → Completed
    (9,  'AUD-101', '2026-06-12 14:00:00', '2026-06-12 17:00:00', 'Workshop',           150, 'Completed'),

    -- Booking 13: Lecturer Hoang Van Em (5) books LAB-102 for a Lecture → Pending
    (5,  'LAB-102', '2026-06-26 07:30:00', '2026-06-26 09:30:00', 'Lecture',            25,  'Pending'),

    -- Booking 14: Student Dang Van Minh (11) books LAB-103 (UnderMaintenance) → Rejected by system/approver
    (11, 'LAB-103', '2026-06-20 08:00:00', '2026-06-20 11:00:00', 'StudentActivity',    20,  'Rejected'),

    -- Booking 15: Student Bui Thi Ngoc (12) books AUD-102 (TemporarilyClosed) → Rejected
    (12, 'AUD-102', '2026-06-23 09:00:00', '2026-06-23 12:00:00', 'Seminar',            100, 'Rejected'),

    -- Booking 16: Student Ta Thi Lan (10) books MTG-101 for Meeting → Pending (future booking)
    (10, 'MTG-101', '2026-07-01 10:00:00', '2026-07-01 11:00:00', 'Meeting',            8,   'Pending'),

    -- Booking 17: Lecturer Ngo Thi Phuong (6) books CLS-202 for AdministrativeEvent → Approved
    (6,  'CLS-202', '2026-06-28 14:00:00', '2026-06-28 16:00:00', 'AdministrativeEvent', 20,  'Approved');


-- ============================================================
-- 5. [Approval]
-- ============================================================
INSERT INTO [Approval] (BookingID, ApproverID, DecisionTime, DecisionNote, RejectionReason)
VALUES
    -- Booking 1 → Approved (by Tran Thi Binh - FacilityManager)
    (1,  2, '2026-06-10 08:00:00', 'Approved for lecture slot.', NULL),

    -- Booking 2 → Approved (by Nguyen Van An - FacilityStaff)
    (2,  1, '2026-06-10 09:00:00', 'Seminar approved.', NULL),

    -- Booking 3 → Approved (by Tran Thi Binh - FacilityManager)
    (3,  2, '2026-06-11 10:00:00', 'Student activity approved.', NULL),

    -- Booking 4 → Approved (by Le Van Cuong - FacilityStaff)
    (4,  3, '2026-06-12 11:00:00', 'Workshop booking approved.', NULL),

    -- Booking 5 → Approved (by Nguyen Van An - FacilityStaff)
    (5,  1, '2026-06-18 09:00:00', 'Meeting room approved.', NULL),

    -- Booking 6 → Approved (by Nguyen Van An - FacilityStaff)
    (6,  1, '2026-06-13 10:00:00', 'Project lab booking approved.', NULL),

    -- Booking 8 → Rejected (by Tran Thi Binh - FacilityManager)
    (8,  2, '2026-06-17 14:00:00', 'Student Hub cannot be reserved exclusively for full-day activity.', 'Student Hub is a first-come, first-served open workspace. Exclusive full-day booking is not permitted.'),

    -- Booking 10 → Approved (by Le Van Cuong - FacilityStaff)
    (10, 3, '2026-06-05 08:30:00', 'Lecture approved.', NULL),

    -- Booking 12 → Approved (by Tran Thi Binh - FacilityManager)
    (12, 2, '2026-06-08 09:00:00', 'Workshop approved.', NULL),

    -- Booking 14 → Rejected (by Nguyen Van An - FacilityStaff)
    (14, 1, '2026-06-18 15:00:00', 'Lab is under maintenance.', 'Cannot book a space that is currently under maintenance.'),

    -- Booking 15 → Rejected (by Tran Thi Binh - FacilityManager)
    (15, 2, '2026-06-20 10:00:00', 'Auditorium is temporarily closed.', 'The auditorium is closed for renovation. Please select another space.'),

    -- Booking 17 → Approved (by Le Van Cuong - FacilityStaff)
    (17, 3, '2026-06-24 09:00:00', 'Administrative event approved.', NULL);


-- ============================================================
-- 6. [UsageSession]
-- ============================================================
INSERT INTO [UsageSession] (BookingID, ActualStartTime, CheckInStaffID, InitialCondition, ActualEndTime, FinalCondition, UsageNotes)
VALUES
    -- Booking 1: Completed — Lecture at AUD-101
    (1,  '2026-06-15 07:35:00', 1, 'Clean, all equipment functioning. Projector working. AC set to 24°C.',
         '2026-06-15 09:25:00', 'Clean, all equipment returned to original state.', 'Lecture ended on time. No issues.'),

    -- Booking 2: Completed — Seminar at CLS-201
    (2,  '2026-06-15 08:05:00', 3, 'Clean. Whiteboard cleaned. Desks arranged in rows.',
         '2026-06-15 09:55:00', 'Whiteboard needs cleaning. Desks moved but acceptable.', 'Seminar had group discussion. Some rearrangement of furniture.'),

    -- Booking 3: NoShow — Student Activity at LAB-101
    (3,  '2026-06-16 13:00:00', 1, 'All computers functioning. Room clean.',
         NULL, NULL, 'Requester did not show up. Waiting period of 30 minutes observed.'),

    -- Booking 4: Completed — Workshop at CLS-202
    (4,  '2026-06-17 09:10:00', 3, 'Clean. Whiteboard clean. 35 chairs set up.',
         '2026-06-17 11:55:00', 'Minor marks on whiteboard. Chairs in order.', 'Workshop completed successfully.'),

    -- Booking 6: Completed — Student Activity at LAB-201
    (6,  '2026-06-18 10:05:00', 1, 'Project lab clean. Equipment checked.',
         '2026-06-18 12:55:00', 'Some components left on desks. General cleanup needed.', 'Students were working on hardware projects. Advised to clean up next time.'),

    -- Booking 10: Completed — Lecture at CLS-301
    (10, '2026-06-10 08:00:00', 3, 'Room clean. Projector and computer working.',
         '2026-06-10 10:00:00', 'Room clean. Good condition.', 'No issues.'),

    -- Booking 12: Completed — Workshop at AUD-101
    (12, '2026-06-12 14:10:00', 1, 'Auditorium prepared. Microphone and projector tested.',
         '2026-06-12 16:55:00', 'Minor trash found. Overall acceptable.', 'Workshop had 150 participants. All facilities worked well.');


-- ============================================================
-- 7. [MaintenanceRecord]
-- ============================================================
INSERT INTO [MaintenanceRecord] (SpaceCode, ReporterID, AssignedStaffID, ProblemDescription, StartTime, CompletionTime, Status, ResultNote)
VALUES
    -- LAB-103: Active maintenance - broken computers
    ('LAB-103', 4, 1, 'Three computer units in row C have malfunctioning power supplies. Network port 12 is also unresponsive.',
     '2026-06-01 08:00:00', NULL, 'InProgress', 'Replaced power supplies for 2 units. Awaiting one replacement part.'),

    -- LAB-103: Previous completed maintenance
    ('LAB-103', 5, 3, 'Air conditioning not cooling properly. Temperature reached 32°C.',
     '2026-05-15 09:00:00', '2026-05-18 16:00:00', 'Completed', 'AC filter cleaned and refrigerant refilled. Temperature now stable at 24°C.'),

    -- AUD-102: TemporarilyClosed - renovation
    ('AUD-102', 2, 3, 'Major renovation required: new seating, painting, and sound system upgrade.',
     '2026-05-20 07:00:00', NULL, 'InProgress', 'Seating removed. Painting in progress. Sound system components ordered.'),

    -- CLS-401: Retired - permanently decommissioned
    ('CLS-401', 2, NULL, 'Room structurally damaged due to ceiling water leak from floor above. Deemed unsafe for use.',
     '2026-04-01 10:00:00', '2026-04-15 14:00:00', 'Completed', 'Room decommissioned. No further repairs planned.'),

    -- CLS-301: Completed maintenance (minor)
    ('CLS-301', 7, 1, 'Projector lamp flickering during use.',
     '2026-06-02 15:00:00', '2026-06-03 10:00:00', 'Completed', 'Projector lamp replaced. Working normally.'),

    -- CLS-201: Reported issue
    ('CLS-201', 10, NULL, 'One desk has a broken leg. Student reported it wobbles.',
     '2026-06-19 08:30:00', NULL, 'Reported', NULL),

    -- AUD-101: Completed - microphone issue
    ('AUD-101', 4, 3, 'Wireless microphone intermittent connection loss during lecture.',
     '2026-06-16 09:00:00', '2026-06-17 11:00:00', 'Completed', 'Replaced batteries and adjusted receiver antenna. Tested successfully.');
```

---

## Sample Data Coverage Summary

### Normal Operations (Standard Workflow)

| Scenario | Booking ID | Description |
|----------|-----------|-------------|
| Request → Approve → Check-in → Complete | 1, 2, 4, 6, 10, 12 | Full lifecycle with approval, check-in, check-out, and completion |
| Request → Approve → (awaiting check-in) | 5, 17 | Approved bookings waiting for the scheduled date |
| Request → Pending | 7, 11, 13, 16 | Recently submitted bookings awaiting decision |
| Request → Cancelled | 9 | Requester cancelled before approval/check-in |
| Request → Completed (with maintenance) | 10 | Space CLS-301 had a past completed maintenance record |

### Exceptional Cases

| Scenario | Booking ID | Description |
|----------|-----------|-------------|
| No-show | 3 | Requester checked in but never arrived; staff recorded no-show |
| Rejected (policy violation) | 8 | Student Hub cannot be exclusively reserved for a full day |
| Rejected (space under maintenance) | 14 | Attempted to book LAB-103 which has active maintenance |
| Rejected (space temporarily closed) | 15 | Attempted to book AUD-102 which is closed for renovation |
| Active maintenance blocking booking | (LAB-103, AUD-102) | Spaces with `UnderMaintenance` or `TemporarilyClosed` status cannot be booked |
| Retired space | CLS-401 | Space marked as `Retired` with completed maintenance record |
| Suspended user booking | (none — La Van Son is suspended) | Edge case: suspended user should be prevented from booking |
| Inactive user | Quach Thi Quynh | Inactive account — should not be able to log in |
| Maintenance — Reported (unassigned) | CLS-201 | Broken desk reported, not yet assigned to any staff |
| Maintenance — InProgress | LAB-103 | Active maintenance with assigned staff |
| Maintenance — Completed | CLS-301, LAB-103 (old), AUD-101 | Historical maintenance records with resolution notes |

### Data Integrity Scenarios Covered

| Integrity Rule | How It Is Tested |
|----------------|------------------|
| Overlapping booking prevention | Two bookings on CLS-201: Booking 2 (08:00–10:00) ✅ Completed; Booking 9 (13:00–16:00) ✅ Cancelled — no overlap. Future test: attempt overlap on MTG-101 via trigger |
| Unavailable space restriction | Bookings 14 (LAB-103 under maintenance) and 15 (AUD-102 closed) were rejected |
| FK referential integrity | All foreign keys reference existing UserID, SpaceCode, BookingID values |
| CHECK constraints | All enum values (Role, Status, SpaceType, etc.) use valid CHECK constraint values |
| 1:1 Approval-Booking | Each approved/rejected booking has exactly one approval record |
| 1:1 UsageSession-Booking | Completed/NoShow bookings have exactly one usage session |
| Historical preservation | All records are INSERT-only; no data is deleted |
