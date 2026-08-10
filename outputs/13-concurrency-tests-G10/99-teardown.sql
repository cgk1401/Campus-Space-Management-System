-- =====================================================================
-- 13 — Concurrency Tests / 99-teardown.sql
-- =====================================================================
-- Final cleanup: removes ALL Step 13 test data (both test spaces and test
-- users) and drops the test harness objects (TT_Concurrency_Control,
-- tt_SetSignal, tt_WaitSignal). Run in any window after the demos are done
-- so no test data persists into the Step 14 dataset.
--
-- The Step 12 objects (fn_BookingConflictCount, usp_ApproveBooking_Auto,
-- usp_ApproveBooking_Manual) are part of the delivered schema and are NOT
-- dropped here.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

-- ---- delete all test data (dependency order) -------------------------------
DELETE FROM dbo.BookingAcknowledgement
WHERE BookingID IN (SELECT BookingID FROM dbo.BookingRequest
                    WHERE SpaceCode IN ('TEST-CC-A', 'TEST-CC-B'));

DELETE FROM dbo.Approval
WHERE BookingID IN (SELECT BookingID FROM dbo.BookingRequest
                    WHERE SpaceCode IN ('TEST-CC-A', 'TEST-CC-B'));

DELETE FROM dbo.BookingRequest
WHERE SpaceCode IN ('TEST-CC-A', 'TEST-CC-B');

DELETE FROM dbo.MaintenanceRecord
WHERE SpaceCode IN ('TEST-CC-A', 'TEST-CC-B');

DELETE FROM dbo.[Space]
WHERE SpaceCode IN ('TEST-CC-A', 'TEST-CC-B');

DELETE FROM dbo.[User]
WHERE Email LIKE 'test.%@campus.test';

-- ---- drop the test harness --------------------------------------------------
DROP PROCEDURE IF EXISTS dbo.tt_SetSignal;
DROP PROCEDURE IF EXISTS dbo.tt_WaitSignal;
DROP TABLE IF EXISTS dbo.TT_Concurrency_Control;

PRINT '99-teardown.sql done: all Step 13 test data removed, test helpers dropped.';
GO
