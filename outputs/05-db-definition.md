# 05 — Database Definition (SQL DDL)

Implements the logical schema from `outputs/03-logical-design.md` for **Microsoft SQL Server** (AGENTS.md default). Constraint names follow `{type}_{Table}_{Column}` for traceability back to the business rules in `outputs/01-business-req-analysis.md`.

Application-level rules (BR2/BR3/BR4/BR16 and conditional checks from BR5/BR7) are **not** DDL — they are documented at the end and enforced in the application/API layer.

---

## 1. Database Creation

```sql
CREATE DATABASE CampusSpaceManagement;
GO

USE CampusSpaceManagement;
GO
```

---

## 2. Tables (in dependency order)

### 2.1. User  (BR1, BR10)

```sql
CREATE TABLE [User] (
    UserID          INT IDENTITY(1,1)  NOT NULL,
    FullName        NVARCHAR(100)      NOT NULL,
    Email           NVARCHAR(255)      NOT NULL,
    PhoneNumber     NVARCHAR(20)       NULL,
    Role            NVARCHAR(30)       NOT NULL,
    Department      NVARCHAR(100)      NULL,
    AccountStatus   NVARCHAR(20)       NOT NULL
        CONSTRAINT DF_User_AccountStatus DEFAULT 'Active',
    CONSTRAINT PK_User PRIMARY KEY (UserID),
    CONSTRAINT UQ_User_Email UNIQUE (Email),
    CONSTRAINT CK_User_Role CHECK (Role IN (
        'Student', 'Lecturer', 'TeachingAssistant',
        'FacilityStaff', 'DepartmentAdministrator', 'FacilityManager')),
    CONSTRAINT CK_User_AccountStatus CHECK (AccountStatus IN ('Active', 'Disabled'))
);
GO
```

### 2.2. Space  (BR3, BR12, BR15)

```sql
CREATE TABLE [Space] (
    SpaceCode       NVARCHAR(20)       NOT NULL,
    SpaceName       NVARCHAR(100)      NOT NULL,
    SpaceType       NVARCHAR(30)       NOT NULL,
    Building        NVARCHAR(100)      NOT NULL,
    Floor           INT                NOT NULL,
    RoomNumber      NVARCHAR(20)       NOT NULL,
    Capacity        INT                NOT NULL,
    CurrentStatus   NVARCHAR(20)       NOT NULL
        CONSTRAINT DF_Space_CurrentStatus DEFAULT 'Available',
    UsagePolicy     NVARCHAR(MAX)      NULL,
    CONSTRAINT PK_Space PRIMARY KEY (SpaceCode),
    -- Assumption A9 (pending confirmation): a room is uniquely located.
    CONSTRAINT UQ_Space_Location UNIQUE (Building, Floor, RoomNumber),
    CONSTRAINT CK_Space_SpaceType CHECK (SpaceType IN (
        'Auditorium', 'Classroom', 'ComputerLaboratory',
        'ProjectLaboratory', 'MeetingRoom', 'StudentWorkspace')),
    CONSTRAINT CK_Space_Capacity CHECK (Capacity > 0),
    CONSTRAINT CK_Space_CurrentStatus CHECK (CurrentStatus IN (
        'Available', 'InUse', 'UnderMaintenance', 'TemporarilyClosed', 'Retired'))
);
GO
```

### 2.3. Facility  (BR9)

```sql
CREATE TABLE Facility (
    FacilityID      INT IDENTITY(1,1)  NOT NULL,
    FacilityName    NVARCHAR(50)       NOT NULL,
    SpaceCode       NVARCHAR(20)       NOT NULL,
    CONSTRAINT PK_Facility PRIMARY KEY (FacilityID),
    CONSTRAINT FK_Facility_Space FOREIGN KEY (SpaceCode)
        REFERENCES [Space](SpaceCode) ON DELETE NO ACTION,
    CONSTRAINT CK_Facility_FacilityName CHECK (FacilityName IN (
        'Projector', 'Whiteboard', 'Microphone', 'Computer',
        'LivestreamingEquipment', 'AirConditioner'))
);
GO
```

### 2.4. BookingRequest  (BR1, BR2, BR11, BR12, BR13, BR14)

