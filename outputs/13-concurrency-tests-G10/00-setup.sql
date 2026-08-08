-- =====================================================================
-- 13 — Concurrency Tests / 00-setup.sql
-- =====================================================================
-- Role   : Senior Database Administrator
-- DBMS   : Microsoft SQL Server (T-SQL)
-- Target : CampusSpaceManagement (Step 05 + Step 10 + Step 12 applied)
-- Purpose: One-time test harness for the Step 13 demos.
--           * dbo.TT_Concurrency_Control  - tiny signal table used by the
--             two sessions to force the exact Step 11 interleavings.
--           * dbo.tt_SetSignal / dbo.tt_WaitSignal - signal primitives.
--
-- Safe to re-run (guarded creates). Cleaned up by 99-teardown.sql.
-- =====================================================================

USE CampusSpaceManagement;
GO

IF OBJECT_ID('dbo.TT_Concurrency_Control', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TT_Concurrency_Control (
        Id       INT          NOT NULL,
        Signal   NVARCHAR(50) NOT NULL,
        SetAt    DATETIME2    NOT NULL
            CONSTRAINT DF_TT_Concurrency_Control_SetAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TT_Concurrency_Control PRIMARY KEY (Id)
    );
END
GO

-- ---------------------------------------------------------------------
-- tt_SetSignal : record that session has reached checkpoint [Signal]
--                for interleave id @Id.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.tt_SetSignal
    @Id     INT,
    @Signal NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.TT_Concurrency_Control
    SET    Signal = @Signal,
           SetAt  = SYSUTCDATETIME()
    WHERE  Id = @Id;

    IF @@ROWCOUNT = 0
        INSERT INTO dbo.TT_Concurrency_Control (Id, Signal)
        VALUES (@Id, @Signal);
END
GO

-- ---------------------------------------------------------------------
-- tt_WaitSignal : block until the session signals [Signal] for interleave
--                 id @Id, or @TimeoutSec elapses (then THROW so a stranded
--                 demo fails loudly instead of hanging forever).
--
-- IMPORTANT: the read is deliberately DIRTY (READUNCOMMITTED). The racing
-- session that writes the signal is often still mid-transaction (that is
-- the whole point of the forced interleave), so the waiter must be able to
-- see the uncommitted signal row. The control table is coordination-only;
-- dirty reads here cannot corrupt application data.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.tt_WaitSignal
    @Id         INT,
    @Signal     NVARCHAR(50),
    @TimeoutSec INT = 120
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Deadline DATETIME2 = DATEADD(SECOND, @TimeoutSec, SYSUTCDATETIME());

    WHILE SYSUTCDATETIME() < @Deadline
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.TT_Concurrency_Control WITH (READUNCOMMITTED)
                   WHERE Id = @Id AND Signal = @Signal)
            RETURN 0;
        WAITFOR DELAY '00:00:00.200';   -- 200 ms poll
    END;

    THROW 50999, 'Test timeout: interleaving signal was not received.', 1;
END
GO

-- ---------------------------------------------------------------------
-- Signal Id convention: each direction of an interleave gets its OWN Id so
-- the two sessions never write the same control row (which would make one
-- session block on the other's uncommitted signal write -> self-deadlock).
--   Scenario A: T1 -> Id 1,  T2 -> Id 11
--   Scenario B: T2 -> Id 2,  T1 -> Id 12
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- Reset both interleave channels so a prior run cannot pre-set a signal
-- and silently skip the forced ordering on the next run.
-- ---------------------------------------------------------------------
DELETE FROM dbo.TT_Concurrency_Control;
GO

PRINT '00-setup.sql applied: TT_Concurrency_Control + tt_SetSignal + tt_WaitSignal ready.';
PRINT 'Interleave channels reset.';
GO
