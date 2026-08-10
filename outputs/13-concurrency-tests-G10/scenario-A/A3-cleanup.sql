-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A3-cleanup.sql
-- =====================================================================
-- Removes every trace of the Scenario A test on TEST-CC-A (Approval rows,
-- acknowledgements, booking requests, the space, and the test users).
-- Run after the unmitigated verify (A1c) and again after the mitigated
-- verify (A2c) before re-running A0-setup.sql. So no test data leaks into
-- the Step 14 dataset.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

DELETE FROM dbo.BookingAcknowledgement
WHERE BookingID IN (SELECT BookingID FROM dbo.BookingRequest WHERE SpaceCode = 'TEST-CC-A');

DELETE FROM dbo.Approval
WHERE BookingID IN (SELECT BookingID FROM dbo.BookingRequest WHERE SpaceCode = 'TEST-CC-A');

DELETE FROM dbo.BookingRequest WHERE SpaceCode = 'TEST-CC-A';

DELETE FROM dbo.[Space] WHERE SpaceCode = 'TEST-CC-A';

DELETE FROM dbo.[User]
WHERE Email IN ('test.staff.a@campus.test', 'test.staff.b@campus.test', 'test.student@campus.test');

DELETE FROM dbo.TT_Concurrency_Control WHERE Id IN (1, 11);

PRINT 'A3-cleanup.sql done: TEST-CC-A test data removed.';
GO
