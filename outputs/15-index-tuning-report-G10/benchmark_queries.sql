-- =====================================================================
-- Benchmark script for Step 15 (Index Tuning Report)
-- Group : 10
-- DBMS  : Microsoft SQL Server (T-SQL)
-- Target: CampusSpaceManagement (Phase 2 schema + generated dataset)
--
-- IMPORTANT: the full generated dataset must be loaded first:
--   outputs/14-data-generator-G10/sql_batches/00_master_seed.sql
--   outputs/14-data-generator-G10/sql_batches/01_bookings_batch_01.sql .. _20.sql
--   (= 100,000 BookingRequests spanning 2023-09-01 .. 2026-08-31).
-- The script prints the actual row count at the top so you can verify.
--
-- Methodology (run the WHOLE script once):
--   PART A - BEFORE indexing: drop tuned indexes -> warmup -> timed run.
--   PART B - create the 3 tuned indexes.
--   PART C - AFTER indexing : warmup (avoids plan-recompile noise caused
--            by CREATE INDEX) -> timed run.
-- Warmup runs materialize into #temp tables (unique names per section)
-- so the Messages tab only shows the timed run, and the "SQL Server
-- Execution Times" line reflects query execution only (plan already cached).
-- =====================================================================
USE CampusSpaceManagement;
GO

SET NOCOUNT ON;

PRINT '';
PRINT '==============================================================';
PRINT ' Benchmark: Step 15 tuned queries (before vs after indexing)';
PRINT '==============================================================';
PRINT '';

-- ---------------------------------------------------------------------
-- 0. Reference parameters (derived from the actual dataset).
-- ---------------------------------------------------------------------
DECLARE @BusySpace NVARCHAR(20) =
    (SELECT TOP 1 SpaceCode
     FROM BookingRequest
     GROUP BY SpaceCode
     ORDER BY COUNT(*) DESC);

DECLARE @SemStart DATETIME2 = (SELECT MIN(StartTime) FROM BookingRequest);
DECLARE @SemEnd   DATETIME2 = DATEADD(MONTH, 6, @SemStart);

DECLARE @WinStart DATETIME2 =
    (SELECT TOP 1 StartTime FROM BookingRequest ORDER BY NEWID());
DECLARE @WinEnd   DATETIME2 = DATEADD(HOUR, 3, @WinStart);

DECLARE @ReqCap INT = 30;
DECLARE @RequiredFacilities TABLE (FacilityName NVARCHAR(50));
INSERT INTO @RequiredFacilities (FacilityName) VALUES ('Projector'), ('Whiteboard');

DECLARE @TotalBookings INT = (SELECT COUNT(*) FROM BookingRequest);

PRINT 'Dataset scale     : ' + CAST(@TotalBookings AS VARCHAR(12)) + ' BookingRequest rows (target: 100,000)';
PRINT 'Busy space        : ' + ISNULL(@BusySpace, '(none)');
PRINT 'Semester window   : ' + CONVERT(VARCHAR(30), @SemStart) + '  ->  ' + CONVERT(VARCHAR(30), @SemEnd);
PRINT 'Conflict window   : ' + CONVERT(VARCHAR(30), @WinStart) + '  ->  ' + CONVERT(VARCHAR(30), @WinEnd);
PRINT 'Required capacity : ' + CAST(@ReqCap AS VARCHAR(10));
PRINT '';

-- ---------------------------------------------------------------------
-- Reset: drop the Step 15 tuned indexes if a previous run left them.
-- Guarantees PART A (BEFORE) always measures WITHOUT the tuned indexes,
-- even when the script is re-run on a database that already has them.
-- (The Phase 1 supporting indexes from 05-db-definition-G10.md §3 are
--  intentionally NOT touched - they are part of the deployed baseline.)
-- ---------------------------------------------------------------------
DROP INDEX IF EXISTS IX_BookingRequest_ConflictCheck ON BookingRequest;
DROP INDEX IF EXISTS IX_MaintenanceRecord_Overlap    ON MaintenanceRecord;
DROP INDEX IF EXISTS IX_BookingRequest_Reporting     ON BookingRequest;
PRINT 'Reset: Step 15 tuned indexes dropped (if present).';
PRINT '';

