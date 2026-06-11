# 07 — Query Design

## DBMS

Microsoft SQL Server

## Query Conventions

- All queries target the schema defined in `05-db-definition.md` and sample data in `06-sample-data.md`.
- Date literal format: `'YYYY-MM-DD HH:MM:SS'` (MS SQL Server compatible).
- Column aliases use `AS` for readability.

---

## Query 1: Pending Bookings Requiring Approval

**Business question:** Which booking requests are currently pending and waiting for a decision?

**Target user(s):** Facility Staff, Facility Manager

**Explanation:** Allows staff to see all new booking requests that need approval, ordered by urgency (earliest start first).

```sql
SELECT
    BR.BookingID,
    U.FullName  AS RequesterName,
    U.Role      AS RequesterRole,
    S.SpaceName,
    S.SpaceCode,
    BR.RequestedStartTime,
    BR.RequestedEndTime,
    BR.PurposeOfUse,
    BR.ExpectedParticipants
FROM [BookingRequest] BR
INNER JOIN [User] U  ON BR.RequesterID = U.UserID
INNER JOIN [Space] S ON BR.SpaceCode   = S.SpaceCode
WHERE BR.Status = 'Pending'
ORDER BY BR.RequestedStartTime ASC;
```

---

## Query 2: Upcoming Approved Bookings for a Specific Space

**Business question:** What approved bookings are scheduled for Auditorium A1 (AUD-101) in the future?

**Target user(s):** Facility Staff, Facility Manager, Department Administrator

**Explanation:** Helps staff prepare the space and avoid double-booking by reviewing which approved sessions are coming up.

```sql
SELECT
    BR.BookingID,
    U.FullName  AS RequesterName,
    BR.RequestedStartTime,
    BR.RequestedEndTime,
    BR.PurposeOfUse,
    BR.ExpectedParticipants
FROM [BookingRequest] BR
INNER JOIN [User] U ON BR.RequesterID = U.UserID
WHERE BR.SpaceCode     = 'AUD-101'
  AND BR.Status        = 'Approved'
  AND BR.RequestedStartTime > GETDATE()
ORDER BY BR.RequestedStartTime ASC;
```

---

## Query 3: Detect Potential Overlapping Bookings

**Business question:** Are there any approved bookings that overlap on the same space?

**Target user(s):** Facility Manager, Facility Staff

**Explanation:** Detects data integrity violations where overlapping bookings may exist (should be prevented by trigger, but useful for auditing).

```sql
SELECT
    BR1.BookingID      AS BookingID_1,
    BR2.BookingID      AS BookingID_2,
    BR1.SpaceCode,
    S.SpaceName,
    BR1.RequestedStartTime AS Start_1,
    BR1.RequestedEndTime   AS End_1,
    BR2.RequestedStartTime AS Start_2,
    BR2.RequestedEndTime   AS End_2,
    U1.FullName AS Requester_1,
    U2.FullName AS Requester_2
FROM [BookingRequest] BR1
INNER JOIN [BookingRequest] BR2
    ON BR1.SpaceCode = BR2.SpaceCode
    AND BR1.BookingID < BR2.BookingID
    AND BR1.RequestedStartTime < BR2.RequestedEndTime
    AND BR2.RequestedStartTime < BR1.RequestedEndTime
INNER JOIN [Space] S  ON BR1.SpaceCode = S.SpaceCode
INNER JOIN [User]  U1 ON BR1.RequesterID = U1.UserID
INNER JOIN [User]  U2 ON BR2.RequesterID = U2.UserID
WHERE BR1.Status IN ('Approved', 'CheckedIn', 'Completed')
  AND BR2.Status IN ('Approved', 'CheckedIn', 'Completed');
```

---

## Query 4: Booking History for a Specific Space

**Business question:** What is the complete booking history for Computer Lab B1 (LAB-101)?

**Target user(s):** Facility Manager, Facility Staff

**Explanation:** Provides a full audit trail of who used the space, when, and for what purpose.

```sql
SELECT
    BR.BookingID,
    U.FullName  AS RequesterName,
    U.Role      AS RequesterRole,
    BR.RequestedStartTime,
    BR.RequestedEndTime,
    BR.PurposeOfUse,
    BR.ExpectedParticipants,
    BR.Status
FROM [BookingRequest] BR
INNER JOIN [User] U ON BR.RequesterID = U.UserID
WHERE BR.SpaceCode = 'LAB-101'
ORDER BY BR.RequestedStartTime DESC;
```

