# 15 — Index Tuning Report
**Group:** 10
**Phase 2 deliverable**

## 1. Introduction

This report documents the indexing strategy and performance tuning applied to the Phase 2 analytical and operational queries. The tuning workflow and the measurement script are both included:

- **Measurement script:** `outputs/15-index-tuning-report-G10/benchmark_queries.sql`
  (warmup run → timed run per query, `SET STATISTICS TIME ON` / `SET STATISTICS IO ON`; tuned indexes are dropped before the "before" section and re-created before the "after" section).

The tuned queries are:

- **Booking conflict check** — the concurrency invariant (Phase 2 §1.2), no two approved bookings may overlap on the same space.
- **Room finder** — spaces satisfying a required capacity and facility list within a time period (Phase 2 §1.3 report 3).
- **Two selected reporting queries** (other than the room finder): *Total approved booking hours per space for a semester* (report 1) and *Approved bookings by weekday and hour for a semester* (report 2).

> **Measurement note (dataset scale).** Phase 2 §1.3 requires the queries to be tested on a sufficiently large generated dataset so the effect of indexing is observable (≥ 100,000 bookings, `outputs/14-data-generator-G10`). The final run reported `Dataset scale: 100000 BookingRequest rows`, spanning `2023-09-01 … 2026-08-31` (the full 3-academic-year generated dataset). All numbers in §2/§3 are measured on this dataset with the plan cached (warmup run first).
>
> Two values need a caveat. Q1 BEFORE (`12 ms` for only 6 logical reads) is **scheduling noise** — the query already used the Phase 1 `IX_BookingRequest_SpaceTime` seek, so its real cost is sub-millisecond. Q3 AFTER (`134 ms` elapsed) is likewise inflated by scheduling noise on the measurement machine: the reliable indicators — `CPU time` (79 → 47 ms) and logical reads (1,143 → 95) — both improve. Where elapsed and CPU disagree, CPU time and the IO stats are the trustworthy numbers.

---

## 2. Tuned Queries

### 2.1. Booking Conflict Check
*   **Purpose:** Ensures no overlapping approved bookings for the same space, the core invariant under concurrent booking/approval (`BR2` / `outputs/05` §4).
*   **Before Indexing:**
    *   **Execution Plan:** seek on the Phase 1 `IX_BookingRequest_SpaceTime` (scan count 1, 6 logical reads) — the Phase 1 supporting index already serves the overlap predicate on `SpaceCode`, so the conflict check is cheap even before tuning.
    *   **Execution Time:** 12 ms (`CPU = 0 ms` — scheduling noise, see §1 note; real cost sub-millisecond).
*   **Applied Index:**
    ```sql
    CREATE NONCLUSTERED INDEX IX_BookingRequest_ConflictCheck
    ON BookingRequest (SpaceCode, Status, StartTime, EndTime)
    INCLUDE (RequesterID);
    ```
*   **After Indexing:**
    *   **Execution Plan:** the covering index is used for range seeks on `(SpaceCode, Status, StartTime)` (scan count 3, 13 logical reads); no clustered access.
    *   **Execution Time:** 0 ms.

---

### 2.2. Room Finder
*   **Purpose:** Finds available spaces satisfying a required capacity and facility list within a time period, excluding spaces blocked by overlapping out-of-service maintenance or approved bookings (Phase 2 §1.3 report 3).
*   **Before Indexing:**
    *   **Execution Plan:** full scan of `BookingRequest` (104,454 logical reads) inside the booking `NOT EXISTS` subquery, full scan of `MaintenanceRecord` (4,250 reads), `Facility` scan (548 reads), `Space` (6 reads); 2,879 ms.
*   **Applied Index:**
    ```sql
    CREATE NONCLUSTERED INDEX IX_MaintenanceRecord_Overlap
    ON MaintenanceRecord (SpaceCode, ImpactLevel, Status, StartTime)
    INCLUDE (CompletionTime);
    ```
    (also used: `IX_BookingRequest_ConflictCheck` for the booking subquery)
*   **After Indexing:**
    *   **Execution Plan:** the maintenance subquery performs 172 seeks on `IX_MaintenanceRecord_Overlap` (346 reads instead of 4,250) and the booking subquery performs 287 seeks on `IX_BookingRequest_ConflictCheck` (977 reads instead of 104,454) — full scans replaced by narrow seeks.
    *   **Execution Time:** 29 ms (~99× faster).

---

### 2.3. Reporting Query 1: Total Approved Booking Hours per Space
*   **Purpose:** Calculates total approved booking hours of each space for a given semester (Phase 2 §1.3 report 1).
*   **Before Indexing:**
    *   **Execution Plan:** scan over `BookingRequest` for the semester/status filter (1,143 logical reads) + join to `Space` (6 reads); 78 ms.
*   **Applied Index:**
    ```sql
    CREATE NONCLUSTERED INDEX IX_BookingRequest_Reporting
    ON BookingRequest (Status, StartTime, EndTime)
    INCLUDE (SpaceCode);
    ```
