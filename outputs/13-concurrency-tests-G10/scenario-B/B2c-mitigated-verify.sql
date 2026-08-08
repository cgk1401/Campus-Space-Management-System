-- =====================================================================
-- 13 — Concurrency Tests / Scenario B / B2c-mitigated-verify.sql
-- =====================================================================
-- PASS/FAIL check for the MITIGATED demo.
-- Counts approved bookings that participate in at least one overlap on the
-- test space (BR21 offender count).
--
-- EXPECTED: 0  (only B3 09:30-10:30 is Approved; B4 10:00-11:00 stayed
--               Pending after error 51009) -> BR21 HOLDS.
-- Proves the Step 12 fix is EFFECTIVE for the phantom race between the
-- instant path and the manual path.
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
WHERE a.SpaceCode = 'TEST-CC-B'
  AND a.Status IN ('Approved','CheckedIn','Completed','NoShow')
  AND b.Status IN ('Approved','CheckedIn','Completed','NoShow');

PRINT '--- Final table state on TEST-CC-B ---';
SELECT b.BookingID, b.SpaceCode, b.StartTime, b.EndTime, b.Status,
       a.DecisionNote
FROM dbo.BookingRequest b
LEFT JOIN dbo.Approval a ON a.BookingID = b.BookingID
WHERE b.SpaceCode = 'TEST-CC-B'
ORDER BY b.StartTime;
GO