---

## Query 5: Booking History for a Specific User

**Business question:** What bookings has student Ly Van Khanh (UserID 9) submitted?

**Target user(s):** Facility Staff, Department Administrator

**Explanation:** Useful for reviewing a user's booking activity, identifying patterns (e.g., frequent cancellations or no-shows).

```sql
SELECT
    BR.BookingID,
    S.SpaceName,
    S.SpaceCode,
    BR.RequestedStartTime,
    BR.RequestedEndTime,
    BR.PurposeOfUse,
    BR.Status
FROM [BookingRequest] BR
INNER JOIN [Space] S ON BR.SpaceCode = S.SpaceCode
WHERE BR.RequesterID = 9
ORDER BY BR.RequestedStartTime DESC;
```

---

## Query 6: List No-Show Bookings

**Business question:** Which bookings resulted in a no-show (requester did not arrive)?

**Target user(s):** Facility Manager, Facility Staff

**Explanation:** Helps identify users who habitually fail to show up, enabling the facility manager to take corrective action (e.g., warnings or booking restrictions).

```sql
SELECT
    BR.BookingID,
    U.FullName  AS RequesterName,
    U.Email     AS RequesterEmail,
    U.Role      AS RequesterRole,
    S.SpaceName,
    S.SpaceCode,
    BR.RequestedStartTime,
    BR.RequestedEndTime,
    BR.PurposeOfUse,
    US.CheckInStaffID,
    US.InitialCondition
FROM [BookingRequest] BR
INNER JOIN [User]         U  ON BR.RequesterID = U.UserID
INNER JOIN [Space]        S  ON BR.SpaceCode   = S.SpaceCode
INNER JOIN [UsageSession] US ON BR.BookingID   = US.BookingID
WHERE BR.Status = 'NoShow'
ORDER BY BR.RequestedStartTime DESC;
```

---

## Query 7: Currently Checked-In Sessions

**Business question:** Which bookings are currently checked in and still in progress?

**Target user(s):** Facility Staff, Facility Manager

**Explanation:** Gives staff a real-time view of which spaces are occupied right now.

```sql
SELECT
    BR.BookingID,
    U.FullName      AS RequesterName,
    S.SpaceName,
    S.SpaceCode,
    BR.RequestedStartTime,
    BR.RequestedEndTime,
    US.ActualStartTime,
    US.CheckInStaffID,
    US.InitialCondition
FROM [BookingRequest] BR
INNER JOIN [User]         U  ON BR.RequesterID      = U.UserID
INNER JOIN [Space]        S  ON BR.SpaceCode        = S.SpaceCode
INNER JOIN [UsageSession] US ON BR.BookingID        = US.BookingID
WHERE BR.Status       = 'CheckedIn'
  AND US.ActualEndTime IS NULL
ORDER BY US.ActualStartTime ASC;
```

---

## Query 8: Active Maintenance Records

**Business question:** What maintenance issues are currently active (reported or in progress)?

**Target user(s):** Facility Manager, Facility Staff

**Explanation:** Provides a dashboard of all unresolved maintenance tasks so staff can prioritize repairs.

```sql
SELECT
    MR.MaintenanceID,
    S.SpaceName,
    S.SpaceCode,
    S.Building,
    S.Floor,
    S.RoomNumber,
    Reporter.FullName  AS ReportedBy,
    Assigned.FullName  AS AssignedTo,
    MR.ProblemDescription,
    MR.StartTime,
    MR.Status,
    MR.ResultNote
FROM [MaintenanceRecord] MR
INNER JOIN [Space] S        ON MR.SpaceCode      = S.SpaceCode
INNER JOIN [User]  Reporter ON MR.ReporterID     = Reporter.UserID
LEFT  JOIN [User]  Assigned ON MR.AssignedStaffID = Assigned.UserID
WHERE MR.Status IN ('Reported', 'InProgress')
ORDER BY MR.StartTime ASC;
```

---

## Query 9: Maintenance History for a Specific Space

**Business question:** What is the complete maintenance history for Computer Lab B3 (LAB-103)?

**Target user(s):** Facility Manager, Facility Staff

**Explanation:** Enables staff to review past issues and repairs for a space, helping identify recurring problems.

