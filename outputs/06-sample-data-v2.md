# 06 — Sample Data (Revised & Optimized)

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

## 5. Booking Requests & Vòng đời Đơn hàng (Sử dụng Khóa Động & ISO 8601)

Để khắc phục rủi ro lệch seed `IDENTITY` từ Stage 1, toàn bộ phần nạp dữ liệu dưới đây sử dụng biến bảng để bắt ID tự động, đồng thời chuẩn hóa mốc thời gian động theo ngày chạy thực tế (`GETDATE()`) giúp các truy vấn thống kê của Step 7 không bị trống lịch sử theo thời gian.

```sql
-- Khai báo biến bảng lưu vết ID động
DECLARE @BookingIDs TABLE (
    ListIndex INT,
    BookingID INT
);

DECLARE @B1 INT, @B2 INT, @B3 INT, @B4 INT, @B5 INT, @B6 INT, @B7 INT, @B8 INT;

-- (1) Đơn số 1: Hoàn thành (Quá khứ 5 ngày trước)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (8, 'CS-201', 
        DATEADD(hour, 9, CAST(DATEADD(day, -5, GETDATE()) AS DATETIME2)), 
        DATEADD(hour, 11, CAST(DATEADD(day, -5, GETDATE()) AS DATETIME2)), 
        'StudentActivity', 20, 'Completed');
SET @B1 = SCOPE_IDENTITY();

-- (2) Đơn số 2: Đang diễn ra ngay tại thời điểm hiện tại (CheckedIn)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (4, 'CS-101', 
        DATEADD(hour, -1, GETDATE()), 
        DATEADD(hour, 2, GETDATE()), 
        'Lecture', 35, 'CheckedIn');
SET @B2 = SCOPE_IDENTITY();

-- (3) Đơn số 3: Đang chờ duyệt (Tương lai ngày mai)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (8, 'WRK-02', 
        DATEADD(hour, 14, CAST(DATEADD(day, 1, GETDATE()) AS DATETIME2)), 
        DATEADD(hour, 17, CAST(DATEADD(day, 1, GETDATE()) AS DATETIME2)), 
        'StudentActivity', 5, 'Pending');
SET @B3 = SCOPE_IDENTITY();

-- (4) Đơn số 4: Đã duyệt, chờ Check-In (Tương lai gần trong ngày)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (6, 'CS-301', 
        DATEADD(hour, 3, GETDATE()), 
        DATEADD(hour, 5, GETDATE()), 
        'Meeting', 8, 'Approved');
SET @B4 = SCOPE_IDENTITY();

-- (5) Đơn số 5: Hoàn thành một hội thảo lớn (Quá khứ 3 ngày trước)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (4, 'AUDI-A', 
        DATEADD(hour, 10, CAST(DATEADD(day, -3, GETDATE()) AS DATETIME2)), 
        DATEADD(hour, 13, CAST(DATEADD(day, -3, GETDATE()) AS DATETIME2)), 
        'Seminar', 150, 'Completed');
SET @B5 = SCOPE_IDENTITY();

-- (6) Đơn số 6: Bị từ chối do vượt quá Capacity (Quá khứ)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (9, 'CS-101', 
        DATEADD(hour, 9, CAST(DATEADD(day, -2, GETDATE()) AS DATETIME2)), 
        DATEADD(hour, 11, CAST(DATEADD(day, -2, GETDATE()) AS DATETIME2)), 
        'StudentActivity', 50, 'Rejected');
SET @B6 = SCOPE_IDENTITY();

-- (7) Đơn số 7: Được duyệt nhưng sau đó bị hủy (Cancelled)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (7, 'CS-301', 
        DATEADD(hour, 10, CAST(DATEADD(day, -4, GETDATE()) AS DATETIME2)), 
        DATEADD(hour, 12, CAST(DATEADD(day, -4, GETDATE()) AS DATETIME2)), 
        'AdministrativeEvent', 5, 'Cancelled');
SET @B7 = SCOPE_IDENTITY();

-- (8) Đơn số 8: Bị đánh dấu vắng mặt (NoShow)
INSERT INTO BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
VALUES (8, 'CS-101', 
        DATEADD(hour, -6, GETDATE()), 
        DATEADD(hour, -4, GETDATE()), 
        'StudentActivity', 10, 'NoShow');
SET @B8 = SCOPE_IDENTITY();
GO
```

---

## 6. Approvals (Sử dụng tham chiếu biến động)

