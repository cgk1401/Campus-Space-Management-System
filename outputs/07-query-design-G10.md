# 07 — Query Design

Eight meaningful SQL queries for the `CampusSpaceManagement` database (DDL: `outputs/05-db-definition.md`; test data: `outputs/06-sample-data.md`). Each query answers a real business question, lists its target user(s), and explains why it is useful.

> Queries assume the database is seeded with the sample data (reference date 2026-08-05). `SYSDATETIME()`-based queries are written for live use.

---

## Q1. Upcoming bookings (what is coming up?)

**Business question:** Which approved bookings are scheduled to take place soon, and who requested them?

**Target user(s):** Facility Staff, Department Administrator, Facility Manager.

**Short explanation:** Answers the §1.8 reporting need "view upcoming bookings" and lets staff prepare spaces and check availability ahead of time.

```sql
SELECT b.BookingID,
       u.FullName            AS Requester,
       s.SpaceCode,
       s.SpaceName,
       b.StartTime,
       b.EndTime,
       b.Purpose,
       b.ExpectedParticipants
FROM BookingRequest b
JOIN [User] u ON u.UserID = b.RequesterID
JOIN [Space] s ON s.SpaceCode = b.SpaceCode
WHERE b.Status IN ('Approved', 'CheckedIn')
  AND b.EndTime >= SYSDATETIME()
ORDER BY b.StartTime;
```

**Expected result (sample data):** B5 (Meeting, `B1-102`, 2026-08-14) and B2 (Workshop, `C2-201`, 2026-08-10); B12 appears while its session is still running (2026-08-05).

---

## Q2. Spaces currently under maintenance

**Business question:** Which spaces are currently unavailable due to maintenance, and what is being fixed?

**Target user(s):** Facility Manager, Facility Staff.

**Short explanation:** Answers the §1.8 reporting need "view spaces under maintenance"; also feeds BR4 — a space with an open maintenance record must not be booked.

```sql
SELECT s.SpaceCode,
       s.SpaceName,
       s.Building,
       s.Floor,
       s.CurrentStatus,
       m.MaintenanceID,
       m.ProblemDescription,
       m.StartTime,
       m.Status               AS MaintenanceStatus,
       u.FullName             AS AssignedStaff
FROM [Space] s
JOIN MaintenanceRecord m ON m.SpaceCode = s.SpaceCode
LEFT JOIN [User] u ON u.UserID = m.AssignedStaffID
WHERE m.Status IN ('Open', 'InProgress')
ORDER BY s.SpaceCode, m.StartTime;
```

**Expected result (sample data):** `B2-301` (Project Lab 301) with M1 (Computer C-201) and M2 (Air conditioning), both Open, assigned to Vu Duc Trung.

---

## Q3. No-show bookings

**Business question:** Which approved bookings never resulted in a check-in (no-show)?

**Target user(s):** Facility Manager, Department Administrator.

**Short explanation:** Answers the §1.8 reporting need "view no-show bookings" and helps decide whether repeat offenders should lose booking privileges.

```sql
SELECT b.BookingID,
       u.FullName             AS Requester,
       u.Email,
       s.SpaceName,
       b.StartTime,
       b.EndTime,
       b.Purpose
FROM BookingRequest b
JOIN [User] u ON u.UserID = b.RequesterID
JOIN [Space] s ON s.SpaceCode = b.SpaceCode
WHERE b.Status = 'NoShow'
ORDER BY b.StartTime;
```

**Expected result (sample data):** B7 (Examination, `B1-102`, requested by Hoang Thu Van).

---

## Q4. Overlap check (BR2 conflict detection)

**Business question:** For a proposed new booking, does any already-approved session overlap it in the same space?

**Target user(s):** Application layer (automatic check at submit/approval time), Facility Staff, Facility Manager.

**Short explanation:** This is the core of the BR2 conflict-prevention rule that cannot be expressed as DDL. Any booking that returns a row here must be rejected.

```sql
DECLARE @SpaceCode NVARCHAR(20) = 'C2-201';
DECLARE @StartTime DATETIME2    = '2026-08-10T09:30:00';
DECLARE @EndTime   DATETIME2    = '2026-08-10T11:30:00';

SELECT b.BookingID,
       b.StartTime,
       b.EndTime,
       b.Status
FROM BookingRequest b
WHERE b.SpaceCode = @SpaceCode
  AND b.Status IN ('Approved', 'CheckedIn')
  AND b.StartTime < @EndTime      -- intervals overlap iff A.start < B.end AND A.end > B.start
  AND b.EndTime   > @StartTime
ORDER BY b.StartTime;
```

**Expected result (sample data):** B2 (09:00–11:00). This is exactly why sample booking B3 (09:30–11:30, same lab) was rejected. For concurrency safety wrap in a transaction with `UPDLOCK`/`HOLDLOCK` (see `outputs/05-db-definition.md` §4).

