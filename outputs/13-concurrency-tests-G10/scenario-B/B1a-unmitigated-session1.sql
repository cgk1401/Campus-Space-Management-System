-- =====================================================================
-- 13 — Concurrency Tests / Scenario B / B1a-unmitigated-session1.sql
-- =====================================================================
-- WINDOW 1 = T1 (INSTANT / AUTO path, raw ad-hoc SQL, NO anchor lock) —
-- Step 11 §3.1 timeline.
--   Step 2: overlap check on (TEST-CC-B, 09:30-10:30) -> 0 -> PASS
--   Step 3: INSERT B3 (Status = 'Approved')        (the phantom row)
--   Step 4: INSERT Approval (ApproverID = -1, system actor); COMMIT
-- B3 is created only AFTER T2's manual check has already run (see B1b),
-- so T2 can never see it -> phantom race.
--
-- HOW TO RUN: Window 1. It waits for T2's check; when it prints
-- "Start B1b in Window 2 now", run B1b-unmitigated-session2.sql.
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;                              -- no dangling transaction on error
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- the vulnerable default

DECLARE @Student INT;
DECLARE @B3      INT;

SELECT @Student = UserID FROM dbo.[User] WHERE Email = 'test.student@campus.test';

-- Wait until T2 (the manual approver) has run its check with B3 absent
-- (T2's own control row Id 2).
EXEC dbo.tt_WaitSignal 2, N't2_checked', 120;
PRINT 'B1 T2 check is done (B3 did not exist then). T1 now creates B3.';

BEGIN TRAN;

    -- Step 2: T1's own check (nothing approved yet on TEST-CC-B).
    DECLARE @Overlap INT =
        (SELECT COUNT(*) FROM dbo.BookingRequest
         WHERE  SpaceCode = 'TEST-CC-B'
           AND  Status IN ('Approved','CheckedIn','Completed','NoShow')
           AND  StartTime < '2026-09-08T10:30:00'
           AND  EndTime   > '2026-09-08T09:30:00');

    PRINT 'B1 T1 check: overlapping approved = ' + CAST(@Overlap AS VARCHAR(10))
        + '  (expect 0 -> PASS)';

    -- Step 3: instant-book B3 as already Approved (raw ad-hoc, no anchor).
    INSERT INTO dbo.BookingRequest (RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status)
    VALUES (@Student, N'TEST-CC-B', '2026-09-08T09:30:00', '2026-09-08T10:30:00',
            N'Meeting', 8, N'Approved');

    SET @B3 = SCOPE_IDENTITY();

    -- Step 4: Approval by the system actor (UserID = -1), mirroring the
    -- schema-identical auto path (Step 11 §1.1 / Step 8 D4).
    INSERT INTO dbo.Approval (BookingID, ApproverID, DecisionTime, DecisionNote)
    VALUES (@B3, -1, SYSUTCDATETIME(),
            N'[Step13 B unmitigated] T1 instant booking - raw ad-hoc WITHOUT anchor lock.');

COMMIT TRAN;

EXEC dbo.tt_SetSignal 12, N't1_committed';   -- T1's own control row Id 12

PRINT 'B1 T1 COMMITTED (instant booking B3, BookingID = ' + CAST(@B3 AS VARCHAR(10))
    + '). B3 was a phantom for T2 -> BR21 violated once T2 commits.';
GO
