-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A2b-mitigated-session2.sql
-- =====================================================================
-- WINDOW 2 = T2 (MITIGATED) — Step 11 §2.2 / Step 12 usp_ApproveBooking_Manual.
--   Runs the REAL Step-12 procedure for B2. It blocks on T1's anchor
--   (UPDLOCK, HOLDLOCK on the TEST-CC-A Space row) until T1 commits, then
--   its overlap check finally sees the committed B1 and REFUSES with
--   error 51009 (Overlapping approved booking exists on this space (BR21)).
--   The procedure rolls back, so B2 stays Pending.
--
-- HOW TO RUN: Window 2, ~2-3 s after A2a starts in Window 1.
--
-- EXPECTED OUTCOME: T2 waits ~30 s, then SSMS shows
--   Msg 51009, Level 16: Overlapping approved booking exists on this space (BR21).
-- That error IS the success criterion (BR21 holds).
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

DECLARE @B2     INT;
DECLARE @StaffB INT;

SELECT @B2     = BookingID FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-A'
                 AND StartTime = '2026-09-07T10:00:00'
                 AND Status = 'Pending';
SELECT @StaffB = UserID    FROM dbo.[User]  WHERE Email = 'test.staff.b@campus.test';

PRINT 'A2 T2 attempting to approve B2 via usp_ApproveBooking_Manual (expect to block on anchor)...';

EXEC dbo.usp_ApproveBooking_Manual
    @BookingID     = @B2,
    @SpaceCode     = N'TEST-CC-A',
    @ApproverID    = @StaffB,
    @DecisionNote  = N'[Step13 A mitigated] T2 approves B2.';

PRINT 'A2 T2 completed without error (UNEXPECTED if T1 was holding the anchor).';
GO
