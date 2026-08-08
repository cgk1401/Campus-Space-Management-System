-- =====================================================================
-- 12 — Concurrency Implementation (Phase 2)
-- =====================================================================
-- Role       : Senior Database Administrator (DBA)
-- DBMS       : Microsoft SQL Server (T-SQL)
-- Target DB  : CampusSpaceManagement  (Phase-1 schema + outputs/10 migration)
-- Purpose    : Implement the BR21 concurrency-prevention mechanism designed
--              in outputs/11-concurrency-design-G10.md.
--
-- INVARIANT (BR21): No two approved bookings may overlap on the same space,
--   regardless of whether they were created through instant (auto) approval
--   or staff approval, and regardless of concurrent operations.
--   "Occupying" statuses = Status IN ('Approved','CheckedIn','Completed',
--   'NoShow')  (assumption A-P2-5).
--
-- MECHANISM (from Step 11):
--   * Anchor-lock transaction: every booking writer FIRST acquires a lock on
--     the parent [Space] row keyed by SpaceCode, held to the end of the
--     transaction (HOLDLOCK), then performs the overlap check, then writes.
--   * Both the instant path and the manual path take the SAME anchor, so the
--     two transaction types are interchangeable (Step 11 §3.2) and the
--     phantom problem is eliminated.
--   * The critical section is kept SHORT: the anchor is acquired only after
--     the decision / eligibility has already been determined by the caller,
--     immediately before the overlap check + write (Step 11 §6). No human
--     think-time is spent holding the lock.
--
-- SERIALIZABLE FALLBACK (Step 11 §3.3) — NOT the default:
--   If a code path cannot guarantee anchor-first ordering, SERIALIZABLE can
--   be layered on by running `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;`
--   at the top of the affected procedure. Its broader key-range lock
--   footprint and higher deadlock risk are why it is not enabled here.
--
-- LOCK-ORDERING CONVENTION (Step 11 §6):
--   Space anchor first -> BookingRequest -> Approval / BookingAcknowledgement.
--   Any future transaction that updates MaintenanceRecord / Space.CurrentStatus
--   for an escalation must take the same Space anchor first to avoid deadlock.
--
-- IDEMPOTENT: uses CREATE OR ALTER (SQL Server 2016 SP1+).
-- SCOPE: only the two approval paths (instant + manual). No "before-fix"
--   variants and no test/demo scripts here — those belong to Step 13
--   (outputs/13-concurrency-tests-G10).
-- =====================================================================

USE CampusSpaceManagement;
GO

-- =====================================================================
-- Shared overlap logic (Step 12 directive 3)
-- Single source of truth for the BR21 predicate so the instant and manual
-- paths cannot drift apart.
-- Returns the number of occupying bookings on the same space that overlap
-- the half-open window [@StartTime, @EndTime).
-- =====================================================================
CREATE OR ALTER FUNCTION dbo.fn_BookingConflictCount
(
    @SpaceCode NVARCHAR(20),
    @StartTime DATETIME2,
    @EndTime   DATETIME2
)
RETURNS INT
AS
BEGIN
    RETURN
    (
        SELECT COUNT(*)
        FROM   dbo.BookingRequest
        WHERE  SpaceCode = @SpaceCode
          AND  Status IN ('Approved','CheckedIn','Completed','NoShow')
          AND  StartTime < @EndTime
          AND  EndTime   > @StartTime
    );
END;
GO

