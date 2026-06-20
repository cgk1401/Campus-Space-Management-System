# 07 — Query Design

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

## Query 3: Space Utilization by Type

| Field | Value |
|-------|-------|
| **Business Question** | What is the total booked time and average participants per space type over the last 30 days? |
| **Target User(s)** | Facility Manager, Department Administrator |
| **Explanation** | Helps management understand which types of spaces are most heavily used, supporting decisions about resource allocation, renovation priorities, or future building plans. |

```sql
SELECT
    s.SpaceType,
    COUNT(b.BookingID)                        AS TotalBookings,
    SUM(DATEDIFF(HOUR, b.StartTime, b.EndTime)) AS TotalHoursBooked,
    AVG(b.ExpectedParticipants)               AS AvgParticipants,
    COUNT(DISTINCT s.SpaceCode)               AS NumberOfSpaces,
    SUM(DATEDIFF(HOUR, b.StartTime, b.EndTime))
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

## Query 5: Spaces Without Recent Maintenance

| Field | Value |
|-------|-------|
| **Business Question** | Which available spaces have never had a maintenance record or have not had maintenance in the past 6 months? |
| **Target User(s)** | Facility Manager, Facility Staff |
| **Explanation** | Proactive maintenance prevents unexpected breakdowns. This query identifies spaces that may need a preventive inspection, helping the facility manager schedule check-ups before issues arise. |

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
GROUP BY s.SpaceCode, s.SpaceName, s.Building, s.Floor, s.SpaceType, s.CurrentStatus
HAVING MAX(m.CompletionTime) IS NULL
    OR MAX(m.CompletionTime) < DATEADD(MONTH, -6, GETDATE())
ORDER BY LastMaintenanceCompletion ASC;
```

---

## Query 6: Space Availability Check

| Field | Value |
|-------|-------|
| **Business Question** | Is a specific space (e.g., 'CS-101') available for booking on a given date and time range (e.g., 2026-06-10 09:00–11:00)? |
| **Target User(s)** | All users (Students, Lecturers, TAs, Staff) |
| **Explanation** | The most frequent operational query: users need to check whether a room is free before submitting a booking request. This query checks for overlapping approved/checked-in bookings and also verifies the space is not blocked by maintenance or closure. |

```sql
DECLARE @TargetSpace NVARCHAR(20) = 'CS-101';
DECLARE @CheckStart  DATETIME2    = '2026-06-10 09:00';
DECLARE @CheckEnd    DATETIME2    = '2026-06-10 11:00';

SELECT
    s.SpaceCode,
    s.SpaceName,
    s.Capacity,
    s.CurrentStatus,
    CASE
        WHEN s.CurrentStatus IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')
            THEN 'Unavailable — space status is ' + s.CurrentStatus
        WHEN EXISTS (
            SELECT 1 FROM BookingRequest b
            WHERE b.SpaceCode = s.SpaceCode
              AND b.Status IN ('Approved', 'CheckedIn')
              AND b.StartTime < @CheckEnd
              AND b.EndTime   > @CheckStart
        )
            THEN 'Unavailable — time slot conflicts with an existing booking'
        ELSE 'Available'
    END AS AvailabilityStatus,
    conflict.BookingID    AS ConflictingBookingID,
    conflict.StartTime    AS ConflictStart,
    conflict.EndTime      AS ConflictEnd,
    conflict.Purpose      AS ConflictPurpose
FROM Space s
LEFT JOIN BookingRequest conflict
    ON s.SpaceCode = conflict.SpaceCode
   AND conflict.Status IN ('Approved', 'CheckedIn')
   AND conflict.StartTime < @CheckEnd
   AND conflict.EndTime   > @CheckStart
WHERE s.SpaceCode = @TargetSpace;
```

---

## Query 7: Maintenance Workload by Staff

| Field | Value |
|-------|-------|
| **Business Question** | What is the current maintenance workload for each facility staff member (open and in-progress tasks)? |
| **Target User(s)** | Facility Manager |
| **Explanation** | Helps the facility manager balance workloads, identify overburdened staff, and reassign open/unassigned tickets before they are forgotten. |

```sql
SELECT
    assigned.UserID         AS StaffID,
    assigned.FullName       AS StaffName,
    assigned.Email          AS StaffEmail,
    COUNT(m.MaintenanceID)  AS ActiveTasks,
    SUM(CASE WHEN m.Status = 'Open'       THEN 1 ELSE 0 END) AS OpenTasks,
    SUM(CASE WHEN m.Status = 'InProgress' THEN 1 ELSE 0 END) AS InProgressTasks,
    STRING_AGG(s.SpaceCode + ' (' + LEFT(m.ProblemDescription, 40) + ')', '; ')
                            AS TaskSummary
FROM [User] assigned
JOIN MaintenanceRecord m ON assigned.UserID = m.AssignedStaffID
JOIN Space s             ON m.SpaceCode     = s.SpaceCode
WHERE assigned.[Role] IN ('FacilityStaff', 'FacilityManager')
  AND m.Status IN ('Open', 'InProgress')
GROUP BY assigned.UserID, assigned.FullName, assigned.Email
ORDER BY ActiveTasks DESC;
```
