-- =====================================================================
-- 13 — Concurrency Tests / Scenario B / B1b-unmitigated-session2.sql
-- =====================================================================
-- WINDOW 2 = T2 (MANUAL approval path, raw ad-hoc SQL, NO anchor lock) —
-- Step 11 §3.1 timeline.
--   Step 1: overlap check on (TEST-CC-B, 10:00-11:00) -> 0 -> PASS
--           (runs BEFORE B3 is inserted by T1)
--   Step 5: UPDATE B4 -> Approved + Approval row; COMMIT
-- The check happens while B3 does not exist yet, so the later-committed B3
-- is invisible to it -> phantom race.
--
-- HOW TO RUN: Window 2, after B1a printed "Start B1b in Window 2 now".
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;                              -- no dangling transaction on error
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DECLARE @B4     INT;
DECLARE @StaffB INT;

SELECT @B4     = BookingID FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-B' AND StartTime = '2026-09-08T10:00:00';
SELECT @StaffB = UserID    FROM dbo.[User]  WHERE Email = 'test.staff.b@campus.test';

BEGIN TRAN;

    -- Step 1: check runs while B3 does NOT exist -> 0 -> PASS (phantom).
    DECLARE @Overlap INT =
        (SELECT COUNT(*) FROM dbo.BookingRequest
         WHERE  SpaceCode = 'TEST-CC-B'
           AND  Status IN ('Approved','CheckedIn','Completed','NoShow')
           AND  StartTime < '2026-09-08T11:00:00'
           AND  EndTime   > '2026-09-08T10:00:00');

    PRINT 'B1 T2 check: overlapping approved = ' + CAST(@Overlap AS VARCHAR(10))
        + '  (B3 not created yet -> expect 0 -> PASS -> RACE!)';

    -- Signal T1 that the (phantom-blind) check is done (T2's own row Id 2);
    -- wait for T1 to commit B3, THEN approve B4 - exactly the Step 11 §3.1
    -- interleave (T1's signal arrives on row Id 12).
    EXEC dbo.tt_SetSignal 2, N't2_checked';
    EXEC dbo.tt_WaitSignal 12, N't1_committed', 120;

    -- Step 5: approve B4 (the phantom B3 is committed now, but T2's check
    -- already ran - READ COMMITTED sees only what existed at check time).
    UPDATE dbo.BookingRequest SET Status = 'Approved' WHERE BookingID = @B4;

    INSERT INTO dbo.Approval (BookingID, ApproverID, DecisionTime, DecisionNote)
    VALUES (@B4, @StaffB, SYSUTCDATETIME(),
            N'[Step13 B unmitigated] T2 manual approval written WITHOUT anchor lock.');

COMMIT TRAN;

EXEC dbo.tt_SetSignal 2, N't2_done';   -- informational; same row T2 already owns

PRINT 'B1 T2 COMMITTED. B4 approved; B3 (instant) already approved -> BR21 violated.';
GO