-- =====================================================================
-- INSTANT (AUTO) APPROVAL PATH  (Step 12 directive 1a)
-- Creates the booking AND approves it inside one atomic, anchor-locked
-- transaction. Called by the application only for requests that are
-- auto-approval-eligible (selected space types satisfying the usage policy;
-- eligibility is configuration — assumption A-P2-4 — signalled through
-- @EligibleForAutoApproval).
--   * Writes the Approval row with the non-human system actor
--     ApproverID = -1 (Step 8 D4; inserted in outputs/10) so the auto path
--     is schema-identical to the manual path (Step 11 §1.1).
--   * Records BR19 acknowledgements for every active advisory that overlaps
--     the booked window (acknowledgement is a booking-time prerequisite,
--     assumption A-P2-2).
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ApproveBooking_Auto
    @RequesterID            INT,
    @SpaceCode              NVARCHAR(20),
    @StartTime              DATETIME2,
    @EndTime                DATETIME2,
    @Purpose                NVARCHAR(30),
    @ExpectedParticipants   INT,
    @EligibleForAutoApproval BIT      = 1,
    @BookingID              INT      = NULL OUTPUT,
    @AdvisoryCount          INT      = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ---------- cheap, lock-free validation (before the critical section) ----------
    IF @RequesterID IS NULL OR @SpaceCode IS NULL
       OR @StartTime IS NULL OR @EndTime IS NULL
       OR @Purpose IS NULL OR @ExpectedParticipants IS NULL
        THROW 50001, 'All booking fields are required.', 1;

    IF @EndTime <= @StartTime
        THROW 50002, 'EndTime must be after StartTime (CK_BookingRequest_TimeRange).', 1;

    IF @ExpectedParticipants <= 0
        THROW 50003, 'ExpectedParticipants must be > 0 (CK_BookingRequest_ExpectedParticipants).', 1;

    IF @EligibleForAutoApproval = 0
        THROW 50004, 'Request does not satisfy the instant-approval eligibility (space type / usage policy).', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.[User] WHERE UserID = @RequesterID)
        THROW 50005, 'Requester does not exist.', 1;

    -- ---------- critical section ----------
    BEGIN TRY
        BEGIN TRAN;

            -- 1. ANCHOR LOCK: exclusive, held to the end of the transaction.
            --    Serialises every writer of this space; the manual path takes
            --    the identical anchor so both paths are interchangeable.
            DECLARE @StoredSpace  NVARCHAR(20);
            DECLARE @StoredStatus NVARCHAR(20);

            SELECT @StoredSpace  = SpaceCode,
                   @StoredStatus = CurrentStatus
            FROM   dbo.[Space] WITH (UPDLOCK, HOLDLOCK)
            WHERE  SpaceCode = @SpaceCode;

            IF @StoredSpace IS NULL
                THROW 50006, 'Space does not exist.', 1;

            -- 2. Space availability (Phase 1 BR3 — unchanged).
            IF @StoredStatus IN ('UnderMaintenance','TemporarilyClosed','Retired')
                THROW 50007, 'Space is not bookable (CurrentStatus).', 1;

            -- 3. BR18: an OPEN, OUT-OF-SERVICE maintenance record overlapping the
            --    window blocks the booking (Phase 2 refinement of Phase 1 BR4).
            IF EXISTS (
                SELECT 1
                FROM   dbo.MaintenanceRecord
                WHERE  SpaceCode = @SpaceCode
                  AND  ImpactLevel = 'OutOfService'
                  AND  Status IN ('Open','InProgress')
                  AND  StartTime < @EndTime
                  AND  (CompletionTime IS NULL OR CompletionTime > @StartTime)
            )
                THROW 50008, 'Space is out of service for the requested window (BR18).', 1;

            -- 4. BR21 overlap check — shared predicate, executed UNDER the anchor so
            --    the read reflects every committed writer of this space.
            IF dbo.fn_BookingConflictCount(@SpaceCode, @StartTime, @EndTime) > 0
                THROW 50009, 'Overlapping approved booking exists on this space (BR21).', 1;

            -- 5. Write the booking (already Approved) and the approval by the
            --    non-human system actor (UserID = -1).
            INSERT INTO dbo.BookingRequest
                (RequesterID, SpaceCode, StartTime, EndTime, Purpose,
                 ExpectedParticipants, Status)
            VALUES
                (@RequesterID, @SpaceCode, @StartTime, @EndTime, @Purpose,
                 @ExpectedParticipants, 'Approved');

            SET @BookingID = SCOPE_IDENTITY();

            INSERT INTO dbo.Approval
                (BookingID, ApproverID, DecisionTime, DecisionNote)
            VALUES
                (@BookingID, -1, SYSUTCDATETIME(),
                 N'Auto-approved at submission time (system actor).');

            -- 6. BR19: record the acknowledgement for EACH active advisory that
            --    overlaps the booked window (one row per (booking, advisory)).
            INSERT INTO dbo.BookingAcknowledgement
                (BookingID, MaintenanceID, AcknowledgedAt, AcknowledgedByUserID)
            SELECT @BookingID,
                   m.MaintenanceID,
                   SYSUTCDATETIME(),
                   @RequesterID
            FROM   dbo.MaintenanceRecord m
            WHERE  m.SpaceCode = @SpaceCode
              AND  m.ImpactLevel = 'Advisory'
              AND  m.Status IN ('Open','InProgress')
              AND  m.StartTime < @EndTime
              AND  (m.CompletionTime IS NULL OR m.CompletionTime > @StartTime);

            SET @AdvisoryCount = @@ROWCOUNT;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- MANUAL (STAFF) APPROVAL PATH  (Step 12 directive 1b)