```sql
CREATE TABLE BookingRequest (
    BookingID            INT IDENTITY(1,1)  NOT NULL,
    RequesterID          INT                NOT NULL,
    SpaceCode            NVARCHAR(20)       NOT NULL,
    StartTime            DATETIME2          NOT NULL,
    EndTime              DATETIME2          NOT NULL,
    Purpose              NVARCHAR(30)       NOT NULL,
    ExpectedParticipants INT                NOT NULL,
    Status               NVARCHAR(20)       NOT NULL
        CONSTRAINT DF_BookingRequest_Status DEFAULT 'Pending',
    CONSTRAINT PK_BookingRequest PRIMARY KEY (BookingID),
    CONSTRAINT FK_BookingRequest_Requester FOREIGN KEY (RequesterID)
        REFERENCES [User](UserID) ON DELETE NO ACTION,
    CONSTRAINT FK_BookingRequest_Space FOREIGN KEY (SpaceCode)
        REFERENCES [Space](SpaceCode) ON DELETE NO ACTION,
    CONSTRAINT CK_BookingRequest_Purpose CHECK (Purpose IN (
        'Lecture', 'Examination', 'Seminar', 'Workshop',
        'Meeting', 'StudentActivity', 'AdministrativeEvent')),
    CONSTRAINT CK_BookingRequest_ExpectedParticipants CHECK (ExpectedParticipants > 0),
    CONSTRAINT CK_BookingRequest_TimeRange CHECK (EndTime > StartTime),
    CONSTRAINT CK_BookingRequest_Status CHECK (Status IN (
        'Pending', 'Approved', 'Rejected', 'Cancelled',
        'CheckedIn', 'Completed', 'NoShow'))
);
GO
```

### 2.5. Approval  (BR5, 1:1 with BookingRequest)

```sql
CREATE TABLE Approval (
    BookingID       INT                NOT NULL,
    ApproverID      INT                NOT NULL,
    DecisionTime    DATETIME2          NOT NULL,
    DecisionNote    NVARCHAR(MAX)      NOT NULL,
    RejectionReason NVARCHAR(MAX)      NULL,  -- required iff booking rejected (application-level, BR5)
    CONSTRAINT PK_Approval PRIMARY KEY (BookingID),
    CONSTRAINT FK_Approval_Booking FOREIGN KEY (BookingID)
        REFERENCES BookingRequest(BookingID) ON DELETE NO ACTION,
    CONSTRAINT FK_Approval_Approver FOREIGN KEY (ApproverID)
        REFERENCES [User](UserID) ON DELETE NO ACTION
);
GO
```

### 2.6. UsageSession  (BR6, BR7, BR8)

```sql
CREATE TABLE UsageSession (
    BookingID        INT                NOT NULL,
    ApprovalID       INT                NOT NULL,  -- BR8: session only after a decision record
    ActualStartTime  DATETIME2          NOT NULL,
    CheckInStaffID   INT                NOT NULL,
    InitialCondition NVARCHAR(MAX)      NOT NULL,
    ActualEndTime    DATETIME2          NULL,      -- NULL until check-out
    FinalCondition   NVARCHAR(MAX)      NULL,
    UsageNotes       NVARCHAR(MAX)      NULL,
    CONSTRAINT PK_UsageSession PRIMARY KEY (BookingID),
    CONSTRAINT FK_UsageSession_Booking FOREIGN KEY (BookingID)
        REFERENCES BookingRequest(BookingID) ON DELETE NO ACTION,
    CONSTRAINT FK_UsageSession_Approval FOREIGN KEY (ApprovalID)
        REFERENCES Approval(BookingID) ON DELETE NO ACTION,
    CONSTRAINT FK_UsageSession_CheckInStaff FOREIGN KEY (CheckInStaffID)
        REFERENCES [User](UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_UsageSession_TimeRange CHECK
        (ActualEndTime IS NULL OR ActualEndTime > ActualStartTime)
);
GO
```

### 2.7. MaintenanceRecord  (A5/Q1, BR4, BR10)

```sql
CREATE TABLE MaintenanceRecord (
    MaintenanceID      INT IDENTITY(1,1)  NOT NULL,
    SpaceCode          NVARCHAR(20)       NOT NULL,
    FacilityID         INT                NULL,   -- Assumption A5 / Q1 (per-unit reference)
    ReporterID         INT                NOT NULL,
    AssignedStaffID    INT                NULL,
    ProblemDescription NVARCHAR(MAX)      NOT NULL,
    StartTime          DATETIME2          NOT NULL,
    CompletionTime     DATETIME2          NULL,   -- NULL until resolved
    Status             NVARCHAR(20)       NOT NULL
        CONSTRAINT DF_MaintenanceRecord_Status DEFAULT 'Open',
    ResultNote         NVARCHAR(MAX)      NULL,
    CONSTRAINT PK_MaintenanceRecord PRIMARY KEY (MaintenanceID),
    CONSTRAINT FK_MaintenanceRecord_Space FOREIGN KEY (SpaceCode)
        REFERENCES [Space](SpaceCode) ON DELETE NO ACTION,
    CONSTRAINT FK_MaintenanceRecord_Facility FOREIGN KEY (FacilityID)
        REFERENCES Facility(FacilityID) ON DELETE NO ACTION,
    CONSTRAINT FK_MaintenanceRecord_Reporter FOREIGN KEY (ReporterID)
        REFERENCES [User](UserID) ON DELETE NO ACTION,
    CONSTRAINT FK_MaintenanceRecord_AssignedStaff FOREIGN KEY (AssignedStaffID)
        REFERENCES [User](UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_MaintenanceRecord_TimeRange CHECK
        (CompletionTime IS NULL OR CompletionTime > StartTime),
    CONSTRAINT CK_MaintenanceRecord_Status CHECK (Status IN (
        'Open', 'InProgress', 'Resolved', 'Closed'))
);
GO
```

