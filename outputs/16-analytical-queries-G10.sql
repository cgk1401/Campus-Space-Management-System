-- =====================================================================
-- 16 - Analytical Queries
-- =====================================================================
USE CampusSpaceManagement;
GO

-- 1. Total approved booking hours of each space for a given semester
DECLARE @SemesterStart DATETIME2 = '2025-01-01 00:00:00';
DECLARE @SemesterEnd DATETIME2 = '2025-06-30 23:59:59';

SELECT 
    s.SpaceCode,
    s.SpaceName,
    s.SpaceType,
    ISNULL(SUM(DATEDIFF(MINUTE, br.StartTime, br.EndTime) / 60.0), 0) AS TotalApprovedHours
FROM [Space] s
LEFT JOIN BookingRequest br ON s.SpaceCode = br.SpaceCode 
    AND br.Status IN ('Approved', 'CheckedIn', 'Completed') 
    AND br.StartTime >= @SemesterStart 
    AND br.EndTime <= @SemesterEnd
GROUP BY s.SpaceCode, s.SpaceName, s.SpaceType
ORDER BY TotalApprovedHours DESC;
GO

-- 2. Number of approved bookings by weekday and hour for a given semester
DECLARE @SemesterStart2 DATETIME2 = '2025-01-01 00:00:00';
DECLARE @SemesterEnd2 DATETIME2 = '2025-06-30 23:59:59';

SELECT 
    DATENAME(WEEKDAY, StartTime) AS DayOfWeek,
    DATEPART(HOUR, StartTime) AS HourOfDay,
    COUNT(BookingID) AS NumberOfApprovedBookings
FROM BookingRequest
WHERE Status IN ('Approved', 'CheckedIn', 'Completed') 
  AND StartTime >= @SemesterStart2 
  AND EndTime <= @SemesterEnd2
GROUP BY DATENAME(WEEKDAY, StartTime), DATEPART(HOUR, StartTime), DATEPART(WEEKDAY, StartTime)
ORDER BY DATEPART(WEEKDAY, StartTime), HourOfDay;
GO

-- 3. Available spaces that satisfy a required capacity and a required facility list
DECLARE @ReqStart DATETIME2 = '2026-03-10 08:00:00';
DECLARE @ReqEnd DATETIME2 = '2026-03-10 11:00:00';
DECLARE @ReqCap INT = 30;

SELECT s.SpaceCode, s.SpaceName, s.Capacity
FROM [Space] s
WHERE s.Capacity >= @ReqCap AND s.CurrentStatus != 'Retired'
  AND NOT EXISTS (
      SELECT 1 FROM BookingRequest br
      WHERE br.SpaceCode = s.SpaceCode AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
        AND br.StartTime < @ReqEnd AND br.EndTime > @ReqStart
  )
  AND NOT EXISTS (
      SELECT 1 FROM MaintenanceRecord mr
      WHERE mr.SpaceCode = s.SpaceCode AND mr.ImpactLevel = 'OutOfService' AND mr.Status IN ('Open', 'InProgress')
        AND mr.StartTime < @ReqEnd AND (mr.CompletionTime IS NULL OR mr.CompletionTime > @ReqStart)
  )
  AND EXISTS (SELECT 1 FROM Facility f WHERE f.SpaceCode = s.SpaceCode AND f.FacilityName = 'Projector');
GO

-- 4. Approved bookings affected when a maintenance record is escalated to out-of-service
DECLARE @EscalatedMaintenanceID INT = 105;

SELECT br.BookingID, u.FullName AS RequesterName, br.SpaceCode, br.StartTime, br.EndTime, br.Status
FROM BookingRequest br
INNER JOIN [User] u ON br.RequesterID = u.UserID
INNER JOIN MaintenanceRecord mr ON br.SpaceCode = mr.SpaceCode
WHERE mr.MaintenanceID = @EscalatedMaintenanceID
  AND br.Status IN ('Approved', 'CheckedIn')
  AND br.StartTime < ISNULL(mr.CompletionTime, '9999-12-31') 
  AND br.EndTime > mr.StartTime;
GO