-- Approves an existing PENDING booking inside an atomic, anchor-locked
-- transaction. The caller (staff UI) has already made the decision, so no
-- human think-time is spent holding the anchor (Step 11 §6).
-- @SpaceCode is supplied by the caller and verified against the booking so
-- that the anchor can be acquired FIRST (lock-ordering convention,
-- Step 11 §6), preventing deadlock with the maintenance-escalation
-- transaction that also takes the Space anchor first.
-- Rejection has no occupancy race (a rejected booking never occupies the
-- space), so it is not part of this BR21-critical path.
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ApproveBooking_Manual
    @BookingID           INT,
    @SpaceCode           NVARCHAR(20),
    @ApproverID          INT,
    @DecisionNote        NVARCHAR(MAX) = N'Approved by facility staff',
    @ApprovedBookingID   INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ---------- cheap, lock-free validation ----------
    IF @BookingID IS NULL OR @SpaceCode IS NULL OR @ApproverID IS NULL
        THROW 51001, 'BookingID, SpaceCode and ApproverID are required.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.[User] WHERE UserID = @ApproverID)
        THROW 51002, 'Approver does not exist.', 1;

    DECLARE @ReqSpaceCode NVARCHAR(20);
    DECLARE @StartTime    DATETIME2;
    DECLARE @EndTime      DATETIME2;
    DECLARE @Status       NVARCHAR(20);

    -- ---------- critical section ----------
    BEGIN TRY
        BEGIN TRAN;

            -- 1. ANCHOR LOCK first — identical to the auto path.
            DECLARE @StoredSpace  NVARCHAR(20);
            DECLARE @StoredStatus NVARCHAR(20);

            SELECT @StoredSpace  = SpaceCode,
                   @StoredStatus = CurrentStatus
            FROM   dbo.[Space] WITH (UPDLOCK, HOLDLOCK)
            WHERE  SpaceCode = @SpaceCode;

            IF @StoredSpace IS NULL
                THROW 51003, 'Space does not exist.', 1;

            -- 2. Read the request under the anchor and validate its state.
            SELECT @ReqSpaceCode = SpaceCode,
                   @StartTime    = StartTime,
                   @EndTime      = EndTime,
                   @Status       = Status
            FROM   dbo.BookingRequest
            WHERE  BookingID = @BookingID;

            IF @ReqSpaceCode IS NULL
                THROW 51004, 'Booking does not exist.', 1;

            IF @ReqSpaceCode <> @SpaceCode
                THROW 51005, 'Booking does not belong to the given space.', 1;

            IF @Status <> 'Pending'
                THROW 51006, 'Only Pending bookings can be approved.', 1;

            -- 3. Space availability re-checked at approval time (BR3).
            IF @StoredStatus IN ('UnderMaintenance','TemporarilyClosed','Retired')
                THROW 51007, 'Space is not bookable (CurrentStatus).', 1;

            -- 4. BR18: open out-of-service maintenance overlapping the window.
            IF EXISTS (
                SELECT 1
                FROM   dbo.MaintenanceRecord
                WHERE  SpaceCode = @SpaceCode
                  AND  ImpactLevel = 'OutOfService'
                  AND  Status IN ('Open','InProgress')
                  AND  StartTime < @EndTime
                  AND  (CompletionTime IS NULL OR CompletionTime > @StartTime)
            )
                THROW 51008, 'Space is out of service for the requested window (BR18).', 1;

            -- 5. BR21 overlap check — identical shared predicate, under the anchor.
            IF dbo.fn_BookingConflictCount(@SpaceCode, @StartTime, @EndTime) > 0
                THROW 51009, 'Overlapping approved booking exists on this space (BR21).', 1;

            -- 6. Approve the booking and write the decision record.
            UPDATE dbo.BookingRequest
            SET    Status = 'Approved'
            WHERE  BookingID = @BookingID;

            INSERT INTO dbo.Approval
                (BookingID, ApproverID, DecisionTime, DecisionNote)
            VALUES
                (@BookingID, @ApproverID, SYSUTCDATETIME(), @DecisionNote);

            SET @ApprovedBookingID = @BookingID;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- End of 12-concurrency-implementation-G10.sql
--
-- Delivered objects:
--   dbo.fn_BookingConflictCount  shared BR21 overlap predicate (directive 3)
--   dbo.usp_ApproveBooking_Auto  instant-approval path, anchor-locked
--   dbo.usp_ApproveBooking_Manual staff-approval path, anchor-locked
--
-- Both procedures implement the Step 11 anchor-lock strategy
-- (UPDLOCK, HOLDLOCK on Space.SpaceCode) so BR21 holds under concurrency for
-- both transaction types. Scripts that demonstrate the conflicts
-- (Scenario A and B) and prove BR21 holds after this fix are delivered in
-- Step 13 (outputs/13-concurrency-tests-G10).
-- =====================================================================
