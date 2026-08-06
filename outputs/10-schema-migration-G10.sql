-- =====================================================================
-- 10 — Schema Migration (Phase 1 -> Phase 2)
-- =====================================================================
-- Role       : Senior Database Administrator
-- DBMS       : Microsoft SQL Server (T-SQL)
-- Target DB  : CampusSpaceManagement  (Phase 1 schema, outputs/05)
-- Purpose    : Transition the LIVE Phase 1 database to Phase 2.
--
-- STRICT DIRECTIVES complied with:
--   1. NO DATA LOSS  -> NO DROP TABLE, NO rewrite/CREATE of existing tables.
--   2. ADDITIVE ONLY -> ALTER TABLE MaintenanceRecord ADD ImpactLevel
--                       (DEFAULT 'OutOfService' so existing rows stay valid).
--   3. New table     -> CREATE TABLE ONLY for BookingAcknowledgement.
--   4. System actor  -> INSERT the non-human System User (UserID = -1,
--                       Role = 'FacilityManager') for auto-approval.
--   5. All SQL is valid Microsoft SQL Server (T-SQL).
-- =====================================================================

USE CampusSpaceManagement;
GO

-- ---------------------------------------------------------------------
-- STEP 2 (directive 2): Additive change on existing MaintenanceRecord.
-- Adds ImpactLevel (CHECK Advisory|OutOfService) with a DEFAULT so the
-- existing rows are back-filled to 'OutOfService' (preserves Phase 1
-- behaviour: open maintenance blocks booking) without a data rewrite.
-- Guarded so the script is safely re-runnable.
-- ---------------------------------------------------------------------
IF COL_LENGTH('dbo.MaintenanceRecord', 'ImpactLevel') IS NULL
BEGIN
    ALTER TABLE MaintenanceRecord
        ADD ImpactLevel NVARCHAR(20) NOT NULL
            CONSTRAINT DF_MaintenanceRecord_ImpactLevel DEFAULT 'OutOfService';

    ALTER TABLE MaintenanceRecord
        ADD CONSTRAINT CK_MaintenanceRecord_ImpactLevel
        CHECK (ImpactLevel IN ('Advisory', 'OutOfService'));
END;
GO

-- =====================================================================
-- 3 (directive 3): NEW table ONLY for the M:N advisory acknowledgement.
-- One row per (booking, advisory) pair records that the requester was
-- informed that this advisory applied at booking time.
-- =====================================================================
IF OBJECT_ID('dbo.BookingAcknowledgement', 'U') IS NULL
BEGIN
    CREATE TABLE BookingAcknowledgement (
        BookingID           INT          NOT NULL,
        MaintenanceID       INT          NOT NULL,
        AcknowledgedAt      DATETIME2    NOT NULL
            CONSTRAINT DF_BookingAcknowledgement_AcknowledgedAt DEFAULT SYSUTCDATETIME(),
        AcknowledgedByUserID INT         NULL,
        CONSTRAINT PK_BookingAcknowledgement
            PRIMARY KEY (BookingID, MaintenanceID),
        CONSTRAINT FK_BookingAcknowledgement_Booking FOREIGN KEY (BookingID)
            REFERENCES BookingRequest(BookingID)    ON DELETE NO ACTION,
        CONSTRAINT FK_BookingAcknowledgement_Maintenance FOREIGN KEY (MaintenanceID)
            REFERENCES MaintenanceRecord(MaintenanceID) ON DELETE NO ACTION,
        CONSTRAINT FK_BookingAcknowledgement_User FOREIGN KEY (AcknowledgedByUserID)
            REFERENCES [User](UserID)               ON DELETE NO ACTION
    );

    -- Supporting index: PK is (BookingID, MaintenanceID); lookups by
    -- maintenance (e.g. "who acknowledged this advisory") need this side.
    CREATE INDEX IX_BookingAcknowledgement_Maintenance
        ON dbo.BookingAcknowledgement (MaintenanceID);
END
GO

-- =====================================================================
-- 4 (directive 4): System data - the Non-human System Actor that
-- auto-approval writes as Approval.ApproverID, keeping the NOT NULL FK
-- and the audit trail intact (directive 3, Step 8 D4).
-- UserID is an IDENTITY column, so IDENTITY_INSERT must be enabled.
-- =====================================================================
SET IDENTITY_INSERT [User] ON;
GO

INSERT INTO [User] (UserID, FullName, Email, PhoneNumber, Role,
                    Department, AccountStatus)
VALUES (-1,
        N'System Auto-Approval',
        N'autoapproval@campus.local',
        NULL,
        N'FacilityManager',
        N'System',
        N'Active');
GO

SET IDENTITY_INSERT [User] OFF;
GO

-- Verify the system actor is present (informational).
SELECT UserID, FullName, Role, AccountStatus
FROM   [User]
WHERE  UserID = -1;
GO

-- =====================================================================
-- Summary of applied Phase 2 changes:
--   [UPDATED] MaintenanceRecord.ImpactLevel
--   [NEW]     BookingAcknowledgement (BookingID, MaintenanceID,
--             AcknowledgedAt, AcknowledgedByUserID)
--   [DATA]    System auto-approval actor (UserID = -1, FacilityManager)
-- No existing table was dropped or recreated. No existing data was lost.
-- =====================================================================