-- =====================================================================
-- PART A - BEFORE INDEXING
-- =====================================================================
PRINT '================ PART A: BEFORE INDEXING ================';

-- ---------------------------------------------------------------------
-- Q1. Booking Conflict Check  (Step 15 Section 2.1)
-- ---------------------------------------------------------------------
PRINT '--- Q1. Booking Conflict Check (BEFORE) ---';

-- Warmup: materialize, discard output, cache the plan.
DROP TABLE IF EXISTS #warm_b1;
SELECT COUNT(*) AS WarmupRowCount INTO #warm_b1
FROM BookingRequest br
WHERE br.SpaceCode = @BusySpace
  AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
  AND br.StartTime < @WinEnd
  AND br.EndTime   > @WinStart;
DROP TABLE IF EXISTS #warm_b1;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT COUNT(*) AS OverlappingBookings
FROM BookingRequest br
WHERE br.SpaceCode = @BusySpace
  AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
  AND br.StartTime < @WinEnd
  AND br.EndTime   > @WinStart;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

-- ---------------------------------------------------------------------
-- Q2. Room Finder  (Step 15 Section 2.2 = Step 16 report 3)
-- ---------------------------------------------------------------------
PRINT '--- Q2. Room Finder (BEFORE) ---';

DROP TABLE IF EXISTS #warm_b2;
SELECT s.SpaceCode, s.SpaceName, s.Capacity, s.CurrentStatus INTO #warm_b2
FROM [Space] s
WHERE s.Capacity >= @ReqCap
  AND s.CurrentStatus IN ('Available', 'InUse')
  AND NOT EXISTS (
      SELECT 1 FROM BookingRequest br
      WHERE br.SpaceCode = s.SpaceCode
        AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
        AND br.StartTime < @WinEnd
        AND br.EndTime   > @WinStart
  )
  AND NOT EXISTS (
      SELECT 1 FROM MaintenanceRecord mr
      WHERE mr.SpaceCode = s.SpaceCode
        AND mr.ImpactLevel = 'OutOfService'
        AND mr.Status IN ('Open', 'InProgress')
        AND mr.StartTime < @WinEnd
        AND (mr.CompletionTime IS NULL OR mr.CompletionTime > @WinStart)
  )
  AND NOT EXISTS (
      SELECT 1 FROM @RequiredFacilities rf
      WHERE NOT EXISTS (
          SELECT 1 FROM Facility f
          WHERE f.SpaceCode = s.SpaceCode AND f.FacilityName = rf.FacilityName
      )
  );
DROP TABLE IF EXISTS #warm_b2;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT s.SpaceCode, s.SpaceName, s.Capacity, s.CurrentStatus
FROM [Space] s
WHERE s.Capacity >= @ReqCap
  AND s.CurrentStatus IN ('Available', 'InUse')
  AND NOT EXISTS (
      SELECT 1 FROM BookingRequest br
      WHERE br.SpaceCode = s.SpaceCode
        AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
        AND br.StartTime < @WinEnd
        AND br.EndTime   > @WinStart
  )
  AND NOT EXISTS (
      SELECT 1 FROM MaintenanceRecord mr
      WHERE mr.SpaceCode = s.SpaceCode
        AND mr.ImpactLevel = 'OutOfService'
        AND mr.Status IN ('Open', 'InProgress')
        AND mr.StartTime < @WinEnd
        AND (mr.CompletionTime IS NULL OR mr.CompletionTime > @WinStart)
  )
  AND NOT EXISTS (
      SELECT 1 FROM @RequiredFacilities rf
      WHERE NOT EXISTS (
          SELECT 1 FROM Facility f
          WHERE f.SpaceCode = s.SpaceCode AND f.FacilityName = rf.FacilityName
      )
  );
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

-- ---------------------------------------------------------------------
-- Q3. Total Approved Booking Hours per Space (Step 15 Section 2.3 = 16 report 1)
-- ---------------------------------------------------------------------
PRINT '--- Q3. Total approved booking hours per space (BEFORE) ---';