```sql
SELECT
    MR.MaintenanceID,
    Reporter.FullName AS ReportedBy,
    Assigned.FullName AS AssignedTo,
    MR.ProblemDescription,
    MR.StartTime,
    MR.CompletionTime,
    MR.Status,
    MR.ResultNote
FROM [MaintenanceRecord] MR
LEFT  JOIN [User] Reporter ON MR.ReporterID      = Reporter.UserID
LEFT  JOIN [User] Assigned ON MR.AssignedStaffID  = Assigned.UserID
WHERE MR.SpaceCode = 'LAB-103'
ORDER BY MR.StartTime DESC;
```

---

## Query 10: Unassigned Maintenance Records

**Business question:** Which maintenance issues have been reported but not yet assigned to any staff member?

**Target user(s):** Facility Manager

**Explanation:** Helps the facility manager quickly find unassigned tasks and delegate them to available staff.

```sql
SELECT
    MR.MaintenanceID,
    S.SpaceName,
    S.SpaceCode,
    Reporter.FullName AS ReportedBy,
    MR.ProblemDescription,
    MR.StartTime,
    MR.Status
FROM [MaintenanceRecord] MR
INNER JOIN [Space] S        ON MR.SpaceCode   = S.SpaceCode
INNER JOIN [User]  Reporter ON MR.ReporterID  = Reporter.UserID
WHERE MR.AssignedStaffID IS NULL
  AND MR.Status IN ('Reported', 'InProgress')
ORDER BY MR.StartTime ASC;
```

---

## Query 11: Spaces with the Most Maintenance Issues

**Business question:** Which spaces have the highest number of reported maintenance issues?

**Target user(s):** Facility Manager

**Explanation:** Identifies problem-prone spaces that may need renovation or more frequent inspections.

```sql
SELECT
    S.SpaceCode,
    S.SpaceName,
    S.Building,
    S.Floor,
    S.RoomNumber,
    COUNT(MR.MaintenanceID) AS TotalMaintenanceRecords,
    SUM(CASE WHEN MR.Status IN ('Reported', 'InProgress') THEN 1 ELSE 0 END) AS ActiveIssues
FROM [Space] S
LEFT JOIN [MaintenanceRecord] MR ON S.SpaceCode = MR.SpaceCode
GROUP BY S.SpaceCode, S.SpaceName, S.Building, S.Floor, S.RoomNumber
ORDER BY TotalMaintenanceRecords DESC;
```

---

## Query 12: Available Spaces for a Given Time Range

**Business question:** Which spaces are available on 2026-06-20 between 08:00 and 10:00?

**Target user(s):** All users (students, lecturers, staff submitting bookings)

**Explanation:** Allows any user to find spaces that are free during a desired time slot, excluding spaces that are unavailable or have overlapping approved bookings.

```sql
SELECT
    S.SpaceCode,
    S.SpaceName,
    S.SpaceType,
    S.Building,
    S.Floor,
    S.RoomNumber,
    S.Capacity,
    S.UsagePolicy
FROM [Space] S
WHERE S.CurrentStatus = 'Available'
  AND S.SpaceCode NOT IN (
      SELECT BR.SpaceCode
      FROM [BookingRequest] BR
      WHERE BR.Status IN ('Approved', 'CheckedIn')
        AND BR.RequestedStartTime < '2026-06-20 10:00:00'
        AND BR.RequestedEndTime   > '2026-06-20 08:00:00'
  )
  AND S.SpaceCode NOT IN (
      SELECT MR.SpaceCode
      FROM [MaintenanceRecord] MR
      WHERE MR.Status IN ('Reported', 'InProgress')
  )
ORDER BY S.SpaceType, S.Capacity DESC;
```

---

## Query 13: Spaces with Specific Equipment (Projector + Computer)

**Business question:** Which spaces have both a projector and a computer?

**Target user(s):** Lecturers, Teaching Assistants, Students

**Explanation:** Helps users find spaces equipped with the technology they need for teaching or presentations.

```sql
SELECT
    S.SpaceCode,
    S.SpaceName,
    S.SpaceType,
    S.Building,
    S.RoomNumber,
    S.Capacity,
    S.CurrentStatus
FROM [Space] S
WHERE EXISTS (
    SELECT 1 FROM [Facility] F
    WHERE F.SpaceCode = S.SpaceCode AND F.FacilityName = 'Projector'
)
AND EXISTS (
    SELECT 1 FROM [Facility] F
    WHERE F.SpaceCode = S.SpaceCode AND F.FacilityName = 'Computer'
)
ORDER BY S.SpaceType, S.Capacity DESC;
```

---

