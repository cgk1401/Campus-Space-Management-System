# 05 — Database Implementation (DDL)

## DBMS

Microsoft SQL Server

## DDL Script

```sql
-- ============================================================
-- Database Definition: Campus Space Management System
-- DBMS: Microsoft SQL Server
-- ============================================================

-- ============================================================
-- 1. [User]
-- ============================================================
CREATE TABLE [User] (
    UserID INT IDENTITY(1,1) NOT NULL,
    FullName VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    PhoneNumber VARCHAR(20) NULL,
    Role VARCHAR(30) NOT NULL,
    Department VARCHAR(100) NULL,
    AccountStatus VARCHAR(20) NOT NULL
        CONSTRAINT DF_User_AccountStatus DEFAULT 'Active',

    CONSTRAINT PK_User PRIMARY KEY (UserID),
    CONSTRAINT UQ_User_Email UNIQUE (Email),
    CONSTRAINT CK_User_Role CHECK (Role IN (
        'Student', 'Lecturer', 'TeachingAssistant',
        'FacilityStaff', 'DepartmentAdministrator', 'FacilityManager'
    )),
    CONSTRAINT CK_User_AccountStatus CHECK (AccountStatus IN (
        'Active', 'Inactive', 'Suspended'
    ))
);

-- ============================================================
-- 2. [Space]
-- ============================================================
CREATE TABLE [Space] (
    SpaceCode VARCHAR(20) NOT NULL,
    SpaceName VARCHAR(100) NOT NULL,
    SpaceType VARCHAR(30) NOT NULL,
    Building VARCHAR(50) NOT NULL,
    Floor INT NOT NULL,
    RoomNumber VARCHAR(20) NOT NULL,
    Capacity INT NOT NULL,
    CurrentStatus VARCHAR(20) NOT NULL
        CONSTRAINT DF_Space_CurrentStatus DEFAULT 'Available',
    UsagePolicy TEXT NULL,

    CONSTRAINT PK_Space PRIMARY KEY (SpaceCode),
    CONSTRAINT CK_Space_SpaceType CHECK (SpaceType IN (
        'Auditorium', 'Classroom', 'ComputerLab',
        'ProjectLab', 'MeetingRoom', 'StudentWorkspace'
    )),
    CONSTRAINT CK_Space_CurrentStatus CHECK (CurrentStatus IN (
        'Available', 'InUse', 'UnderMaintenance',
        'TemporarilyClosed', 'Retired'
    )),
    CONSTRAINT CK_Space_Capacity CHECK (Capacity > 0)
);

-- ============================================================
-- 3. [Facility]
-- ============================================================
CREATE TABLE [Facility] (
    FacilityID INT IDENTITY(1,1) NOT NULL,
    FacilityName VARCHAR(50) NOT NULL,
    SpaceCode VARCHAR(20) NOT NULL,

    CONSTRAINT PK_Facility PRIMARY KEY (FacilityID),
    CONSTRAINT FK_Facility_Space FOREIGN KEY (SpaceCode)
        REFERENCES [Space](SpaceCode)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT CK_Facility_FacilityName CHECK (FacilityName IN (
        'Projector', 'Whiteboard', 'Microphone', 'Computer',
        'LivestreamingEquipment', 'AirConditioner'
    ))
);

-- ============================================================
-- 4. [BookingRequest]
-- ============================================================
CREATE TABLE [BookingRequest] (
    BookingID INT IDENTITY(1,1) NOT NULL,
    RequesterID INT NOT NULL,
    SpaceCode VARCHAR(20) NOT NULL,
    RequestedStartTime DATETIME2 NOT NULL,
    RequestedEndTime DATETIME2 NOT NULL,
    PurposeOfUse VARCHAR(30) NOT NULL,
    ExpectedParticipants INT NOT NULL,
    Status VARCHAR(20) NOT NULL
        CONSTRAINT DF_BookingRequest_Status DEFAULT 'Pending',

    CONSTRAINT PK_BookingRequest PRIMARY KEY (BookingID),
    CONSTRAINT FK_BookingRequest_Requester FOREIGN KEY (RequesterID)
        REFERENCES [User](UserID)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT FK_BookingRequest_Space FOREIGN KEY (SpaceCode)
        REFERENCES [Space](SpaceCode)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT CK_BookingRequest_TimeRange
        CHECK (RequestedEndTime > RequestedStartTime),
    CONSTRAINT CK_BookingRequest_PurposeOfUse CHECK (PurposeOfUse IN (
        'Lecture', 'Examination', 'Seminar', 'Workshop',
        'Meeting', 'StudentActivity', 'AdministrativeEvent'
    )),
    CONSTRAINT CK_BookingRequest_ExpectedParticipants
        CHECK (ExpectedParticipants > 0),
    CONSTRAINT CK_BookingRequest_Status CHECK (Status IN (
        'Pending', 'Approved', 'Rejected', 'Cancelled',
        'CheckedIn', 'Completed', 'NoShow'
    ))
);

-- ============================================================
-- 5. [Approval]
-- ============================================================
CREATE TABLE [Approval] (
    ApprovalID INT IDENTITY(1,1) NOT NULL,
    BookingID INT NOT NULL,
    ApproverID INT NOT NULL,
    DecisionTime DATETIME2 NOT NULL,
    DecisionNote TEXT NULL,
    RejectionReason TEXT NULL,

    CONSTRAINT PK_Approval PRIMARY KEY (ApprovalID),
    CONSTRAINT UQ_Approval_BookingID UNIQUE (BookingID),
    CONSTRAINT FK_Approval_BookingRequest FOREIGN KEY (BookingID)
        REFERENCES [BookingRequest](BookingID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_Approval_Approver FOREIGN KEY (ApproverID)
        REFERENCES [User](UserID)
        ON DELETE NO ACTION ON UPDATE CASCADE
);

-- ============================================================
-- 6. [UsageSession]
-- ============================================================
CREATE TABLE [UsageSession] (
    BookingID INT NOT NULL,
    ActualStartTime DATETIME2 NOT NULL,
    CheckInStaffID INT NOT NULL,
    InitialCondition TEXT NULL,
    ActualEndTime DATETIME2 NULL,
    FinalCondition TEXT NULL,
    UsageNotes TEXT NULL,

    CONSTRAINT PK_UsageSession PRIMARY KEY (BookingID),
    CONSTRAINT FK_UsageSession_BookingRequest FOREIGN KEY (BookingID)
        REFERENCES [BookingRequest](BookingID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_UsageSession_CheckInStaff FOREIGN KEY (CheckInStaffID)
        REFERENCES [User](UserID)
        ON DELETE NO ACTION ON UPDATE CASCADE
);

-- ============================================================
-- 7. [MaintenanceRecord]
-- ============================================================
CREATE TABLE [MaintenanceRecord] (
    MaintenanceID INT IDENTITY(1,1) NOT NULL,
    SpaceCode VARCHAR(20) NOT NULL,
    ReporterID INT NOT NULL,
    AssignedStaffID INT NULL,
    ProblemDescription TEXT NOT NULL,
    StartTime DATETIME2 NOT NULL,
    CompletionTime DATETIME2 NULL,
    Status VARCHAR(20) NOT NULL
        CONSTRAINT DF_MaintenanceRecord_Status DEFAULT 'Reported',
    ResultNote TEXT NULL,

    CONSTRAINT PK_MaintenanceRecord PRIMARY KEY (MaintenanceID),
    CONSTRAINT FK_MaintenanceRecord_Space FOREIGN KEY (SpaceCode)
        REFERENCES [Space](SpaceCode)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_MaintenanceRecord_Reporter FOREIGN KEY (ReporterID)
        REFERENCES [User](UserID)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT FK_MaintenanceRecord_AssignedStaff FOREIGN KEY (AssignedStaffID)
        REFERENCES [User](UserID)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT CK_MaintenanceRecord_Status CHECK (Status IN (
        'Reported', 'InProgress', 'Completed', 'Cancelled'
    ))
);
```