DROP TABLE IF EXISTS #warm_b3;
SELECT s.SpaceCode, s.SpaceName, s.SpaceType,
       ISNULL(SUM(DATEDIFF(MINUTE, br.StartTime, br.EndTime) / 60.0), 0) AS TotalApprovedHours
INTO #warm_b3
FROM [Space] s
LEFT JOIN BookingRequest br
    ON s.SpaceCode = br.SpaceCode
   AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
   AND br.StartTime < @SemEnd
   AND br.EndTime   > @SemStart
GROUP BY s.SpaceCode, s.SpaceName, s.SpaceType;
DROP TABLE IF EXISTS #warm_b3;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT
    s.SpaceCode,
    s.SpaceName,
    s.SpaceType,
    ISNULL(SUM(DATEDIFF(MINUTE, br.StartTime, br.EndTime) / 60.0), 0) AS TotalApprovedHours
FROM [Space] s
LEFT JOIN BookingRequest br
    ON s.SpaceCode = br.SpaceCode
   AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
   AND br.StartTime < @SemEnd
   AND br.EndTime   > @SemStart
GROUP BY s.SpaceCode, s.SpaceName, s.SpaceType
ORDER BY TotalApprovedHours DESC;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

-- ---------------------------------------------------------------------
-- Q4. Approved Bookings by Weekday and Hour (Step 15 Section 2.4 = 16 report 2)
-- ---------------------------------------------------------------------
PRINT '--- Q4. Approved bookings by weekday and hour (BEFORE) ---';

DROP TABLE IF EXISTS #warm_b4;
SELECT DATENAME(WEEKDAY, StartTime) AS DayOfWeek,
       DATEPART(HOUR, StartTime)    AS HourOfDay,
       COUNT(BookingID)             AS NumberOfApprovedBookings
INTO #warm_b4
FROM BookingRequest
WHERE Status IN ('Approved', 'CheckedIn', 'Completed')
  AND StartTime < @SemEnd
  AND EndTime   > @SemStart
GROUP BY DATENAME(WEEKDAY, StartTime), DATEPART(HOUR, StartTime), DATEPART(WEEKDAY, StartTime);
DROP TABLE IF EXISTS #warm_b4;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT
    DATENAME(WEEKDAY, StartTime) AS DayOfWeek,
    DATEPART(HOUR, StartTime)    AS HourOfDay,
    COUNT(BookingID)             AS NumberOfApprovedBookings
FROM BookingRequest
WHERE Status IN ('Approved', 'CheckedIn', 'Completed')
  AND StartTime < @SemEnd
  AND EndTime   > @SemStart
GROUP BY DATENAME(WEEKDAY, StartTime), DATEPART(HOUR, StartTime), DATEPART(WEEKDAY, StartTime)
ORDER BY DATEPART(WEEKDAY, StartTime), HourOfDay;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

PRINT '';
PRINT '================ END OF PART A ================';

-- =====================================================================
-- PART B - CREATE THE TUNED INDEXES
-- =====================================================================
PRINT '';
PRINT '================ PART B: CREATING INDEXES ================';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BookingRequest_ConflictCheck'
               AND object_id = OBJECT_ID('dbo.BookingRequest'))
    CREATE NONCLUSTERED INDEX IX_BookingRequest_ConflictCheck
        ON BookingRequest (SpaceCode, Status, StartTime, EndTime)
        INCLUDE (RequesterID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MaintenanceRecord_Overlap'
               AND object_id = OBJECT_ID('dbo.MaintenanceRecord'))
    CREATE NONCLUSTERED INDEX IX_MaintenanceRecord_Overlap
        ON MaintenanceRecord (SpaceCode, ImpactLevel, Status, StartTime)
        INCLUDE (CompletionTime);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BookingRequest_Reporting'
               AND object_id = OBJECT_ID('dbo.BookingRequest'))
    CREATE NONCLUSTERED INDEX IX_BookingRequest_Reporting
        ON BookingRequest (Status, StartTime, EndTime)
        INCLUDE (SpaceCode);

PRINT 'Indexes created: IX_BookingRequest_ConflictCheck, IX_MaintenanceRecord_Overlap, IX_BookingRequest_Reporting';

