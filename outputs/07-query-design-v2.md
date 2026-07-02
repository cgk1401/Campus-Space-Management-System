# 07 — Query Design (Revised & Optimized)

**DBMS:** Microsoft SQL Server (T-SQL)

---

## Query 1: Upcoming Approved Bookings

| Field | Value |
|-------|-------|
| **Business Question** | Which approved bookings are scheduled for today and tomorrow, and what spaces do they use? |
| **Target User(s)** | Facility Staff, Facility Manager |
| **Explanation** | Staff need a daily schedule to prepare spaces (unlock rooms, check equipment, set up facilities) before users arrive. This query gives a clean operational view for the next 48 hours. |

```sql
SELECT
    b.BookingID,
    u.FullName              AS Requester,
    u.Email                 AS RequesterEmail,
    u.Department,
    s.SpaceCode,
    s.SpaceName,
    s.Building,
    s.RoomNumber,
    b.StartTime,
    b.EndTime,
    b.Purpose,
    b.ExpectedParticipants
FROM BookingRequest b
JOIN [User] u ON b.RequesterID = u.UserID
JOIN Space s   ON b.SpaceCode   = s.SpaceCode
WHERE b.Status IN ('Approved', 'CheckedIn')
  AND b.StartTime >= CAST(GETDATE() AS DATE)
  AND b.StartTime <  DATEADD(DAY, 2, CAST(GETDATE() AS DATE))
ORDER BY b.StartTime;
```

---

## Query 2: Unavailable Spaces Summary

| Field | Value |
|-------|-------|
| **Business Question** | Which spaces are currently unavailable (under maintenance, temporarily closed, or retired), and what maintenance issues are active? |
| **Target User(s)** | Facility Staff, Facility Manager, Department Administrator |
| **Explanation** | A quick reference of all spaces that cannot be booked, along with active maintenance reasons. Helps staff answer "why is this room blocked?" without digging through multiple screens. |

```sql
SELECT
    s.SpaceCode,
    s.SpaceName,
    s.Building,
    s.Floor,
    s.CurrentStatus,
    m.MaintenanceID,
    m.ProblemDescription,
    m.Status               AS MaintenanceStatus,
    m.StartTime            AS MaintenanceStart,
    reporter.FullName      AS ReportedBy,
    assigned.FullName      AS AssignedTo
FROM Space s
LEFT JOIN MaintenanceRecord m
    ON s.SpaceCode = m.SpaceCode
   AND m.Status IN ('Open', 'InProgress')
LEFT JOIN [User] reporter ON m.ReporterID = reporter.UserID
LEFT JOIN [User] assigned ON m.AssignedStaffID = assigned.UserID
WHERE s.CurrentStatus IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')
ORDER BY s.SpaceCode, m.StartTime DESC;
```

---

## Query 3: Space Utilization by Type (High Precision Fix)

| Field | Value |
|-------|-------|
| **Business Question** | What is the total booked time (in precision hours) and average participants per space type over the last 30 days? |
| **Target User(s)** | Facility Manager, Department Administrator |
| **Explanation** | VÁ LỖI STAGE 1: Sử dụng tính toán mức MINUTE chia cho 60.0 để tránh lỗi làm tròn/đếm sai mốc giờ của hàm `DATEDIFF(HOUR)`. Giúp dữ liệu báo cáo đạt độ chính xác tuyệt đối ở dạng số thập phân. |

```sql
SELECT
    s.SpaceType,
    COUNT(b.BookingID)                        AS TotalBookings,
    -- SỬA ĐỔI: Chuyển sang phút rồi chia decimal để giữ độ chính xác fractional hours
    SUM(DATEDIFF(MINUTE, b.StartTime, b.EndTime)) / 60.0 AS TotalHoursBooked,
    AVG(b.ExpectedParticipants)               AS AvgParticipants,
    COUNT(DISTINCT s.SpaceCode)               AS NumberOfSpaces,
    (SUM(DATEDIFF(MINUTE, b.StartTime, b.EndTime)) / 60.0)
        / NULLIF(COUNT(DISTINCT s.SpaceCode), 0) AS AvgHoursPerSpace
FROM Space s
LEFT JOIN BookingRequest b
    ON s.SpaceCode = b.SpaceCode
   AND b.Status IN ('Approved', 'CheckedIn', 'Completed')
   AND b.StartTime >= DATEADD(DAY, -30, GETDATE())
GROUP BY s.SpaceType
ORDER BY TotalHoursBooked DESC;
```

