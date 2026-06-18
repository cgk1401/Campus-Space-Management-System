# 05 — Database Definition (DDL)

**DBMS:** Microsoft SQL Server (T-SQL)

---

## 1. Create Database

```sql
CREATE DATABASE CampusSpaceManagement;
GO

USE CampusSpaceManagement;
GO
```

---

## 2. Table: User

```sql
CREATE TABLE [User] (
    UserID              INT           NOT NULL IDENTITY(1,1),
    FullName            NVARCHAR(100) NOT NULL,
    Email               NVARCHAR(255) NOT NULL,
    PhoneNumber         NVARCHAR(20)  NOT NULL,
    [Role]              NVARCHAR(30)  NOT NULL,
    Department          NVARCHAR(100) NOT NULL,
    AccountStatus       NVARCHAR(20)  NOT NULL DEFAULT 'Active',

    CONSTRAINT PK_User PRIMARY KEY (UserID),
    CONSTRAINT UQ_User_Email UNIQUE (Email),
    CONSTRAINT CK_User_Role CHECK ([Role] IN (
        'Student',
        'Lecturer',
        'TeachingAssistant',
        'FacilityStaff',
        'DepartmentAdministrator',
        'FacilityManager'
    )),
    CONSTRAINT CK_User_AccountStatus CHECK (AccountStatus IN (
        'Active',
        'Disabled'
    ))
);
GO
```

---

## 3. Table: Space

```sql
CREATE TABLE Space (
    SpaceCode           NVARCHAR(20)  NOT NULL,
    SpaceName           NVARCHAR(100) NOT NULL,
    SpaceType           NVARCHAR(30)  NOT NULL,
    Building            NVARCHAR(100) NOT NULL,
    Floor               INT           NOT NULL,
    RoomNumber          NVARCHAR(20)  NOT NULL,
    Capacity            INT           NOT NULL,
    CurrentStatus       NVARCHAR(20)  NOT NULL DEFAULT 'Available',
    UsagePolicy         NVARCHAR(MAX) NULL,

    CONSTRAINT PK_Space PRIMARY KEY (SpaceCode),
    CONSTRAINT UQ_Space_Room UNIQUE (Building, Floor, RoomNumber),
    CONSTRAINT CK_Space_SpaceType CHECK (SpaceType IN (
        'Auditorium',
        'Classroom',
        'ComputerLaboratory',
        'ProjectLaboratory',
        'MeetingRoom',
        'StudentWorkspace'
    )),
    CONSTRAINT CK_Space_CurrentStatus CHECK (CurrentStatus IN (
        'Available',
        'InUse',
        'UnderMaintenance',
        'TemporarilyClosed',
        'Retired'
    )),
    CONSTRAINT CK_Space_Capacity CHECK (Capacity > 0)
);
GO
```

---

## 4. Table: FacilityType

```sql
CREATE TABLE FacilityType (
    FacilityName NVARCHAR(50) NOT NULL,

    CONSTRAINT PK_FacilityType PRIMARY KEY (FacilityName)
);
GO
```

---

## 5. Table: SpaceFacility

```sql
CREATE TABLE SpaceFacility (
    SpaceCode    NVARCHAR(20) NOT NULL,
    FacilityName NVARCHAR(50) NOT NULL,

    CONSTRAINT PK_SpaceFacility PRIMARY KEY (SpaceCode, FacilityName),

    CONSTRAINT FK_SpaceFacility_Space
        FOREIGN KEY (SpaceCode) REFERENCES Space(SpaceCode)
        ON DELETE CASCADE,

    CONSTRAINT FK_SpaceFacility_FacilityType
        FOREIGN KEY (FacilityName) REFERENCES FacilityType(FacilityName)
        ON DELETE NO ACTION
);
GO
```

---

## 6. Table: BookingRequest