-- =====================================================================
-- PART C - AFTER INDEXING  (warmup first -> no plan-recompile noise)
-- =====================================================================
PRINT '';
PRINT '================ PART C: AFTER INDEXING ================';

PRINT '--- Q1. Booking Conflict Check (AFTER) ---';
DROP TABLE IF EXISTS #warm_a1;
SELECT COUNT(*) AS WarmupRowCount INTO #warm_a1
FROM BookingRequest br
WHERE br.SpaceCode = @BusySpace
  AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
  AND br.StartTime < @WinEnd
  AND br.EndTime   > @WinStart;
DROP TABLE IF EXISTS #warm_a1;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT COUNT(*) AS OverlappingBookings
FROM BookingRequest br
WHERE br.SpaceCode = @BusySpace
  AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
  AND br.StartTime < @WinEnd
  AND br.EndTime   > @WinStart;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

PRINT '--- Q2. Room Finder (AFTER) ---';
DROP TABLE IF EXISTS #warm_a2;
SELECT s.SpaceCode, s.SpaceName, s.Capacity, s.CurrentStatus INTO #warm_a2
FROM [Space] s
WHERE s.Capacity >= @ReqCap
  AND s.CurrentStatus IN ('Available', 'InUse')
  AND NOT EXISTS (
      SELECT 1 FROM BookingRequest br
      WHERE br.SpaceCode = s.SpaceCode
        AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
        AND br.StartTime < @WinEnd
        AND br.EndTime   > @WinStart
  )
  AND NOT EXISTS (
      SELECT 1 FROM MaintenanceRecord mr
      WHERE mr.SpaceCode = s.SpaceCode
        AND mr.ImpactLevel = 'OutOfService'
        AND mr.Status IN ('Open', 'InProgress')
        AND mr.StartTime < @WinEnd
        AND (mr.CompletionTime IS NULL OR mr.CompletionTime > @WinStart)
  )
  AND NOT EXISTS (
      SELECT 1 FROM @RequiredFacilities rf
      WHERE NOT EXISTS (
          SELECT 1 FROM Facility f
          WHERE f.SpaceCode = s.SpaceCode AND f.FacilityName = rf.FacilityName
      )
  );
DROP TABLE IF EXISTS #warm_a2;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT s.SpaceCode, s.SpaceName, s.Capacity, s.CurrentStatus
FROM [Space] s
WHERE s.Capacity >= @ReqCap
  AND s.CurrentStatus IN ('Available', 'InUse')
  AND NOT EXISTS (
      SELECT 1 FROM BookingRequest br
      WHERE br.SpaceCode = s.SpaceCode
        AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
        AND br.StartTime < @WinEnd
        AND br.EndTime   > @WinStart
  )
  AND NOT EXISTS (
      SELECT 1 FROM MaintenanceRecord mr
      WHERE mr.SpaceCode = s.SpaceCode
        AND mr.ImpactLevel = 'OutOfService'
        AND mr.Status IN ('Open', 'InProgress')
        AND mr.StartTime < @WinEnd
        AND (mr.CompletionTime IS NULL OR mr.CompletionTime > @WinStart)
  )
  AND NOT EXISTS (
      SELECT 1 FROM @RequiredFacilities rf
      WHERE NOT EXISTS (
          SELECT 1 FROM Facility f
          WHERE f.SpaceCode = s.SpaceCode AND f.FacilityName = rf.FacilityName
      )
  );
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

PRINT '--- Q3. Total approved booking hours per space (AFTER) ---';
DROP TABLE IF EXISTS #warm_a3;
SELECT s.SpaceCode, s.SpaceName, s.SpaceType,
       ISNULL(SUM(DATEDIFF(MINUTE, br.StartTime, br.EndTime) / 60.0), 0) AS TotalApprovedHours
INTO #warm_a3
FROM [Space] s
LEFT JOIN BookingRequest br
    ON s.SpaceCode = br.SpaceCode
   AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
   AND br.StartTime < @SemEnd
   AND br.EndTime   > @SemStart
