-- =====================================================================
-- 13 — Concurrency Tests / Scenario B / B3-cleanup.sql
-- =====================================================================
-- Removes every trace of the Scenario B test on TEST-CC-B (Approval rows,
-- acknowledgements, booking requests, the space, and the test users).
-- Run after the unmitigated verify (B1c) and again after the mitigated
-- verify (B2c) before re-running B0-setup.sql. So no test data leaks into
-- the Step 14 dataset.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

DELETE FROM dbo.BookingAcknowledgement
WHERE BookingID IN (SELECT BookingID FROM dbo.BookingRequest WHERE SpaceCode = 'TEST-CC-B');

DELETE FROM dbo.Approval
WHERE BookingID IN (SELECT BookingID FROM dbo.BookingRequest WHERE SpaceCode = 'TEST-CC-B');

DELETE FROM dbo.BookingRequest WHERE SpaceCode = 'TEST-CC-B';

DELETE FROM dbo.[Space] WHERE SpaceCode = 'TEST-CC-B';

DELETE FROM dbo.[User]
WHERE Email IN ('test.staff.a@campus.test', 'test.staff.b@campus.test', 'test.student@campus.test');

DELETE FROM dbo.TT_Concurrency_Control WHERE Id IN (2, 12);

PRINT 'B3-cleanup.sql done: TEST-CC-B test data removed.';
GO