## Query 14: Space Utilization Rate

**Business question:** What percentage of time was each space used over a given period (e.g., June 2026)?

**Target user(s):** Facility Manager, Department Administrator

**Explanation:** Measures how efficiently each space is being utilized, helping management make decisions about space allocation.

```sql
WITH SpaceTotalHours AS (
    SELECT
        S.SpaceCode,
        S.SpaceName,
        S.SpaceType,
        S.Capacity
    FROM [Space] S
),
BookingHours AS (
    SELECT
        BR.SpaceCode,
        SUM(DATEDIFF(HOUR, BR.RequestedStartTime, BR.RequestedEndTime)) AS BookedHours
    FROM [BookingRequest] BR
    WHERE BR.Status IN ('Completed', 'CheckedIn', 'Approved', 'NoShow')
      AND BR.RequestedStartTime >= '2026-06-01'
      AND BR.RequestedEndTime   <= '2026-06-30'
    GROUP BY BR.SpaceCode
)
SELECT
    ST.SpaceCode,
    ST.SpaceName,
    ST.SpaceType,
    ST.Capacity,
    ISNULL(BH.BookedHours, 0) AS BookedHours,
    ROUND(100.0 * ISNULL(BH.BookedHours, 0) / (30 * 12), 2) AS UtilizationPercent
    -- Assumes 12 available hours per day × 30 days
FROM SpaceTotalHours ST
LEFT JOIN BookingHours BH ON ST.SpaceCode = BH.SpaceCode
ORDER BY UtilizationPercent DESC;
```

---

## Query 15: Spaces with Capacity Above a Threshold

**Business question:** Which spaces can accommodate 50 or more participants?

**Target user(s):** Lecturers, Event Organizers, Facility Staff

**Explanation:** Quickly find large-capacity spaces for lectures, seminars, or workshops.

```sql
SELECT
    S.SpaceCode,
    S.SpaceName,
    S.SpaceType,
    S.Building,
    S.Floor,
    S.RoomNumber,
    S.Capacity,
    S.CurrentStatus,
    S.UsagePolicy
FROM [Space] S
WHERE S.Capacity >= 50
ORDER BY S.Capacity DESC;
```

---

## Query 16: Approval Activity by Staff Member

**Business question:** How many bookings has each facility staff member approved or rejected?

**Target user(s):** Facility Manager

**Explanation:** Tracks staff workload and decision-making activity for performance evaluation.

```sql
SELECT
    U.UserID,
    U.FullName AS StaffName,
    U.Role,
    COUNT(A.ApprovalID) AS TotalDecisions,
    SUM(CASE WHEN BR.Status = 'Approved' THEN 1 ELSE 0 END) AS ApprovedCount,
    SUM(CASE WHEN BR.Status = 'Rejected' THEN 1 ELSE 0 END) AS RejectedCount
FROM [User] U
INNER JOIN [Approval]       A  ON U.UserID      = A.ApproverID
INNER JOIN [BookingRequest] BR ON A.BookingID   = BR.BookingID
WHERE U.Role IN ('FacilityStaff', 'FacilityManager')
GROUP BY U.UserID, U.FullName, U.Role
ORDER BY TotalDecisions DESC;
```

---

## Query 17: Users with the Most Bookings

**Business question:** Which users submit the most booking requests?

**Target user(s):** Facility Manager, Department Administrator

**Explanation:** Identifies the most active users for planning and communication purposes.

```sql
SELECT
    U.UserID,
    U.FullName,
    U.Role,
    U.Department,
    COUNT(BR.BookingID) AS TotalBookings,
    SUM(CASE WHEN BR.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedBookings,
    SUM(CASE WHEN BR.Status = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledBookings,
    SUM(CASE WHEN BR.Status = 'NoShow'   THEN 1 ELSE 0 END) AS NoShowBookings
FROM [User] U
LEFT JOIN [BookingRequest] BR ON U.UserID = BR.RequesterID
GROUP BY U.UserID, U.FullName, U.Role, U.Department
ORDER BY TotalBookings DESC;
```

---

## Query 18: Rejected Bookings with Reasons

**Business question:** What booking requests were rejected, and why?

**Target user(s):** Facility Staff, Facility Manager

**Explanation:** Provides a clear audit trail of all rejections, including the reason and who made the decision.

