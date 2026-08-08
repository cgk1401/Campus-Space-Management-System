-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A1c-unmitigated-verify.sql
-- =====================================================================
-- PASS/FAIL check for the UNMITIGATED demo.
-- Counts approved bookings that participate in at least one overlap on the
-- test space (BR21 offender count).
--
-- EXPECTED: 2  (B1 09:00-11:00 and B2 10:00-12:00 are BOTH Approved and
--               overlap at 10:00-11:00) -> BR21 VIOLATED.
-- This is the "before-fix" proof that the race is real and the Step 12
-- solution is NECESSARY.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

PRINT '--- PASS/FAIL: BR21 overlap offender count (expect 2 = BR21 violated) ---';
SELECT COUNT(DISTINCT a.BookingID) AS OverlappingApprovedBookings
FROM dbo.BookingRequest a
JOIN dbo.BookingRequest b
  ON a.SpaceCode = b.SpaceCode
 AND a.BookingID <> b.BookingID
 AND a.StartTime < b.EndTime
 AND a.EndTime   > b.StartTime
WHERE a.SpaceCode = 'TEST-CC-A'
  AND a.Status IN ('Approved','CheckedIn','Completed','NoShow')
  AND b.Status IN ('Approved','CheckedIn','Completed','NoShow');

PRINT '--- Final table state on TEST-CC-A ---';
SELECT b.BookingID, b.SpaceCode, b.StartTime, b.EndTime, b.Status,
       a.DecisionNote
FROM dbo.BookingRequest b
LEFT JOIN dbo.Approval a ON a.BookingID = b.BookingID
WHERE b.SpaceCode = 'TEST-CC-A'
ORDER BY b.StartTime;
GO
