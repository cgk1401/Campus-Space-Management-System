-- =====================================================================
-- 13 — Concurrency Tests / Scenario A / A1b-unmitigated-session2.sql
-- =====================================================================
-- WINDOW 2 = T2 (raw ad-hoc SQL, NO anchor lock) — Step 11 §2.1 timeline.
--   Step 2: overlap check on (TEST-CC-A, 10:00-12:00) -> 0 -> PASS
--           (runs AFTER T1's uncommitted UPDATE, but READ COMMITTED
--            cannot see it)
--   Step 4: UPDATE B2 -> Approved  + Approval row
--   Step 6: COMMIT (before T1)
--
-- HOW TO RUN: Window 2, after A1a printed "Start A1b in Window 2 now".
-- =====================================================================

USE CampusSpaceManagement;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;                              -- no dangling transaction on error
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DECLARE @B2     INT;
DECLARE @StaffB INT;

SELECT @B2     = BookingID FROM dbo.BookingRequest
               WHERE SpaceCode = 'TEST-CC-A' AND StartTime = '2026-09-07T10:00:00';
SELECT @StaffB = UserID    FROM dbo.[User]  WHERE Email = 'test.staff.b@campus.test';

-- Wait until T1's uncommitted approval exists (signal on T1's own row Id 1).
EXEC dbo.tt_WaitSignal 1, N't1_updated', 120;

BEGIN TRAN;

    -- Step 2: T1's change is UNCOMMITTED -> invisible under READ COMMITTED.
    -- READPAST emulates a check that skips rows currently being modified by
    -- other transactions instead of blocking on them; together with READ
    -- COMMITTED this is the classic insufficient application-level check:
    -- it sees only committed state and never the in-flight write.
    DECLARE @Overlap INT =
        (SELECT COUNT(*) FROM dbo.BookingRequest WITH (READPAST)
         WHERE  SpaceCode = 'TEST-CC-A'
           AND  Status IN ('Approved','CheckedIn','Completed','NoShow')
           AND  StartTime < '2026-09-07T12:00:00'
           AND  EndTime   > '2026-09-07T10:00:00');

    PRINT 'A1 T2 check: overlapping approved = ' + CAST(@Overlap AS VARCHAR(10))
        + '  (T1 B1 uncommitted + READPAST -> expect 0 -> PASS -> RACE!)';

    -- Step 4: approve B2 and commit BEFORE T1.
    UPDATE dbo.BookingRequest SET Status = 'Approved' WHERE BookingID = @B2;

    INSERT INTO dbo.Approval (BookingID, ApproverID, DecisionTime, DecisionNote)
    VALUES (@B2, @StaffB, SYSUTCDATETIME(),
            N'[Step13 A unmitigated] T2 raw approval written WITHOUT anchor lock.');

COMMIT TRAN;

-- Step 6: T2 committed first; unblock T1 (T2's own control row Id 11).
EXEC dbo.tt_SetSignal 11, N't2_committed';

PRINT 'A1 T2 COMMITTED. B2 is approved; T1 will also commit -> BR21 violated.';
GO