---

## Q5. Space utilization summary

**Business question:** How heavily is each space used, and what is its total booked time?

**Target user(s):** Facility Manager, Department Administrator.

**Short explanation:** Supports the main system goal of managing shared spaces fairly by showing load across spaces; retired/closed spaces naturally show zero.

```sql
SELECT s.SpaceCode,
       s.SpaceName,
       s.SpaceType,
       s.Capacity,
       s.CurrentStatus,
       COUNT(b.BookingID)                    AS TotalBookings,
       SUM(DATEDIFF(MINUTE, b.StartTime, b.EndTime)) / 60.0 AS TotalBookedHours
FROM [Space] s
LEFT JOIN BookingRequest b
       ON b.SpaceCode = s.SpaceCode
      AND b.Status NOT IN ('Rejected', 'Cancelled', 'NoShow')
GROUP BY s.SpaceCode, s.SpaceName, s.SpaceType, s.Capacity, s.CurrentStatus
ORDER BY TotalBookedHours DESC;
```

**Expected result (sample data):** `A1-101` (2 effective bookings), `C2-201` (2), `B1-102` (2), `D1-105` (1 pending); `B2-301`, `B3-401`, `C1-101` show zero because they cannot be booked.

---

## Q6. Pending bookings awaiting a decision

**Business question:** Which booking requests still need an approval/rejection decision?

**Target user(s):** Facility Staff, Facility Manager.

**Short explanation:** A ready-made task list for approvers (BR16 — only FacilityStaff/Manager decide) so requests do not sit in `Pending` indefinitely.

```sql
SELECT b.BookingID,
       u.FullName             AS Requester,
       s.SpaceCode,
       s.SpaceName,
       b.StartTime,
       b.EndTime,
       b.Purpose,
       b.ExpectedParticipants
FROM BookingRequest b
JOIN [User] u ON u.UserID = b.RequesterID
JOIN [Space] s ON s.SpaceCode = b.SpaceCode
WHERE b.Status = 'Pending'
ORDER BY b.StartTime;
```

**Expected result (sample data):** B4 (AdministrativeEvent, `D1-105`, 2026-08-12).

---

## Q7. Facility inventory per space

**Business question:** What facilities (individual units) are installed in each space?

**Target user(s):** Facility Manager, Facility Staff.

**Short explanation:** Answers the §1.3 requirement to store the list of facilities per space at unit level, and supports maintenance reporting per unit.

```sql
SELECT s.SpaceCode,
       s.SpaceName,
       f.FacilityID,
       f.FacilityName
FROM [Space] s
LEFT JOIN Facility f ON f.SpaceCode = s.SpaceCode
ORDER BY s.SpaceCode, f.FacilityID;
```

**Expected result (sample data):** 16 facility units distributed across 7 spaces (e.g., `A1-101` has Projector, Microphone, LivestreamingEquipment, Whiteboard; `C2-201` has 4 units).

---

## Q8. Maintenance history per facility unit

**Business question:** What is the complete maintenance history of each individual facility unit?

**Target user(s):** Facility Manager, Facility Staff.

**Short explanation:** Exploits the per-unit modeling decision (BR9/A5) so a specific unit (e.g., Computer C-201) can be traced through every maintenance record.

```sql
SELECT f.FacilityID,
       f.FacilityName,
       s.SpaceCode,
       s.SpaceName,
       m.MaintenanceID,
       m.ProblemDescription,
       m.Status,
       m.StartTime,
       m.CompletionTime,
       m.ResultNote
FROM Facility f
JOIN [Space] s ON s.SpaceCode = f.SpaceCode
LEFT JOIN MaintenanceRecord m ON m.FacilityID = f.FacilityID
ORDER BY f.FacilityID, m.StartTime;
```

**Expected result (sample data):** Facility 11 (Computer, `B2-301`) shows M1 (Open); Facility 12 (AirConditioner, `B2-301`) shows M2 (Open); units never maintained show NULL maintenance columns.

---

## Coverage vs. Reporting Requirements (§1.8)

| §1.8 report | Query |
|-------------|-------|
| Booking history | Q5 (aggregated), Q7/Q8 (facility-oriented), sample-driven via Q3 |
| Upcoming bookings | Q1 |
| Spaces under maintenance | Q2 |
| No-show bookings | Q3 |
| Core rule support (BR2 conflict) | Q4 |
| Approver task list / pending | Q6 |

---

## Notes

- All queries are valid against the Step 5 DDL (table/column names match exactly; `[User]` bracketed as a reserved word).
- Q4, Q5, Q8 demonstrate the three main query patterns the system needs: interval-overlap detection, aggregation for utilization, and join chains for traceability.