```sql
SELECT
    BR.BookingID,
    Requester.FullName AS RequesterName,
    S.SpaceName,
    S.SpaceCode,
    BR.RequestedStartTime,
    BR.RequestedEndTime,
    BR.PurposeOfUse,
    Approver.FullName  AS ApprovedBy,
    A.DecisionTime,
    A.RejectionReason
FROM [BookingRequest] BR
INNER JOIN [Approval] A  ON BR.BookingID   = A.BookingID
INNER JOIN [User] Requester ON BR.RequesterID = Requester.UserID
INNER JOIN [User] Approver  ON A.ApproverID   = Approver.UserID
INNER JOIN [Space] S  ON BR.SpaceCode    = S.SpaceCode
WHERE BR.Status = 'Rejected'
ORDER BY A.DecisionTime DESC;
```

---

## Query 19: Booking Count by Purpose

**Business question:** How are bookings distributed across different purposes (lecture, seminar, meeting, etc.)?

**Target user(s):** Facility Manager, Department Administrator

**Explanation:** Helps the school understand how spaces are being used and plan for future resource allocation.

```sql
SELECT
    BR.PurposeOfUse,
    COUNT(BR.BookingID) AS TotalBookings,
    COUNT(CASE WHEN BR.Status = 'Completed' THEN 1 END) AS CompletedCount,
    COUNT(CASE WHEN BR.Status = 'Approved'  THEN 1 END) AS UpcomingCount,
    COUNT(CASE WHEN BR.Status = 'Rejected'  THEN 1 END) AS RejectedCount,
    COUNT(CASE WHEN BR.Status = 'Cancelled' THEN 1 END) AS CancelledCount,
    ROUND(100.0 * COUNT(BR.BookingID) / SUM(COUNT(BR.BookingID)) OVER (), 2) AS Percentage
FROM [BookingRequest] BR
GROUP BY BR.PurposeOfUse
ORDER BY TotalBookings DESC;
```

---

## Query 20: Spaces That Have Never Been Booked

**Business question:** Which spaces have zero booking requests ever?

**Target user(s):** Facility Manager

**Explanation:** Identifies underutilized spaces that may need promotion, repurposing, or policy changes.

```sql
SELECT
    S.SpaceCode,
    S.SpaceName,
    S.SpaceType,
    S.Building,
    S.Floor,
    S.RoomNumber,
    S.Capacity,
    S.CurrentStatus
FROM [Space] S
WHERE NOT EXISTS (
    SELECT 1 FROM [BookingRequest] BR
    WHERE BR.SpaceCode = S.SpaceCode
)
ORDER BY S.SpaceType, S.SpaceCode;
```

---

## Query 21: Monthly Booking Summary

**Business question:** How many bookings were made each month, broken down by status?

**Target user(s):** Facility Manager, Department Administrator

**Explanation:** Provides a monthly trend report to analyze booking volume and seasonal patterns.

```sql
SELECT
    YEAR(BR.RequestedStartTime)  AS Year,
    MONTH(BR.RequestedStartTime) AS Month,
    COUNT(BR.BookingID) AS TotalBookings,
    SUM(CASE WHEN BR.Status = 'Completed' THEN 1 ELSE 0 END) AS Completed,
    SUM(CASE WHEN BR.Status = 'Approved'  THEN 1 ELSE 0 END) AS Approved,
    SUM(CASE WHEN BR.Status = 'Pending'   THEN 1 ELSE 0 END) AS Pending,
    SUM(CASE WHEN BR.Status = 'Rejected'  THEN 1 ELSE 0 END) AS Rejected,
    SUM(CASE WHEN BR.Status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
    SUM(CASE WHEN BR.Status = 'NoShow'   THEN 1 ELSE 0 END) AS NoShow
FROM [BookingRequest] BR
GROUP BY YEAR(BR.RequestedStartTime), MONTH(BR.RequestedStartTime)
ORDER BY Year DESC, Month DESC;
```

---

## Query 22: Average Booking Duration by Space Type

**Business question:** What is the average booking duration for each type of space?

**Target user(s):** Facility Manager

**Explanation:** Helps set appropriate booking policies and limits based on actual usage patterns.

```sql
SELECT
    S.SpaceType,
    COUNT(BR.BookingID) AS TotalBookings,
    AVG(DATEDIFF(MINUTE, BR.RequestedStartTime, BR.RequestedEndTime)) AS AvgDurationMinutes,
    MIN(DATEDIFF(MINUTE, BR.RequestedStartTime, BR.RequestedEndTime)) AS MinDurationMinutes,
    MAX(DATEDIFF(MINUTE, BR.RequestedStartTime, BR.RequestedEndTime)) AS MaxDurationMinutes
FROM [BookingRequest] BR
INNER JOIN [Space] S ON BR.SpaceCode = S.SpaceCode
WHERE BR.Status IN ('Completed', 'Approved', 'CheckedIn', 'NoShow')
GROUP BY S.SpaceType
ORDER BY AvgDurationMinutes DESC;
```