---

## Query 4: No-Show Bookings

| Field | Value |
|-------|-------|
| **Business Question** | Which bookings resulted in no-shows over the past 30 days, and who made them? |
| **Target User(s)** | Facility Manager, Facility Staff |
| **Explanation** | No-shows waste space that could have been used by others. Identifying repeat offenders or patterns helps the facility manager decide whether to enforce penalties or adjust booking policies. |

```sql
SELECT
    b.BookingID,
    u.FullName              AS Requester,
    u.Email                 AS RequesterEmail,
    u.Department,
    s.SpaceCode,
    s.SpaceName,
    b.StartTime,
    b.EndTime,
    b.Purpose,
    b.ExpectedParticipants,
    a.DecisionTime          AS ApprovalTime,
    a.ApproverID
FROM BookingRequest b
JOIN [User] u        ON b.RequesterID = u.UserID
JOIN Space s         ON b.SpaceCode   = s.SpaceCode
LEFT JOIN Approval a ON b.BookingID   = a.BookingID
WHERE b.Status = 'NoShow'
  AND b.StartTime >= DATEADD(DAY, -30, GETDATE())
ORDER BY b.StartTime DESC;
```

---

## Query 5: Spaces Without Recent Maintenance (Active Incident Isolation)

| Field | Value |
|-------|-------|
| **Business Question** | Which available spaces have never had a maintenance record or have not had maintenance in the past 6 months? |
| **Target User(s)** | Facility Manager, Facility Staff |
| **Explanation** | VÁ LỖI STAGE 1: Tích hợp mệnh đề `NOT EXISTS` để cô lập, loại bỏ hoàn toàn các phòng đang có sự cố active chưa giải quyết (`Open` hoặc `InProgress`), đảm bảo danh sách gợi ý bảo trì phòng ngừa chỉ hiển thị các phòng thực sự sạch lỗi. |

```sql
SELECT
    s.SpaceCode,
    s.SpaceName,
    s.Building,
    s.Floor,
    s.SpaceType,
    s.CurrentStatus,
    MAX(m.CompletionTime)   AS LastMaintenanceCompletion,
    COUNT(m.MaintenanceID)  AS TotalMaintenanceRecords
FROM Space s
LEFT JOIN MaintenanceRecord m
    ON s.SpaceCode = m.SpaceCode
   AND m.Status = 'Resolved'
WHERE s.CurrentStatus = 'Available'
  -- SỬA ĐỔI: Chặn các không gian có lỗi active chưa xử lý xong xuôi
  AND NOT EXISTS (
      SELECT 1 
      FROM MaintenanceRecord active_m
      WHERE active_m.SpaceCode = s.SpaceCode
        AND active_m.Status IN ('Open', 'InProgress')
  )
GROUP BY s.SpaceCode, s.SpaceName, s.Building, s.Floor, s.SpaceType, s.CurrentStatus
HAVING MAX(m.CompletionTime) IS NULL
    OR MAX(m.CompletionTime) < DATEADD(MONTH, -6, GETDATE())
ORDER BY LastMaintenanceCompletion ASC;
```

---

## Query 6: Space Availability Check (Row Isolation Fix via OUTER APPLY)

| Field | Value |
|-------|-------|
| **Business Question** | Is a specific space (e.g., 'CS-101') available for booking on a given date and time range? |
| **Target User(s)** | All users (Students, Lecturers, TAs, Staff) |
| **Explanation** | VÁ LỖI STAGE 1: Chuyển đổi `LEFT JOIN` thô sơ thành cấu trúc `OUTER APPLY` cô lập bản ghi. Tránh hoàn toàn lỗi nhân bản dòng (Row Multiplication Violation) khi một phòng chức năng dính nhiều đơn trùng lịch trong cùng khung giờ khảo sát. |

