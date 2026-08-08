-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A1a-unmitigated-session1.sql
-- =====================================================================
-- WINDOW 1 = T1 (raw ad-hoc SQL, NO anchor lock) — Step 11 §2.1 timeline.
--   Step 1: overlap check on (TEST-CC-A, 09:00-11:00) -> 0 -> PASS
--   Step 3: UPDATE B1 -> Approved (UNCOMMITTED)        + Approval row
--   Step 5: wait for T2 to commit, then COMMIT
-- The uncommitted UPDATE is deliberately held while T2 runs its own check,
-- reproducing the lost-update race under READ COMMITTED.
--
-- HOW TO RUN: Window 1. When it prints "Start A1b in Window 2 now", run
-- A1b-unmitigated-session2.sql in Window 2.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;                              -- no dangling transaction on error
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- the vulnerable default (Step 11 §1.2)

DECLARE @B1    INT;
DECLARE @StaffA INT;

SELECT @B1    = BookingID FROM dbo.BookingRequest
              WHERE SpaceCode = 'TEST-CC-A' AND StartTime = '2026-09-07T09:00:00';
SELECT @StaffA = UserID    FROM dbo.[User]  WHERE Email = 'test.staff.a@campus.test';

BEGIN TRAN;

    -- Step 1: application-style overlap check WITHOUT the anchor lock.
    DECLARE @Overlap INT =
        (SELECT COUNT(*) FROM dbo.BookingRequest
         WHERE  SpaceCode = 'TEST-CC-A'
           AND  Status IN ('Approved','CheckedIn','Completed','NoShow')
           AND  StartTime < '2026-09-07T11:00:00'
           AND  EndTime   > '2026-09-07T09:00:00');

    PRINT 'A1 T1 check: overlapping approved = ' + CAST(@Overlap AS VARCHAR(10))
        + '  (expect 0 -> PASS, nothing approved yet)';

    -- Step 3: approve B1 but DO NOT COMMIT yet.
    UPDATE dbo.BookingRequest SET Status = 'Approved' WHERE BookingID = @B1;

    INSERT INTO dbo.Approval (BookingID, ApproverID, DecisionTime, DecisionNote)
    VALUES (@B1, @StaffA, SYSUTCDATETIME(),
            N'[Step13 A unmitigated] T1 raw approval written WITHOUT anchor lock.');

    -- Tell T2 (via its OWN control row Id 1) that T1 has written but not committed.
    EXEC dbo.tt_SetSignal 1, N't1_updated';
    PRINT 'A1 T1 updated B1 (UNCOMMITTED).  Start A1b in Window 2 now.';

    -- Step 5: wait for T2 to run its check + commit (signal on row Id 11),
    --         THEN commit.
    EXEC dbo.tt_WaitSignal 11, N't2_committed', 120;
    PRINT 'A1 T2 committed first. T1 commits now.';

COMMIT TRAN;

PRINT 'A1 T1 COMMITTED. Run A1c-unmitigated-verify.sql to confirm BR21 was violated.';
GO
