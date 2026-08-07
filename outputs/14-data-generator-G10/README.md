# 14 — Data Generator (Group G10)

Large-scale synthetic data generator and workload generator with 10,000 test queries for the **Campus Space Management System** (Microsoft SQL Server).

---

## 1. Directory Structure

- `generate_data.py`: Generates **100,000 to 500,000 records** for `BookingRequest` and related tables (`User`, `Space`, `Facility`, `MaintenanceRecord`, `Approval`, `UsageSession`, `BookingAcknowledgement`) spanning 3 academic years (2023 - 2026).
- `generate_queries.py`: Generates a workload of **10,000 SQL queries (Workload Queries)** with randomized parameters to evaluate and optimize indexes (Index Tuning) for the report `15-index-tuning-report-G10.md`.
- `sql_batches/`: Directory containing auto-chunked SQL DML files (5,000 records per file) for safe execution on SQL Server.

---

## 2. Business & Data Constraints

The generated data strictly complies with the business rules defined in `outputs/01-business-req-analysis-G10.md` and `outputs/08-requirement-change-analysis-G10.md`:

1. **Time Range**: September 1, 2023, to August 31, 2026 (3 academic years).
2. **Data Scales**:
   - `User`: 3,000 users (Students, Lecturers, TAs, Staff, Admin + User ID `-1` for System Auto-Approval).
   - `Space`: 125 spaces (classrooms, auditoriums, labs) across 5 buildings (Building A..E).
   - `Facility`: ~375 equipment items.
   - `MaintenanceRecord`: 3,000 maintenance events (both `OutOfService` and `Advisory` levels).
   - `BookingRequest`: **100,000 records** (can be increased up to 500,000 by adjusting parameters in `generate_data.py`).
   - `Approval`, `UsageSession`, `BookingAcknowledgement`: Synchronously generated to match the lifecycle of each booking.

---

## 3. Execution Guide

### Step 1: Generate Synthetic Data & SQL Batches
Run the Python script to generate the SQL files:
```bash
python outputs/14-data-generator-G10/generate_data.py
```

### Step 2: Load Data into SQL Server
Execute the `.sql` files inside the `outputs/14-data-generator-G10/sql_batches/` directory in the following order:
1. File `00_master_seed.sql` (Contains User, Space, Facility, MaintenanceRecord metadata).
2. Files `01_bookings_batch_01.sql` to `01_bookings_batch_20.sql` (Contains 100,000 BookingRequests & lifecycle records).

Use the `sqlcmd` command-line utility:
```bash
sqlcmd -S localhost -d CampusSpaceManagement -i outputs/14-data-generator-G10/sql_batches/00_master_seed.sql
```

### Step 3: Generate 10,000 Query Workloads for Index Tuning
Run the query workload generator script:
```bash
python outputs/14-data-generator-G10/generate_queries.py
```
The resulting file `benchmark_10k_queries.sql` will be used to measure response times (Elapsed time, CPU time, and Logical reads) before and after index tuning for `15-index-tuning-report-G10.md`.
