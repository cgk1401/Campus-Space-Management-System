-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A2a-mitigated-session1.sql
-- =====================================================================
-- WINDOW 1 = T1 (MITIGATED) — Step 11 §2.2 / Step 12 usp_ApproveBooking_Manual.
--   Runs the REAL Step-12 procedure for B1 inside an outer transaction.
--   The procedure takes the anchor lock (UPDLOCK, HOLDLOCK on the Space row);
--   the outer transaction keeps that anchor held for ~30 s so T2 genuinely
--   blocks (locks acquired inside a nested transaction are held until the
--   OUTER COMMIT).
--
-- HOW TO RUN: Window 1. ~2-3 s later run A2b-mitigated-session2.sql in
-- Window 2. During the WAITFOR DELAY pause, run evidence-blocking.sql in
-- THIS window to capture the blocking proof.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;

DECLARE @B1     INT;
DECLARE @StaffA INT;

SELECT @B1     = BookingID FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-A'
                 AND StartTime = '2026-09-07T09:00:00'
                 AND Status = 'Pending';
SELECT @StaffA = UserID    FROM dbo.[User]  WHERE Email = 'test.staff.a@campus.test';

BEGIN TRAN;

    -- REAL Step-12 procedure: acquires the Space anchor (UPDLOCK, HOLDLOCK),
    -- overlap-checks, approves B1, writes Approval. The outer transaction
    -- holds the anchor until we COMMIT.
    EXEC dbo.usp_ApproveBooking_Manual
        @BookingID     = @B1,
        @SpaceCode     = N'TEST-CC-A',
        @ApproverID    = @StaffA,
        @DecisionNote  = N'[Step13 A mitigated] T1 approves B1 via usp_ApproveBooking_Manual.';

    PRINT 'A2 T1 approved B1 via usp_ApproveBooking_Manual - Space anchor HELD.';
    PRINT 'Start A2b in Window 2 NOW, then run evidence-blocking.sql here during the pause.';

    WAITFOR DELAY '00:00:30';   -- T2 must be started within ~3 s; it will block on the anchor

COMMIT TRAN;

PRINT 'A2 T1 COMMITTED - anchor released. Window 2 should now show error 51009.';
GO
