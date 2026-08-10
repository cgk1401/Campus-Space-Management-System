-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A0-setup.sql
-- =====================================================================
-- Scenario A (Step 11 §2): two manual staff approvals racing on the same
-- space. Prepares dedicated test data on space TEST-CC-A:
--   staffA  -> approves B1 (09:00-11:00)
--   staffB  -> approves B2 (10:00-12:00)   (overlaps B1 at 10:00-11:00)
--   student -> requester of B1 and B2
-- All inserts are guarded so the file is safe to re-run (it also resets
-- the scenario-A interleave channel).
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

-- ---- test users (guarded) -------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.[User] WHERE Email = 'test.staff.a@campus.test')
    INSERT INTO dbo.[User] (FullName, Email, PhoneNumber, Role, Department, AccountStatus)
    VALUES (N'Test Staff A', 'test.staff.a@campus.test', NULL, N'FacilityStaff', N'Testing', N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.[User] WHERE Email = 'test.staff.b@campus.test')
    INSERT INTO dbo.[User] (FullName, Email, PhoneNumber, Role, Department, AccountStatus)
    VALUES (N'Test Staff B', 'test.staff.b@campus.test', NULL, N'FacilityStaff', N'Testing', N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.[User] WHERE Email = 'test.student@campus.test')
    INSERT INTO dbo.[User] (FullName, Email, PhoneNumber, Role, Department, AccountStatus)
    VALUES (N'Test Student', 'test.student@campus.test', NULL, N'Student', N'Testing', N'Active');

-- ---- test space (guarded) --------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.[Space] WHERE SpaceCode = 'TEST-CC-A')
    INSERT INTO dbo.[Space] (SpaceCode, SpaceName, SpaceType, Building, Floor, RoomNumber, Capacity, CurrentStatus, UsagePolicy)
    VALUES (N'TEST-CC-A', N'Test Concurrency Space A', N'MeetingRoom',
            N'Test Building A', 1, N'TA01', 20, N'Available',
            N'Step 13 test-only space. Never book this for real events.');

-- ---- pending bookings B1 and B2 (guarded) ----------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-A' AND StartTime = '2026-09-07T09:00:00')
    INSERT INTO dbo.BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
    SELECT u.UserID, N'TEST-CC-A', '2026-09-07T09:00:00', '2026-09-07T11:00:00', N'Lecture', 15, N'Pending'
    FROM dbo.[User] u WHERE u.Email = 'test.student@campus.test';

IF NOT EXISTS (SELECT 1 FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-A' AND StartTime = '2026-09-07T10:00:00')
    INSERT INTO dbo.BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
    SELECT u.UserID, N'TEST-CC-A', '2026-09-07T10:00:00', '2026-09-07T12:00:00', N'Lecture', 15, N'Pending'
    FROM dbo.[User] u WHERE u.Email = 'test.student@campus.test';

-- ---- reset the scenario-A interleave channel (T1 = Id 1, T2 = Id 11) --------
DELETE FROM dbo.TT_Concurrency_Control WHERE Id IN (1, 11);
GO

-- ---- show what is ready -----------------------------------------------------
SELECT b.BookingID, b.SpaceCode, b.StartTime, b.EndTime, b.Status,
       u.Email AS Requester
FROM dbo.BookingRequest b
JOIN dbo.[User] u ON u.UserID = b.RequesterID
WHERE b.SpaceCode = 'TEST-CC-A'
ORDER BY b.StartTime;
GO
