-- =====================================================================
-- 16 - Analytical Queries (Phase 2 Section 1.3)
-- Group : 10
-- DBMS  : Microsoft SQL Server (T-SQL)
-- Target: CampusSpaceManagement (Phase 2 schema)
--
-- Implements the four Facility Manager reports:
--   1. Total approved booking hours of each space for a given semester.
--   2. Number of approved bookings by weekday and hour for a semester.
--   3. Available spaces satisfying a required capacity and a required
--      facility list within a given time period (room finder).
--   4. Approved bookings affected when a maintenance record is escalated
--      to out-of-service (overlap analysis).
--
-- Each query declares its parameters at the top so it can be re-run with
-- different inputs.
-- =====================================================================
USE CampusSpaceManagement;
GO

-- ---------------------------------------------------------------------
-- 1. Total approved booking hours of each space for a given semester
--    (Phase 2 Section 1.3, report 1).
-- ---------------------------------------------------------------------
DECLARE @SemesterStart DATETIME2 = '2025-01-01 00:00:00';
DECLARE @SemesterEnd   DATETIME2 = '2025-06-30 23:59:59';

SELECT
    s.SpaceCode,
    s.SpaceName,
    s.SpaceType,
    ISNULL(SUM(DATEDIFF(MINUTE, br.StartTime, br.EndTime) / 60.0), 0) AS TotalApprovedHours
FROM [Space] s
LEFT JOIN BookingRequest br
    ON s.SpaceCode = br.SpaceCode
   AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
   AND br.StartTime < @SemesterEnd          -- booking overlaps the semester
   AND br.EndTime   > @SemesterStart
GROUP BY s.SpaceCode, s.SpaceName, s.SpaceType
ORDER BY TotalApprovedHours DESC;
GO

-- ---------------------------------------------------------------------
-- 2. Number of approved bookings by weekday and hour for a given semester
--    (Phase 2 Section 1.3, report 2).
-- ---------------------------------------------------------------------
DECLARE @SemesterStart2 DATETIME2 = '2025-01-01 00:00:00';
DECLARE @SemesterEnd2   DATETIME2 = '2025-06-30 23:59:59';

SELECT
    DATENAME(WEEKDAY, StartTime)                        AS DayOfWeek,
    DATEPART(HOUR, StartTime)                           AS HourOfDay,
    COUNT(BookingID)                                    AS NumberOfApprovedBookings
FROM BookingRequest
WHERE Status IN ('Approved', 'CheckedIn', 'Completed')
  AND StartTime < @SemesterEnd2
  AND EndTime   > @SemesterStart2
GROUP BY DATENAME(WEEKDAY, StartTime),
         DATEPART(HOUR, StartTime),
         DATEPART(WEEKDAY, StartTime)
ORDER BY DATEPART(WEEKDAY, StartTime), HourOfDay;
GO

-- ---------------------------------------------------------------------
-- 3. Room finder: available spaces that satisfy a required capacity and
--    a required facility list within a given time period
--    (Phase 2 Section 1.3, report 3).
--    The required facilities are supplied in a table variable so that a
--    list (one or more facilities) can be requested at once.
-- ---------------------------------------------------------------------
DECLARE @ReqStart DATETIME2 = '2026-03-10 08:00:00';
DECLARE @ReqEnd   DATETIME2 = '2026-03-10 11:00:00';
DECLARE @ReqCap   INT       = 30;

DECLARE @RequiredFacilities TABLE (FacilityName NVARCHAR(50));
INSERT INTO @RequiredFacilities (FacilityName) VALUES ('Projector'), ('Whiteboard');

SELECT s.SpaceCode, s.SpaceName, s.Capacity, s.CurrentStatus
FROM [Space] s
WHERE s.Capacity >= @ReqCap
  AND s.CurrentStatus IN ('Available', 'InUse')          -- not retired/closed/under maintenance
  AND NOT EXISTS (                                       -- no overlapping approved booking
      SELECT 1
      FROM BookingRequest br
      WHERE br.SpaceCode = s.SpaceCode
        AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
        AND br.StartTime < @ReqEnd
        AND br.EndTime   > @ReqStart
  )
  AND NOT EXISTS (                                       -- no overlapping out-of-service maintenance
      SELECT 1
      FROM MaintenanceRecord mr
      WHERE mr.SpaceCode = s.SpaceCode
        AND mr.ImpactLevel = 'OutOfService'
        AND mr.Status IN ('Open', 'InProgress')
        AND mr.StartTime < @ReqEnd
        AND (mr.CompletionTime IS NULL OR mr.CompletionTime > @ReqStart)
  )
  AND NOT EXISTS (                                       -- every required facility present
      SELECT 1
      FROM @RequiredFacilities rf
      WHERE NOT EXISTS (
          SELECT 1
          FROM Facility f
          WHERE f.SpaceCode = s.SpaceCode
            AND f.FacilityName = rf.FacilityName
      )
  );
GO

-- ---------------------------------------------------------------------
-- 4. Approved bookings affected when a maintenance record is escalated
--    to out-of-service (Phase 2 Section 1.3, report 4).
--    Finds approved bookings on the same space whose time range overlaps
--    the (open) maintenance period, so staff can contact the requesters.
--    The parameter defaults to a real, currently-open out-of-service
--    maintenance record so the report always returns meaningful rows;
--    override it to analyse a specific record (must be ImpactLevel =
--    'OutOfService' for the overlap analysis to apply).
-- ---------------------------------------------------------------------
DECLARE @EscalatedMaintenanceID INT =
    (SELECT TOP 1 MaintenanceID
     FROM MaintenanceRecord
     WHERE ImpactLevel = 'OutOfService'
       AND Status IN ('Open', 'InProgress')
     ORDER BY MaintenanceID);

SELECT
    br.BookingID,
    u.FullName      AS RequesterName,
    u.Email         AS RequesterEmail,
    br.SpaceCode,
    br.StartTime,
    br.EndTime,
    br.Status,
    mr.ImpactLevel,
    mr.ProblemDescription
FROM BookingRequest br
INNER JOIN [User] u          ON br.RequesterID = u.UserID
INNER JOIN MaintenanceRecord mr ON br.SpaceCode = mr.SpaceCode
WHERE mr.MaintenanceID = @EscalatedMaintenanceID
  AND mr.ImpactLevel  = 'OutOfService'
  AND mr.Status       IN ('Open', 'InProgress')
  AND br.Status IN ('Approved', 'CheckedIn')
  AND br.StartTime < ISNULL(mr.CompletionTime, '9999-12-31')   -- overlaps the maintenance window
  AND br.EndTime   > mr.StartTime
ORDER BY br.StartTime;
GO