---

## 3. Supporting Indexes (recommended)

FK columns and overlap queries are the hot paths. SQL Server does not auto-index child FK columns.

```sql
CREATE INDEX IX_BookingRequest_SpaceTime
    ON BookingRequest (SpaceCode, StartTime, EndTime);
GO

CREATE INDEX IX_Facility_SpaceCode ON Facility (SpaceCode);
GO
CREATE INDEX IX_BookingRequest_Requester ON BookingRequest (RequesterID);
GO
CREATE INDEX IX_BookingRequest_Status ON BookingRequest (Status);
GO
CREATE INDEX IX_MaintenanceRecord_SpaceCode ON MaintenanceRecord (SpaceCode);
GO
CREATE INDEX IX_MaintenanceRecord_AssignedStaff ON MaintenanceRecord (AssignedStaffID);
GO
CREATE INDEX IX_UsageSession_CheckInStaff ON UsageSession (CheckInStaffID);
GO
CREATE INDEX IX_Approval_Approver ON Approval (ApproverID);
GO
```

`IX_BookingRequest_SpaceTime` specifically supports the overlap-prevention check (BR2) and the "upcoming bookings / booking history" reports (§1.8).

---

## 4. Application-Level Rules (NOT DDL)

| # | Rule | Recommended implementation |
|---|------|----------------------------|
| BR2 | No overlapping approved bookings for same space | Transactional overlap check: `SELECT ... FROM BookingRequest WHERE SpaceCode = @s AND Status IN ('Approved','CheckedIn') AND StartTime < @newEnd AND EndTime > @newStart` executed with `UPDLOCK`/`HOLDLOCK` on the Space row, or under `SERIALIZABLE` isolation. |
| BR3 | Under-maintenance/closed/retired space not bookable | Application validates `Space.CurrentStatus` before insert; re-check at approval time. |
| BR4 | Space with active unresolved maintenance not bookable | Application checks for `MaintenanceRecord` with `Status IN ('Open','InProgress')` on the space. |
| BR5 | RejectionReason required when decision is Rejected | Application requires it when writing `BookingRequest.Status = 'Rejected'`. |
| BR6 nuance | Booking must be `Status IN ('Approved','CheckedIn')` before check-in (BR8 actually means *approved*, not merely decided — see validation risk 4.2) | Application check on booking status when creating a UsageSession. |
| BR16 | Only FacilityStaff/FacilityManager approve, check in, are assigned maintenance | Role-based access control in the application layer. |

---

## 5. Traceability Summary (Requirement → Table → Constraint)

| Business rule | Table | Constraint |
|---------------|-------|------------|
| BR1 university account | User / BookingRequest | PK_User; FK_BookingRequest_Requester |
| BR2 overlap prevention | BookingRequest | Application-level (index IX_BookingRequest_SpaceTime) |
| BR3 unavailable spaces | Space | Application-level (status check) |
| BR4 active maintenance | Space / MaintenanceRecord | Application-level (status check) |
| BR5 approval decision | Approval | PK_Approval; FK_Approval_Approver; NOT NULL DecisionTime/DecisionNote |
| BR6 check-in | UsageSession | NOT NULL ActualStartTime/CheckInStaffID/InitialCondition |
| BR7 check-out | UsageSession | Nullable ActualEndTime/FinalCondition/UsageNotes; CK_UsageSession_TimeRange |
| BR8 session after approval | UsageSession | FK_UsageSession_Approval (NOT NULL) |
| BR9 facility units | Facility | PK_Facility; FK_Facility_Space |
| BR10 history preservation | All | All FKs ON DELETE NO ACTION |
| BR11 purpose domain | BookingRequest | CK_BookingRequest_Purpose |
| BR12 capacity > 0 | Space | CK_Space_Capacity |
| BR13 EndTime > StartTime | BookingRequest | CK_BookingRequest_TimeRange |
| BR14 booking status domain | BookingRequest | CK_BookingRequest_Status |
| BR15 space status domain | Space | CK_Space_CurrentStatus |
| BR16 role-based access | — | Application-level |
| BR17 app-level enforcement | — | Section 4 |

---

## 6. Notes

- Script is idempotent-agnostic (no `DROP IF EXISTS`); drop tables in reverse dependency order if re-running: `MaintenanceRecord → UsageSession → Approval → BookingRequest → Facility → Space → User`.
- `UsageSession.ApprovalID` guarantees a decision record exists (BR8 structural part); confirming the decision was **Approved** is an application check (Section 4, BR6 nuance; see validation risk 4.2).
- `UQ_Space_Location` and `MaintenanceRecord.FacilityID` rest on documented assumptions A9 and A5/Q1 respectively and should be confirmed before production.