---

## Query 23: Facilities Count Grouped by Space

**Business question:** How many facilities (projector, whiteboard, etc.) does each space have?

**Target user(s):** Facility Staff, Facility Manager

**Explanation:** Quick inventory overview — which spaces are best equipped.

```sql
SELECT
    S.SpaceCode,
    S.SpaceName,
    S.SpaceType,
    S.Building,
    S.RoomNumber,
    COUNT(F.FacilityID) AS FacilityCount,
    STRING_AGG(F.FacilityName, ', ') AS FacilityList
FROM [Space] S
LEFT JOIN [Facility] F ON S.SpaceCode = F.SpaceCode
GROUP BY S.SpaceCode, S.SpaceName, S.SpaceType, S.Building, S.RoomNumber
ORDER BY FacilityCount DESC, S.SpaceCode;
```

---

## Query 24: Maintenance Completion Time Analysis

**Business question:** What is the average time taken to complete maintenance tasks?

**Target user(s):** Facility Manager

**Explanation:** Measures maintenance efficiency and helps identify bottlenecks.

```sql
SELECT
    MR.Status,
    COUNT(MR.MaintenanceID) AS TotalRecords,
    AVG(CASE
        WHEN MR.CompletionTime IS NOT NULL
        THEN DATEDIFF(HOUR, MR.StartTime, MR.CompletionTime)
        ELSE NULL
    END) AS AvgCompletionHours,
    MIN(CASE
        WHEN MR.CompletionTime IS NOT NULL
        THEN DATEDIFF(HOUR, MR.StartTime, MR.CompletionTime)
        ELSE NULL
    END) AS MinCompletionHours,
    MAX(CASE
        WHEN MR.CompletionTime IS NOT NULL
        THEN DATEDIFF(HOUR, MR.StartTime, MR.CompletionTime)
        ELSE NULL
    END) AS MaxCompletionHours
FROM [MaintenanceRecord] MR
GROUP BY MR.Status;
```

---

## Summary

| # | Query | Target User(s) | Category |
|---|-------|----------------|----------|
| 1 | Pending bookings needing approval | Facility Staff, Manager | Booking Management |
| 2 | Upcoming approved bookings for a space | Facility Staff, Manager | Booking Management |
| 3 | Detect potential overlapping bookings | Facility Manager | Booking Management |
| 4 | Booking history for a specific space | Facility Staff, Manager | History / Audit |
| 5 | Booking history for a specific user | Facility Staff, Admin | History / Audit |
| 6 | List no-show bookings | Facility Manager, Staff | Booking Management |
| 7 | Currently checked-in sessions | Facility Staff | Real-time Monitoring |
| 8 | Active maintenance records | Facility Manager, Staff | Maintenance |
| 9 | Maintenance history for a specific space | Facility Manager, Staff | Maintenance |
| 10 | Unassigned maintenance records | Facility Manager | Maintenance |
| 11 | Spaces with the most maintenance issues | Facility Manager | Analytics |
| 12 | Available spaces for a given time range | All users | Space Availability |
| 13 | Spaces with specific equipment (projector + computer) | Lecturers, TAs, Students | Space Discovery |
| 14 | Space utilization rate | Facility Manager, Admin | Analytics |
| 15 | Spaces with capacity above a threshold | Lecturers, Event Organizers | Space Discovery |
| 16 | Approval activity by staff member | Facility Manager | Staff Oversight |
| 17 | Users with the most bookings | Facility Manager, Admin | User Analytics |
| 18 | Rejected bookings with reasons | Facility Staff, Manager | History / Audit |
| 19 | Booking count by purpose | Facility Manager, Admin | Analytics |
| 20 | Spaces never booked | Facility Manager | Analytics |
| 21 | Monthly booking summary | Facility Manager, Admin | Analytics |
| 22 | Average booking duration by space type | Facility Manager | Analytics |
| 23 | Facilities count grouped by space | Facility Staff, Manager | Inventory |
| 24 | Maintenance completion time analysis | Facility Manager | Analytics |