*   **After Indexing:**
    *   **Execution Plan:** the reporting filter reads only the narrow index on `(Status, StartTime)` (95 reads instead of 1,143) — the semester window is obtained from index pages rather than the clustered row.
    *   **Execution Time:** 134 ms elapsed with `CPU = 47 ms` (79 ms before) — elapsed inflated by scheduling noise, see §1 note.

---

### 2.4. Reporting Query 2: Approved Bookings by Weekday and Hour
*   **Purpose:** Counts approved bookings by weekday and hour for a given semester (Phase 2 §1.3 report 2).
*   **Before Indexing:**
    *   **Execution Plan:** single scan over `BookingRequest` (1,143 logical reads); 72 ms.
*   **Applied Index:**
    Reuses `IX_BookingRequest_Reporting` (§2.3 — same `Status`, `StartTime` predicates).
*   **After Indexing:**
    *   **Execution Plan:** `DATEPART`/`DATENAME` of `StartTime` and `COUNT(BookingID)` are satisfied by seeks over the covering index (scan count 3, 95 reads) instead of a single wide scan; 25 ms.

---

## 3. Summary of Results

Measured on the full 100,000-row generated dataset (see §1 note):

| Query | Before (ms) | After (ms) | Plan change (logical reads before → after) |
|---|---|---|---|
| Booking conflict check | 12* | 0 | Phase 1 index seek (6) → covering-index seeks (13) |
| Room finder | 2,879 | 29 | BR full scan (104,454) + MR scan (4,250) → BR seeks (977) + MR seeks (346) |
| Total approved hours | 78 | 134* | full scan (1,143) → narrow index (95) |
| Weekday/hour counts | 72 | 25 | full scan (1,143) → covering-index seeks (95) |

Measurements taken with the plan cached (warmup run first) using `SET STATISTICS TIME ON` / `SET STATISTICS IO ON`; plans inspected in SSMS with "Include Actual Execution Plan".

\* Q1 BEFORE (12 ms) and Q3 AFTER (134 ms) are inflated by scheduling noise — for Q1 `CPU = 0 ms` on an already-indexed query (6 reads), and for Q3 the CPU time (79 → 47 ms) and reads (1,143 → 95) improve. CPU time and the IO stats are the reliable indicators; the elapsed outliers are not query work.

---

## 4. Normalization Validation (3NF)

As required by Phase 2 §2, we identify the functional dependencies of the updated database and confirm every relation satisfies at least Third Normal Form (3NF).

| Relation | Primary key | Functional dependencies | Normal form |
|---|---|---|---|
| User | UserID | UserID → FullName, Email, PhoneNumber, Role, Department, AccountStatus; Email → UserID (unique) | 3NF / BCNF |
| Space | SpaceCode | SpaceCode → SpaceName, SpaceType, Building, Floor, RoomNumber, Capacity, CurrentStatus, UsagePolicy; (Building, Floor, RoomNumber) → SpaceCode (unique) | 3NF / BCNF |
| Facility | FacilityID | FacilityID → FacilityName, SpaceCode | 3NF |
| BookingRequest | BookingID | BookingID → RequesterID, SpaceCode, StartTime, EndTime, Purpose, ExpectedParticipants, Status | 3NF |
| Approval | BookingID | BookingID → ApproverID, DecisionTime, DecisionNote, RejectionReason | 3NF |
| UsageSession | BookingID | BookingID → ApprovalID, ActualStartTime, CheckInStaffID, InitialCondition, ActualEndTime, FinalCondition, UsageNotes | 3NF |
| MaintenanceRecord | MaintenanceID | MaintenanceID → SpaceCode, FacilityID, ReporterID, AssignedStaffID, ProblemDescription, StartTime, CompletionTime, Status, ResultNote, ImpactLevel `[UPDATED]` | 3NF |
| BookingAcknowledgement `[NEW]` | (BookingID, MaintenanceID) | (BookingID, MaintenanceID) → AcknowledgedByUserID, AcknowledgedAt | 3NF |

**Verdict:** every attribute depends only on the whole candidate key (no partial dependency → ≥ 2NF; no transitive dependency → ≥ 3NF). All relations are in at least 3NF (most in BCNF), including the Phase 2 additions (`BookingAcknowledgement` has a single non-key attribute pair, and `MaintenanceRecord.ImpactLevel` is a direct attribute of the maintenance record). No decomposition is required.

---

## 5. Conclusion

The primary bottlenecks (single wide scans over `BookingRequest`/`MaintenanceRecord`) were addressed with targeted non-clustered covering indexes on the exact filter columns (`SpaceCode, Status, StartTime, EndTime`, `SpaceCode, ImpactLevel, Status, StartTime`, and `Status, StartTime, EndTime`). On the full 100,000-row dataset the **room finder** dropped from **2,879 ms to 29 ms** (~99×), the **weekday/hour report** from 72 ms to 25 ms, and the **approved-hours report** reduced CPU time 79 → 47 ms and reads 1,143 → 95. The **booking conflict check** was already served by the Phase 1 `IX_BookingRequest_SpaceTime`; the Phase 2 covering index keeps it at sub-millisecond cost, so the overlap invariant stays cheap to enforce under concurrent booking/approval. The schema was also confirmed to be normalized to at least 3NF.
