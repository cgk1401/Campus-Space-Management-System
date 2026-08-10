-- =====================================================================
-- 13 — Concurrency Tests / Scenario B / B2b-mitigated-session2.sql
-- =====================================================================
-- WINDOW 2 = T2 (MITIGATED, MANUAL path) — Step 11 §3.2 / Step 12
-- usp_ApproveBooking_Manual.
--   Runs the REAL Step-12 manual-approval procedure for B4. It blocks on
--   T1's anchor (the SAME Space anchor the auto path holds) until T1
--   commits, then its overlap check finally sees the committed instant B3
--   and REFUSES with error 51009. B4 stays Pending.
--
-- HOW TO RUN: Window 2, ~2-3 s after B2a starts in Window 1.
--
-- EXPECTED OUTCOME: T2 waits ~30 s, then SSMS shows
--   Msg 51009, Level 16: Overlapping approved booking exists on this space (BR21).
-- That error IS the success criterion (BR21 holds).
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

DECLARE @B4     INT;
DECLARE @StaffB INT;

SELECT @B4     = BookingID FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-B'
                 AND StartTime = '2026-09-08T10:00:00'
                 AND Status = 'Pending';
SELECT @StaffB = UserID    FROM dbo.[User]  WHERE Email = 'test.staff.b@campus.test';

PRINT 'B2 T2 attempting to approve B4 via usp_ApproveBooking_Manual (expect to block on anchor)...';

EXEC dbo.usp_ApproveBooking_Manual
    @BookingID     = @B4,
    @SpaceCode     = N'TEST-CC-B',
    @ApproverID    = @StaffB,
    @DecisionNote  = N'[Step13 B mitigated] T2 approves B4.';

PRINT 'B2 T2 completed without error (UNEXPECTED if T1 was holding the anchor).';
GO
