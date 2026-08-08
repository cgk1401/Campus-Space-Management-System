-- =====================================================================
-- 13 — Concurrency Tests / Scenario B / B0-setup.sql
-- =====================================================================
-- Scenario B (Step 11 §3): an auto-approval (instant booking) racing a
-- manual staff approval on the same space. Prepares dedicated test data on
-- space TEST-CC-B:
--   student -> requester of B3 (created by the instant path) and of B4
--   staffB  -> manually approves B4 (10:00-11:00)
--   B3 (09:30-10:30) does NOT exist yet - the instant path creates it.
--   B4 (10:00-11:00) is pre-created Pending. They overlap at 10:00-10:30.
-- All inserts are guarded so the file is safe to re-run (it also resets
-- the scenario-B interleave channel).
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

-- ---- test users (guarded) --------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.[User] WHERE Email = 'test.staff.b@campus.test')
    INSERT INTO dbo.[User] (FullName, Email, PhoneNumber, Role, Department, AccountStatus)
    VALUES (N'Test Staff B', 'test.staff.b@campus.test', NULL, N'FacilityStaff', N'Testing', N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.[User] WHERE Email = 'test.student@campus.test')
    INSERT INTO dbo.[User] (FullName, Email, PhoneNumber, Role, Department, AccountStatus)
    VALUES (N'Test Student', 'test.student@campus.test', NULL, N'Student', N'Testing', N'Active');

-- ---- test space (guarded) --------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.[Space] WHERE SpaceCode = 'TEST-CC-B')
    INSERT INTO dbo.[Space] (SpaceCode, SpaceName, SpaceType, Building, Floor, RoomNumber, Capacity, CurrentStatus, UsagePolicy)
    VALUES (N'TEST-CC-B', N'Test Concurrency Space B', N'MeetingRoom',
            N'Test Building B', 1, N'TB01', 20, N'Available',
            N'Step 13 test-only space. Never book this for real events.');

-- ---- pending booking B4 (guarded) ------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-B' AND StartTime = '2026-09-08T10:00:00')
    INSERT INTO dbo.BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
    SELECT u.UserID, N'TEST-CC-B', '2026-09-08T10:00:00', '2026-09-08T11:00:00', N'Meeting', 8, N'Pending'
    FROM dbo.[User] u WHERE u.Email = 'test.student@campus.test';

-- ---- reset the scenario-B interleave channel (T2 = Id 2, T1 = Id 12) --------
DELETE FROM dbo.TT_Concurrency_Control WHERE Id IN (2, 12);
GO

-- ---- show what is ready -----------------------------------------------------
SELECT b.BookingID, b.SpaceCode, b.StartTime, b.EndTime, b.Status,
       u.Email AS Requester
FROM dbo.BookingRequest b
JOIN dbo.[User] u ON u.UserID = b.RequesterID
WHERE b.SpaceCode = 'TEST-CC-B'
ORDER BY b.StartTime;
GO