```sql
CREATE TABLE BookingRequest (
    BookingID            INT           NOT NULL IDENTITY(1,1),
    RequesterID          INT           NOT NULL,
    SpaceCode            NVARCHAR(20)  NOT NULL,
    StartTime            DATETIME2     NOT NULL,
    EndTime              DATETIME2     NOT NULL,
    Purpose              NVARCHAR(30)  NOT NULL,
    ExpectedParticipants INT           NOT NULL,
    Status               NVARCHAR(20)  NOT NULL DEFAULT 'Pending',

    CONSTRAINT PK_BookingRequest PRIMARY KEY (BookingID),

    CONSTRAINT FK_BookingRequest_Requester
        FOREIGN KEY (RequesterID) REFERENCES [User](UserID)
        ON DELETE NO ACTION,

    CONSTRAINT FK_BookingRequest_Space
        FOREIGN KEY (SpaceCode) REFERENCES Space(SpaceCode)
        ON DELETE NO ACTION,

    CONSTRAINT CK_BookingRequest_Purpose CHECK (Purpose IN (
        'Lecture',
        'Examination',
        'Seminar',
        'Workshop',
        'Meeting',
        'StudentActivity',
        'AdministrativeEvent'
    )),

    CONSTRAINT CK_BookingRequest_Status CHECK (Status IN (
        'Pending',
        'Approved',
        'Rejected',
        'Cancelled',
        'CheckedIn',
        'Completed',
        'NoShow'
    )),

    CONSTRAINT CK_BookingRequest_TimeRange CHECK (EndTime > StartTime),

    CONSTRAINT CK_BookingRequest_Participants CHECK (ExpectedParticipants > 0)
);
GO
```

---

## 7. Table: Approval

```sql
CREATE TABLE Approval (
    BookingID       INT           NOT NULL,
    ApproverID      INT           NOT NULL,
    DecisionTime    DATETIME2     NOT NULL,
    DecisionNote    NVARCHAR(MAX) NULL,
    RejectionReason NVARCHAR(MAX) NULL,

    CONSTRAINT PK_Approval PRIMARY KEY (BookingID),

    CONSTRAINT FK_Approval_Booking
        FOREIGN KEY (BookingID) REFERENCES BookingRequest(BookingID)
        ON DELETE CASCADE,

    CONSTRAINT FK_Approval_Approver
        FOREIGN KEY (ApproverID) REFERENCES [User](UserID)
        ON DELETE NO ACTION
);
GO
```

---

## 8. Table: UsageSession

```sql
CREATE TABLE UsageSession (
    BookingID        INT           NOT NULL,
    ActualStartTime  DATETIME2     NOT NULL,
    CheckInStaffID   INT           NOT NULL,
    InitialCondition NVARCHAR(MAX) NULL,
    ActualEndTime    DATETIME2     NULL,
    FinalCondition   NVARCHAR(MAX) NULL,
    UsageNotes       NVARCHAR(MAX) NULL,

    CONSTRAINT PK_UsageSession PRIMARY KEY (BookingID),

    CONSTRAINT FK_UsageSession_Booking
        FOREIGN KEY (BookingID) REFERENCES BookingRequest(BookingID)
        ON DELETE CASCADE,

    CONSTRAINT FK_UsageSession_CheckInStaff
        FOREIGN KEY (CheckInStaffID) REFERENCES [User](UserID)
        ON DELETE NO ACTION
);
GO
```

---

## 9. Table: MaintenanceRecord

```sql
CREATE TABLE MaintenanceRecord (
    MaintenanceID     INT           NOT NULL IDENTITY(1,1),
    SpaceCode         NVARCHAR(20)  NOT NULL,
    ReporterID        INT           NOT NULL,
    AssignedStaffID   INT           NULL,
    ProblemDescription NVARCHAR(MAX) NOT NULL,
    StartTime         DATETIME2     NOT NULL,
    CompletionTime    DATETIME2     NULL,
    Status            NVARCHAR(20)  NOT NULL DEFAULT 'Open',
    ResultNote        NVARCHAR(MAX) NULL,

    CONSTRAINT PK_MaintenanceRecord PRIMARY KEY (MaintenanceID),

    CONSTRAINT FK_MaintenanceRecord_Space
        FOREIGN KEY (SpaceCode) REFERENCES Space(SpaceCode)
        ON DELETE NO ACTION,

    CONSTRAINT FK_MaintenanceRecord_Reporter
        FOREIGN KEY (ReporterID) REFERENCES [User](UserID)
        ON DELETE NO ACTION,

    CONSTRAINT FK_MaintenanceRecord_AssignedStaff
        FOREIGN KEY (AssignedStaffID) REFERENCES [User](UserID)
        ON DELETE SET NULL,

    CONSTRAINT CK_MaintenanceRecord_Status CHECK (Status IN (
        'Open',
        'InProgress',
        'Resolved',
        'Closed'
    ))
);
GO
```