```sql
DECLARE @TargetSpace NVARCHAR(20) = 'CS-101';
DECLARE @CheckStart  DATETIME2    = DATEADD(day, 1, GETDATE()); -- Demo tương lai ngày mai
DECLARE @CheckEnd    DATETIME2    = DATEADD(hour, 2, DATEADD(day, 1, GETDATE()));

SELECT
    s.SpaceCode,
    s.SpaceName,
    s.Capacity,
    s.CurrentStatus,
    CASE
        WHEN s.CurrentStatus IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')
            THEN 'Unavailable — space status is ' + s.CurrentStatus
        WHEN conflict.BookingID IS NOT NULL
            THEN 'Unavailable — time slot conflicts with an existing booking'
        ELSE 'Available'
    END AS AvailabilityStatus,
    conflict.BookingID    AS ConflictingBookingID,
    conflict.StartTime    AS ConflictStart,
    conflict.EndTime      AS ConflictEnd,
    conflict.Purpose      AS ConflictPurpose
FROM Space s
-- SỬA ĐỔI: Sử dụng OUTER APPLY kết hợp TOP 1 để cô lập chống nhân dòng dữ liệu
OUTER APPLY (
    SELECT TOP 1 b.BookingID, b.StartTime, b.EndTime, b.Purpose
    FROM BookingRequest b
    WHERE b.SpaceCode = s.SpaceCode
      AND b.Status IN ('Approved', 'CheckedIn')
      AND b.StartTime < @CheckEnd
      AND b.EndTime   > @CheckStart
) conflict
WHERE s.SpaceCode = @TargetSpace;
```

---

## Query 7: Maintenance Workload by Staff (Idle Staff Inclusion Fix)

| Field | Value |
|-------|-------|
| **Business Question** | What is the current maintenance workload for each facility staff member (open and in-progress tasks)? |
| **Target User(s)** | Facility Manager |
| **Explanation** | VÁ LỖI STAGE 1: Thay thế `INNER JOIN` bằng `LEFT JOIN` và chuyển điều kiện lọc trạng thái từ mệnh đề `WHERE` vào trực tiếp mệnh đề `ON`. Giúp giữ lại thông tin của các nhân sự đang "rảnh rỗi" (0 task) phục vụ phân bổ công việc công bằng. |

```sql
SELECT
    assigned.UserID         AS StaffID,
    assigned.FullName       AS StaffName,
    assigned.Email          AS StaffEmail,
    COUNT(m.MaintenanceID)  AS ActiveTasks,
    SUM(CASE WHEN m.Status = 'Open'       THEN 1 ELSE 0 END) AS OpenTasks,
    SUM(CASE WHEN m.Status = 'InProgress' THEN 1 ELSE 0 END) AS InProgressTasks,
    ISNULL(STRING_AGG(s.SpaceCode + ' (' + LEFT(m.ProblemDescription, 40) + ')', '; '), 'No active tasks')
                            AS TaskSummary
FROM [User] assigned
-- SỬA ĐỔI: Đổi sang LEFT JOIN để giữ lại nhân sự có 0 tasks
LEFT JOIN MaintenanceRecord m 
    ON assigned.UserID = m.AssignedStaffID
    -- SỬA ĐỔI: Chuyển điều kiện trạng thái sự cố lên ON của JOIN để không triệt tiêu dòng rỗng
    AND m.Status IN ('Open', 'InProgress')
LEFT JOIN Space s             
    ON m.SpaceCode     = s.SpaceCode
WHERE assigned.[Role] IN ('FacilityStaff', 'FacilityManager')
GROUP BY assigned.UserID, assigned.FullName, assigned.Email
ORDER BY ActiveTasks DESC;
```