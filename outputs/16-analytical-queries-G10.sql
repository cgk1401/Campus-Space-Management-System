-- =====================================================================
-- 16 - Analytical Queries
-- Group: 10
-- Purpose: Provide analytical reports required in Phase 2
-- DBMS: Microsoft SQL Server
-- =====================================================================

USE CampusSpaceManagement;
GO

-- =====================================================================
-- QUERY 1: Total approved booking hours of each space for a given semester
-- =====================================================================
-- Variables to define the semester period
DECLARE @SemesterStart DATETIME2 = '2025-01-01 00:00:00';
DECLARE @SemesterEnd DATETIME2 = '2025-06-30 23:59:59';

SELECT 
    s.SpaceCode,
    s.SpaceName,
    s.SpaceType,
    -- Calculate total duration in hours (using DATEDIFF in minutes then divide by 60.0 to get decimals)
    ISNULL(SUM(DATEDIFF(MINUTE, br.StartTime, br.EndTime) / 60.0), 0) AS TotalApprovedHours
FROM 
    [Space] s
LEFT JOIN 
    BookingRequest br ON s.SpaceCode = br.SpaceCode 
    AND br.Status IN ('Approved', 'CheckedIn', 'Completed') 
    AND br.StartTime >= @SemesterStart 
    AND br.EndTime <= @SemesterEnd
GROUP BY 
    s.SpaceCode, 
    s.SpaceName, 
    s.SpaceType
ORDER BY 
    TotalApprovedHours DESC;
GO

-- =====================================================================
-- QUERY 2: Number of approved bookings by weekday and hour for a given semester
-- =====================================================================
DECLARE @SemesterStart2 DATETIME2 = '2025-01-01 00:00:00';
DECLARE @SemesterEnd2 DATETIME2 = '2025-06-30 23:59:59';

SELECT 
    DATENAME(WEEKDAY, StartTime) AS DayOfWeek,
    DATEPART(HOUR, StartTime) AS HourOfDay,
    COUNT(BookingID) AS NumberOfApprovedBookings
FROM 
    BookingRequest
WHERE 
    Status IN ('Approved', 'CheckedIn', 'Completed') 
    AND StartTime >= @SemesterStart2 
    AND EndTime <= @SemesterEnd2
GROUP BY 
    DATENAME(WEEKDAY, StartTime),
    DATEPART(HOUR, StartTime),
    DATEPART(WEEKDAY, StartTime) -- Used for correct sorting
ORDER BY 
    DATEPART(WEEKDAY, StartTime), 
    HourOfDay;
GO

-- =====================================================================
-- QUERY 3: Room Finder - Available spaces satisfying capacity and facilities
-- =====================================================================
DECLARE @RequiredStartTime DATETIME2 = '2026-03-10 08:00:00';
DECLARE @RequiredEndTime DATETIME2 = '2026-03-10 11:00:00';
DECLARE @RequiredCapacity INT = 30;

SELECT 
    s.SpaceCode,
    s.SpaceName,
    s.Capacity,
    s.SpaceType
FROM 
    [Space] s
WHERE 
    s.Capacity >= @RequiredCapacity
    AND s.CurrentStatus != 'Retired' -- Basic sanity check
    -- 1. Must NOT have any overlapping approved/checked-in/completed booking
    AND NOT EXISTS (
        SELECT 1 
        FROM BookingRequest br
        WHERE br.SpaceCode = s.SpaceCode
          AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
          AND br.StartTime < @RequiredEndTime 
          AND br.EndTime > @RequiredStartTime
    )
    -- 2. Must NOT have any overlapping OUT-OF-SERVICE maintenance
    AND NOT EXISTS (
        SELECT 1 
        FROM MaintenanceRecord mr
        WHERE mr.SpaceCode = s.SpaceCode
          AND mr.ImpactLevel = 'OutOfService'
          AND mr.Status IN ('Open', 'InProgress')
          AND mr.StartTime < @RequiredEndTime 
          AND (mr.CompletionTime IS NULL OR mr.CompletionTime > @RequiredStartTime)
    )
    -- 3. Must satisfy required facility list (Example: needs BOTH Projector and Whiteboard)
    -- If no specific facilities are required, this block can be omitted.
    AND EXISTS (SELECT 1 FROM Facility f WHERE f.SpaceCode = s.SpaceCode AND f.FacilityName = 'Projector')
    AND EXISTS (SELECT 1 FROM Facility f WHERE f.SpaceCode = s.SpaceCode AND f.FacilityName = 'Whiteboard')
ORDER BY 
    s.Capacity ASC; -- Suggest rooms that closely match the capacity
GO

-- =====================================================================
-- QUERY 4: Approved bookings affected when a maintenance record is escalated
-- =====================================================================
-- Assume MaintenanceID = 105 is suddenly escalated to 'OutOfService'
DECLARE @EscalatedMaintenanceID INT = 105;

SELECT 
    br.BookingID,
    br.RequesterID,
    u.FullName AS RequesterName,
    u.Email AS RequesterEmail,
    br.SpaceCode,
    br.StartTime AS BookingStart,
    br.EndTime AS BookingEnd,
    br.Status AS BookingStatus
FROM 
    BookingRequest br
INNER JOIN 
    [User] u ON br.RequesterID = u.UserID
INNER JOIN 
    MaintenanceRecord mr ON br.SpaceCode = mr.SpaceCode
WHERE 
    mr.MaintenanceID = @EscalatedMaintenanceID
    AND br.Status IN ('Approved', 'CheckedIn') -- Only affect bookings that are active/future
    AND br.StartTime < ISNULL(mr.CompletionTime, '9999-12-31') -- Overlap check (BookingStart < MaintenanceEnd)
    AND br.EndTime > mr.StartTime;                             -- Overlap check (BookingEnd > MaintenanceStart)
GO