```sql
-- Giả định chạy lệnh tiếp nối khối trên, sử dụng các biến @B1..@B8 đã bắt phát sinh
INSERT INTO Approval (BookingID, ApproverID, DecisionTime, DecisionNote, RejectionReason)
VALUES
(@B1, 2, DATEADD(hour, -1, DATEADD(day, -5, GETDATE())), 'Approved for student lab session.', NULL),
(@B2, 1, DATEADD(hour, -2, DATEADD(day, 0, GETDATE())),  'Approved for lecture.', NULL),
(@B4, 2, DATEADD(hour, -1, GETDATE()),                  'Approved for TA meeting.', NULL),
(@B5, 1, DATEADD(hour, -5, DATEADD(day, -3, GETDATE())), 'Approved for seminar. Remind requester to arrive early.', NULL),
(@B6, 2, DATEADD(hour, -6, DATEADD(day, -2, GETDATE())), 'Rejected due to capacity constraints.', 'Capacity exceeds room limit (max 40, requested 50).'),
(@B7, 2, DATEADD(hour, -12, DATEADD(day, -4, GETDATE())), 'Approved for administrative meeting.', NULL),
(@B8, 2, DATEADD(hour, -7, GETDATE()),                  'Approved — student activity.', NULL);
GO
```

---

## 7. Usage Sessions (Check-in / Check-out)

```sql
INSERT INTO UsageSession (BookingID, ActualStartTime, CheckInStaffID, InitialCondition, ActualEndTime, FinalCondition, UsageNotes)
VALUES
-- Booking 1: Đã hoàn tất hoàn toàn sạch sẽ
(@B1, 
 DATEADD(minute, 5, DATEADD(hour, 9, CAST(DATEADD(day, -5, GETDATE()) AS DATETIME2))), 
 2, 'All computers functional, room clean.',
 DATEADD(minute, 10, DATEADD(hour, 11, CAST(DATEADD(day, -5, GETDATE()) AS DATETIME2))), 
 'All OK. One keyboard missing a keycap.', 
 'Session completed on time. Students were working on database project.'),

-- Booking 2: Phiên làm việc đang active tại thời điểm hiện tại (ActualEndTime là NULL)
(@B2, 
 DATEADD(minute, -5, DATEADD(hour, -1, GETDATE())), 
 2, 'Room tidy. Projector and whiteboard ready.',
 NULL, NULL, NULL),

-- Booking 5: Hội thảo lớn đã hoàn tất thành công trong quá khứ
(@B5, 
 DATEADD(minute, -5, DATEADD(hour, 10, CAST(DATEADD(day, -3, GETDATE()) AS DATETIME2))), 
 7, 'Auditorium clean. All microphones working. Livestream equipment set up.',
 DATEADD(minute, 5, DATEADD(hour, 13, CAST(DATEADD(day, -3, GETDATE()) AS DATETIME2))), 
 'Auditorium in good condition. No issues reported.', 'Seminar on AI ethics ran smoothly. 150 attendees.');
GO
```

---

## 8. Maintenance Records

```sql
INSERT INTO MaintenanceRecord (SpaceCode, ReporterID, AssignedStaffID, ProblemDescription, StartTime, CompletionTime, Status, ResultNote)
VALUES
-- Resolved: Đã xử lý xong xuôi điều hòa cho WRK-01
('WRK-01', 8, 2, 'Air conditioner not cooling. Room temperature reaching 32°C.',
    DATEADD(day, -10, GETDATE()), DATEADD(day, -8, GETDATE()), 'Resolved', 'Replaced coolant. AC working normally.'),
-- In progress: Lỗi mạng tại WRK-01 chưa giải quyết dứt điểm
('WRK-01', 6, 7, 'Network port by window not providing connectivity.',
    DATEADD(day, -2, GETDATE()), NULL, 'InProgress', 'Waiting for network infrastructure team.'),
-- Open: Lỗi bóng đèn máy chiếu giảng đường chưa bàn giao staff
('AUDI-A', 4, 2, 'Projector displaying dim, yellowish image. Bulb may need replacement.',
    DATEADD(day, -1, GETDATE()), NULL, 'Open', NULL),
-- Open, unassigned: Hỏng phím cơ hàng ghế C tại CS-201
('CS-201', 8, NULL, 'Several keyboards in Row C have sticky or unresponsive keys.',
    DATEADD(hour, -12, GETDATE()), NULL, 'Open', NULL);
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
| **Overlap scenario (data only)** | Bookings 1 and 2 | BookingRequest |