GROUP BY s.SpaceCode, s.SpaceName, s.SpaceType;
DROP TABLE IF EXISTS #warm_a3;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT
    s.SpaceCode,
    s.SpaceName,
    s.SpaceType,
    ISNULL(SUM(DATEDIFF(MINUTE, br.StartTime, br.EndTime) / 60.0), 0) AS TotalApprovedHours
FROM [Space] s
LEFT JOIN BookingRequest br
    ON s.SpaceCode = br.SpaceCode
   AND br.Status IN ('Approved', 'CheckedIn', 'Completed')
   AND br.StartTime < @SemEnd
   AND br.EndTime   > @SemStart
GROUP BY s.SpaceCode, s.SpaceName, s.SpaceType
ORDER BY TotalApprovedHours DESC;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

PRINT '--- Q4. Approved bookings by weekday and hour (AFTER) ---';
DROP TABLE IF EXISTS #warm_a4;
SELECT DATENAME(WEEKDAY, StartTime) AS DayOfWeek,
       DATEPART(HOUR, StartTime)    AS HourOfDay,
       COUNT(BookingID)             AS NumberOfApprovedBookings
INTO #warm_a4
FROM BookingRequest
WHERE Status IN ('Approved', 'CheckedIn', 'Completed')
  AND StartTime < @SemEnd
  AND EndTime   > @SemStart
GROUP BY DATENAME(WEEKDAY, StartTime), DATEPART(HOUR, StartTime), DATEPART(WEEKDAY, StartTime);
DROP TABLE IF EXISTS #warm_a4;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
SELECT
    DATENAME(WEEKDAY, StartTime) AS DayOfWeek,
    DATEPART(HOUR, StartTime)    AS HourOfDay,
    COUNT(BookingID)             AS NumberOfApprovedBookings
FROM BookingRequest
WHERE Status IN ('Approved', 'CheckedIn', 'Completed')
  AND StartTime < @SemEnd
  AND EndTime   > @SemStart
GROUP BY DATENAME(WEEKDAY, StartTime), DATEPART(HOUR, StartTime), DATEPART(WEEKDAY, StartTime)
ORDER BY DATEPART(WEEKDAY, StartTime), HourOfDay;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

PRINT '';
PRINT '================ END OF PART C ================';
PRINT 'Copy the "SQL Server Execution Times (elapsed time)" lines from the';
PRINT 'Messages tab (Q1..Q4 BEFORE and AFTER) into 15-index-tuning-report-G10.md.';
GO

-- ---------------------------------------------------------------------
-- Q5 (optional) Step 16 report 4: approved bookings affected when a
-- maintenance record is escalated to out-of-service.
-- Not part of the Step 15 tuning set; run once for reporting.
-- ---------------------------------------------------------------------
SET NOCOUNT ON;
SET STATISTICS TIME ON;

DECLARE @EscalatedMaintenanceID INT =
    (SELECT TOP 1 MaintenanceID
     FROM MaintenanceRecord
     WHERE ImpactLevel = 'OutOfService' AND Status IN ('Open', 'InProgress')
     ORDER BY MaintenanceID);

PRINT '--- Q5 (optional). Escalation impact: affected approved bookings ---';
PRINT 'MaintenanceID = ' + ISNULL(CAST(@EscalatedMaintenanceID AS VARCHAR(20)), '(none open)');

SELECT
    br.BookingID,
    u.FullName      AS RequesterName,
    u.Email         AS RequesterEmail,
    br.SpaceCode,
    br.StartTime,
    br.EndTime,
    br.Status,
    mr.ProblemDescription
FROM BookingRequest br
INNER JOIN [User] u          ON br.RequesterID = u.UserID
INNER JOIN MaintenanceRecord mr ON br.SpaceCode = mr.SpaceCode
WHERE mr.MaintenanceID = @EscalatedMaintenanceID
  AND mr.ImpactLevel  = 'OutOfService'
  AND br.Status IN ('Approved', 'CheckedIn')
  AND br.StartTime < ISNULL(mr.CompletionTime, '9999-12-31')
  AND br.EndTime   > mr.StartTime
ORDER BY br.StartTime;

SET STATISTICS TIME OFF;
GO
