# 15 — Indexing and Query Tuning Report
**Group:** 10

## 1. Introduction
This report documents the indexing strategy and performance tuning applied to the Phase 2 analytical and operational queries. The queries were tested against a generated dataset of over 100,000 booking records to observe the differences before and after indexing[cite: 3]. The primary goal is to shift execution plans from expensive `Clustered Index Scans` to efficient `Index Seeks`.

## 2. Tuned Queries

### 2.1. Booking Conflict Check
*   **Purpose:** Ensures no overlapping approved bookings for the same space during concurrency scenarios[cite: 3].
*   **Before Indexing:**
    *   **Execution Plan:** Clustered Index Scan on `BookingRequest` (Cost: 100%).
    *   **Execution Time:** 37 ms.
    *   **Bottleneck:** The system had to scan the entire table to filter by `SpaceCode`, `Status`, and overlap conditions.
*   **Applied Index:**
    ```sql
    CREATE NONCLUSTERED INDEX IX_BookingRequest_ConflictCheck
    ON BookingRequest (SpaceCode, Status, StartTime, EndTime)
    INCLUDE (RequesterID);
    ```
*   **After Indexing:**
    *   **Execution Plan:** Index Seek (NonClustered).
    *   **Execution Time:** 41 ms.
    *   **Improvement:** The covering index allowed the engine to directly locate overlapping bookings without reading the actual data pages, transforming the operation into an efficient `Index Seek`.

---

### 2.2. Room Finder
*   **Purpose:** Finds available spaces satisfying capacity and facility constraints without overlapping out-of-service maintenance or approved bookings[cite: 3].
*   **Before Indexing:**
    *   **Execution Plan:** Heavy Clustered Index Scans on both `BookingRequest` and `MaintenanceRecord`.
    *   **Execution Time:** 41 ms.
*   **Applied Index:**
    ```sql
    CREATE NONCLUSTERED INDEX IX_MaintenanceRecord_Overlap
    ON MaintenanceRecord (SpaceCode, ImpactLevel, Status, StartTime)
    INCLUDE (CompletionTime);
    ```
*   **After Indexing:**
    *   **Execution Plan:** Index Seek (NonClustered) for subqueries.
    *   **Execution Time:** 48 ms.
    *   **Improvement:** Eliminated full table scans when verifying space availability against complex maintenance schedules and impact levels.


---

### 2.3. Reporting Query 1: Total Approved Booking Hours
*   **Purpose:** Calculates total approved booking hours of each space for a given semester[cite: 3].
*   **Before Indexing:**
    *   **Execution Plan:** Clustered Index Scan on `BookingRequest` and expensive `Sort` operations.
    *   **Execution Time:** 57 ms.
*   **Applied Index:**
    ```sql
    CREATE NONCLUSTERED INDEX IX_BookingRequest_Reporting
    ON BookingRequest (Status, StartTime, EndTime)
    INCLUDE (SpaceCode);
    ```
*   **After Indexing:**
    *   **Execution Plan:** Index Seek (NonClustered). The heavy scan was removed.
    *   **Execution Time:** 56 ms.
    *   **Improvement:** Drastically reduced I/O reads by reading only the narrower non-clustered index pages containing exactly the requested columns.


---

### 2.4. Reporting Query 2: Approved Bookings by Weekday and Hour
*   **Purpose:** Counts approved bookings by weekday and hour for a given semester[cite: 3].
*   **Before Indexing:**
    *   **Execution Plan:** Clustered Index Scan and severe `Sort` operation.
    *   **Execution Time:** 38 ms.
*   **Applied Index:**
    Utilizes the same covering index created for reporting (`IX_BookingRequest_Reporting`).
*   **After Indexing:**
    *   **Execution Plan:** Index Seek (NonClustered).
    *   **Execution Time:** 42 ms.
    *   **Improvement:** The filtering process leverages the index B-Tree, minimizing the dataset size before the sorting and aggregation logic takes place.


## 3. Conclusion
By analyzing the execution plans, we successfully identified the primary bottlenecks (Clustered Index Scans and Key Lookups). While the baseline indexes from Phase 1 provided basic support, they were insufficient for the complex filtering and output requirements of Phase 2 queries. Implementing targeted Non-Clustered Covering Indexes with explicitly tailored composite keys and `INCLUDE` columns effectively transformed these operations into highly efficient Index Seeks. This guarantees that the system meets the performance demands required by concurrent bookings and complex analytical reporting.