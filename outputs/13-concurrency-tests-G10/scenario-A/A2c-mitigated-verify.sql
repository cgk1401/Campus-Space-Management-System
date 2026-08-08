-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A2c-mitigated-verify.sql
-- =====================================================================
-- PASS/FAIL check for the MITIGATED demo.
-- Counts approved bookings that participate in at least one overlap on the
-- test space (BR21 offender count).
--
-- EXPECTED: 0  (only B1 09:00-11:00 is Approved; B2 10:00-12:00 stayed
--               Pending after error 51009) -> BR21 HOLDS.
-- This is the "after-fix" proof that the Step 12 solution is EFFECTIVE.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

PRINT '--- PASS/FAIL: BR21 overlap offender count (expect 0 = BR21 holds) ---';
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