---

## 10. Complete DDL Script (All in Order)

```sql
-- ============================================================
-- Campus Space Management System — SQL Server DDL
-- ============================================================

CREATE DATABASE CampusSpaceManagement;
GO

USE CampusSpaceManagement;
GO

-- 10.1. User
CREATE TABLE [User] (
    UserID              INT           NOT NULL IDENTITY(1,1),
    FullName            NVARCHAR(100) NOT NULL,
    Email               NVARCHAR(255) NOT NULL,
    PhoneNumber         NVARCHAR(20)  NOT NULL,
    [Role]              NVARCHAR(30)  NOT NULL,
    Department          NVARCHAR(100) NOT NULL,
    AccountStatus       NVARCHAR(20)  NOT NULL DEFAULT 'Active',

    CONSTRAINT PK_User PRIMARY KEY (UserID),
    CONSTRAINT UQ_User_Email UNIQUE (Email),
    CONSTRAINT CK_User_Role CHECK ([Role] IN (
        'Student', 'Lecturer', 'TeachingAssistant',
        'FacilityStaff', 'DepartmentAdministrator', 'FacilityManager'
    )),
    CONSTRAINT CK_User_AccountStatus CHECK (AccountStatus IN ('Active', 'Disabled'))
);
GO

-- 10.2. Space
CREATE TABLE Space (
    SpaceCode           NVARCHAR(20)  NOT NULL,
    SpaceName           NVARCHAR(100) NOT NULL,
    SpaceType           NVARCHAR(30)  NOT NULL,
    Building            NVARCHAR(100) NOT NULL,
    Floor               INT           NOT NULL,
    RoomNumber          NVARCHAR(20)  NOT NULL,
    Capacity            INT           NOT NULL,
    CurrentStatus       NVARCHAR(20)  NOT NULL DEFAULT 'Available',
    UsagePolicy         NVARCHAR(MAX) NULL,

    CONSTRAINT PK_Space PRIMARY KEY (SpaceCode),
    CONSTRAINT UQ_Space_Room UNIQUE (Building, Floor, RoomNumber),
    CONSTRAINT CK_Space_SpaceType CHECK (SpaceType IN (
        'Auditorium', 'Classroom', 'ComputerLaboratory',
        'ProjectLaboratory', 'MeetingRoom', 'StudentWorkspace'
    )),
    CONSTRAINT CK_Space_CurrentStatus CHECK (CurrentStatus IN (
        'Available', 'InUse', 'UnderMaintenance',
        'TemporarilyClosed', 'Retired'
    )),
    CONSTRAINT CK_Space_Capacity CHECK (Capacity > 0)
);
GO

-- 10.3. FacilityType
CREATE TABLE FacilityType (
    FacilityName NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_FacilityType PRIMARY KEY (FacilityName)
);
GO

-- 10.4. SpaceFacility
CREATE TABLE SpaceFacility (
    SpaceCode    NVARCHAR(20) NOT NULL,
    FacilityName NVARCHAR(50) NOT NULL,

    CONSTRAINT PK_SpaceFacility PRIMARY KEY (SpaceCode, FacilityName),

    CONSTRAINT FK_SpaceFacility_Space
        FOREIGN KEY (SpaceCode) REFERENCES Space(SpaceCode)
        ON DELETE CASCADE,

    CONSTRAINT FK_SpaceFacility_FacilityType
        FOREIGN KEY (FacilityName) REFERENCES FacilityType(FacilityName)
        ON DELETE NO ACTION
);
GO

-- 10.5. BookingRequest
CREATE TABLE BookingRequest (
    BookingID            INT           NOT NULL IDENTITY(1,1),
    RequesterID          INT           NOT NULL,
    SpaceCode            NVARCHAR(20)  NOT NULL,
    StartTime            DATETIME2     NOT NULL,
    EndTime              DATETIME2     NOT NULL,
    Purpose              NVARCHAR(30)  NOT NULL,
    ExpectedParticipants INT           NOT NULL,
    Status               NVARCHAR(20)  NOT NULL DEFAULT 'Pending',

    CONSTRAINT PK_BookingRequest PRIMARY KEY (BookingID),

    CONSTRAINT FK_BookingRequest_Requester
        FOREIGN KEY (RequesterID) REFERENCES [User](UserID)
        ON DELETE NO ACTION,

    CONSTRAINT FK_BookingRequest_Space
        FOREIGN KEY (SpaceCode) REFERENCES Space(SpaceCode)
        ON DELETE NO ACTION,

    CONSTRAINT CK_BookingRequest_Purpose CHECK (Purpose IN (
        'Lecture', 'Examination', 'Seminar', 'Workshop',
        'Meeting', 'StudentActivity', 'AdministrativeEvent'
    )),

    CONSTRAINT CK_BookingRequest_Status CHECK (Status IN (
        'Pending', 'Approved', 'Rejected', 'Cancelled',
        'CheckedIn', 'Completed', 'NoShow'
    )),

    CONSTRAINT CK_BookingRequest_TimeRange CHECK (EndTime > StartTime),
    CONSTRAINT CK_BookingRequest_Participants CHECK (ExpectedParticipants > 0)
);
GO

-- 10.6. Approval
CREATE TABLE Approval (
    BookingID       INT           NOT NULL,
    ApproverID      INT           NOT NULL,
    DecisionTime    DATETIME2     NOT NULL,
    DecisionNote    NVARCHAR(MAX) NULL,
    RejectionReason NVARCHAR(MAX) NULL,

    CONSTRAINT PK_Approval PRIMARY KEY (BookingID),

    CONSTRAINT FK_Approval_Booking
        FOREIGN KEY (BookingID) REFERENCES BookingRequest(BookingID)
        ON DELETE CASCADE,

    CONSTRAINT FK_Approval_Approver
        FOREIGN KEY (ApproverID) REFERENCES [User](UserID)
        ON DELETE NO ACTION
);
GO

-- 10.7. UsageSession
CREATE TABLE UsageSession (
    BookingID        INT           NOT NULL,
    ActualStartTime  DATETIME2     NOT NULL,
    CheckInStaffID   INT           NOT NULL,
    InitialCondition NVARCHAR(MAX) NULL,
    ActualEndTime    DATETIME2     NULL,
    FinalCondition   NVARCHAR(MAX) NULL,
    UsageNotes       NVARCHAR(MAX) NULL,

    CONSTRAINT PK_UsageSession PRIMARY KEY (BookingID),

    CONSTRAINT FK_UsageSession_Booking
        FOREIGN KEY (BookingID) REFERENCES BookingRequest(BookingID)
        ON DELETE CASCADE,

    CONSTRAINT FK_UsageSession_CheckInStaff
        FOREIGN KEY (CheckInStaffID) REFERENCES [User](UserID)
        ON DELETE NO ACTION
);
GO

-- 10.8. MaintenanceRecord
CREATE TABLE MaintenanceRecord (
    MaintenanceID      INT           NOT NULL IDENTITY(1,1),
    SpaceCode          NVARCHAR(20)  NOT NULL,
    ReporterID         INT           NOT NULL,
    AssignedStaffID    INT           NULL,
    ProblemDescription NVARCHAR(MAX) NOT NULL,
    StartTime          DATETIME2     NOT NULL,
    CompletionTime     DATETIME2     NULL,
    Status             NVARCHAR(20)  NOT NULL DEFAULT 'Open',
    ResultNote         NVARCHAR(MAX) NULL,

    CONSTRAINT PK_MaintenanceRecord PRIMARY KEY (MaintenanceID),

    CONSTRAINT FK_MaintenanceRecord_Space
        FOREIGN KEY (SpaceCode) REFERENCES Space(SpaceCode)
        ON DELETE NO ACTION,

    CONSTRAINT FK_MaintenanceRecord_Reporter
        FOREIGN KEY (ReporterID) REFERENCES [User](UserID)
        ON DELETE NO ACTION,

    CONSTRAINT FK_MaintenanceRecord_AssignedStaff
        FOREIGN KEY (AssignedStaffID) REFERENCES [User](UserID)
        ON DELETE SET NULL,

    CONSTRAINT CK_MaintenanceRecord_Status CHECK (Status IN (
        'Open', 'InProgress', 'Resolved', 'Closed'
    ))
);
GO
```