---

## Additional Constraints (Non-declarative)

The following business rules cannot be enforced via declarative `CHECK` constraints and require triggers or application logic:

### BR2 — Overlapping Booking Prevention

Prevents two approved bookings from overlapping on the same space.

```sql
CREATE TRIGGER TR_BookingRequest_PreventOverlap
ON [BookingRequest]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM [BookingRequest] BR1
        INNER JOIN [BookingRequest] BR2
            ON BR1.SpaceCode = BR2.SpaceCode
            AND BR1.BookingID <> BR2.BookingID
            AND BR1.RequestedStartTime < BR2.RequestedEndTime
            AND BR2.RequestedStartTime < BR1.RequestedEndTime
        WHERE BR1.Status IN ('Approved', 'CheckedIn')
          AND BR2.Status IN ('Approved', 'CheckedIn')
          AND BR1.BookingID IN (SELECT BookingID FROM inserted)
    )
    BEGIN
        RAISERROR('Overlapping booking detected for the same space.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
```

### BR3 / BR6 — Unavailable Space Booking Prevention

Prevents booking a space that is *Under Maintenance*, *Temporarily Closed*, or *Retired*, or that has an active maintenance record.

```sql
CREATE TRIGGER TR_BookingRequest_CheckSpaceAvailability
ON [BookingRequest]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted I
        INNER JOIN [Space] S ON I.SpaceCode = S.SpaceCode
        WHERE S.CurrentStatus IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')
    )
    BEGIN
        RAISERROR('Cannot book a space that is under maintenance, closed, or retired.', 16, 1);
        ROLLBACK TRANSACTION;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted I
        INNER JOIN [MaintenanceRecord] MR
            ON I.SpaceCode = MR.SpaceCode
        WHERE MR.Status IN ('Reported', 'InProgress')
          AND I.Status IN ('Pending', 'Approved')
    )
    BEGIN
        RAISERROR('Cannot book a space with an active maintenance record.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
```

---

## DEFAULT Values Summary

| Table | Column | Default |
|-------|--------|---------|
| User | AccountStatus | 'Active' |
| Space | CurrentStatus | 'Available' |
| BookingRequest | Status | 'Pending' |
| MaintenanceRecord | Status | 'Reported' |

---

## Referential Integrity Summary

| FK Constraint | Parent | Child | ON DELETE | ON UPDATE |
|---------------|--------|-------|-----------|-----------|
| FK_Facility_Space | Space | Facility | CASCADE | CASCADE |
| FK_BookingRequest_Requester | User | BookingRequest | NO ACTION | CASCADE |
| FK_BookingRequest_Space | Space | BookingRequest | NO ACTION | CASCADE |
| FK_Approval_BookingRequest | BookingRequest | Approval | CASCADE | CASCADE |
| FK_Approval_Approver | User | Approval | NO ACTION | CASCADE |
| FK_UsageSession_BookingRequest | BookingRequest | UsageSession | CASCADE | CASCADE |
| FK_UsageSession_CheckInStaff | User | UsageSession | NO ACTION | CASCADE |
| FK_MaintenanceRecord_Space | Space | MaintenanceRecord | CASCADE | CASCADE |
| FK_MaintenanceRecord_Reporter | User | MaintenanceRecord | NO ACTION | CASCADE |
| FK_MaintenanceRecord_AssignedStaff | User | MaintenanceRecord | SET NULL | CASCADE |
