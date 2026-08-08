-- =====================================================================
-- 13 — Concurrency Tests / Scenario B / B2a-mitigated-session1.sql
-- =====================================================================
-- WINDOW 1 = T1 (MITIGATED, INSTANT path) — Step 11 §3.2 / Step 12
-- usp_ApproveBooking_Auto.
--   Runs the REAL Step-12 auto-approval procedure (creates B3 Approved +
--   Approval by system actor -1) inside an outer transaction. The procedure
--   takes the SAME Space anchor as the manual path (UPDLOCK, HOLDLOCK);
--   the outer transaction holds that anchor ~30 s so T2 genuinely blocks.
--
-- HOW TO RUN: Window 1. ~2-3 s later run B2b-mitigated-session2.sql in
-- Window 2. During the WAITFOR DELAY pause, run evidence-blocking.sql in
-- THIS window to capture the blocking proof.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

DECLARE @Student        INT;
DECLARE @BookingID      INT;
DECLARE @AdvisoryCount  INT;

SELECT @Student = UserID FROM dbo.[User] WHERE Email = 'test.student@campus.test';

BEGIN TRAN;

    -- REAL Step-12 auto-approval path: acquires the SAME anchor
    -- (UPDLOCK, HOLDLOCK on the TEST-CC-B Space row) that the manual path
    -- uses, so the instant and manual paths are interchangeable (Step 11 §3.2).
    EXEC dbo.usp_ApproveBooking_Auto
        @RequesterID             = @Student,
        @SpaceCode               = N'TEST-CC-B',
        @StartTime               = '2026-09-08T09:30:00',
        @EndTime                 = '2026-09-08T10:30:00',
        @Purpose                 = N'Meeting',
        @ExpectedParticipants    = 8,
        @EligibleForAutoApproval = 1,
        @BookingID               = @BookingID OUTPUT,
        @AdvisoryCount           = @AdvisoryCount OUTPUT;

    PRINT 'B2 T1 auto-approved instant booking (BookingID = ' + CAST(@BookingID AS VARCHAR(10))
        + ', AdvisoryCount = ' + CAST(@AdvisoryCount AS VARCHAR(10)) + ') - Space anchor HELD.';
    PRINT 'Start B2b in Window 2 NOW, then run evidence-blocking.sql here during the pause.';

    WAITFOR DELAY '00:00:30';   -- T2 must be started within ~3 s; it will block on the anchor

COMMIT TRAN;

PRINT 'B2 T1 COMMITTED - anchor released. Window 2 should now show error 51009.';
GO
