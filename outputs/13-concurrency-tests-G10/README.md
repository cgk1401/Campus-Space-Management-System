# 13 — Concurrency Tests (Phase 2)

**Role:** Senior Database Administrator (DBA)
**Basis:** Scenario A and Scenario B defined in `outputs/11-concurrency-design-G10.md`; solution implemented in `outputs/12-concurrency-implementation-G10.sql`.
**Target DBMS:** Microsoft SQL Server (T-SQL), database `CampusSpaceManagement`.
**Invariant under test:** **BR21** — no two approved bookings may overlap on the same space, regardless of instant vs. manual approval and regardless of concurrency (Phase 2 §1.2; Step 11 §1).

---

## 1. What this folder proves

For **each** scenario from Step 11 this folder provides an **unmitigated** demo
(raw ad-hoc T-SQL that bypasses the anchor lock — BR21 is violated, proving the
race is real and the fix is *necessary*) and a **mitigated** demo (the actual
Step 12 procedures run in two real sessions — T2 blocks, then is refused, and
BR21 holds, proving the fix is *effective*).

| Scenario | Racing transactions | Windows on test space | Overlap |
|----------|---------------------|-----------------------|---------|
| **A** (Step 11 §2) | T1 manual-approve **B1** vs T2 manual-approve **B2** (two staff) | 09:00–11:00 vs 10:00–12:00 | 10:00–11:00 |
| **B** (Step 11 §3) | T1 **instant-book B3** (auto, system actor −1) vs T2 manual-approve **B4** | 09:30–10:30 vs 10:00–11:00 | 10:00–10:30 |

The unmitigated interleavings are forced with a small in-database **signal/control
table** (`dbo.TT_Concurrency_Control`, created by `00-setup.sql`) plus
`WAITFOR DELAY`, so each run reproduces the exact read/write timelines in
Step 11 §2.1 / §3.1 deterministically across two real sessions.

---

## 2. Prerequisites (must be applied in this order)

1. Phase 1 schema from `outputs/05-db-definition-G10.md` (tables `User`, `Space`,
   `BookingRequest`, `Approval`, `MaintenanceRecord`, index `IX_BookingRequest_SpaceTime`).
2. Phase 2 migration from `outputs/10-schema-migration-G10.sql`
   (`MaintenanceRecord.ImpactLevel`, `BookingAcknowledgement`, system actor `UserID = -1`).
3. Concurrency implementation from `outputs/12-concurrency-implementation-G10.sql`
   (`fn_BookingConflictCount`, `usp_ApproveBooking_Auto`, `usp_ApproveBooking_Manual`).

> All test data is namespaced to dedicated test spaces (`TEST-CC-A`, `TEST-CC-B`)
> and test users (`test.*@campus.test`). Nothing in this folder touches production
> data, and `*3-cleanup.sql` / `99-teardown.sql` remove everything the tests created.

---

## 3. Run matrix

Open **two SSMS query windows** on `CampusSpaceManagement` (or two `sqlcmd`
connections). Window 1 drives each demo; Window 2 is the second racing session.

### 3.0. One-time setup

| Step | Window 1 | Window 2 |
|------|----------|----------|
| 1 | Run `00-setup.sql` (creates test control table + `tt_SetSignal` / `tt_WaitSignal`). | — |

### 3.1. Scenario A — two manual staff approvals

| Step | Window 1 | Window 2 | Then run (any window) | Expected |
|------|----------|----------|------------------------|----------|
| A0 | Run `scenario-A/A0-setup.sql` | — | — | test space/users/B1/B2 created |
| A1 | Run `A1a-unmitigated-session1.sql` | As soon as W1 prints *"Start A1b in Window 2 now"*, run `A1b-unmitigated-session2.sql` | `A1c-unmitigated-verify.sql` | Overlap offender count = **2** → BR21 **violated** (both B1 and B2 Approved) |
| A2 | Run `A3-cleanup.sql`, then `A0-setup.sql` again | — | — | reset test space |
| A3 | Run `A2a-mitigated-session1.sql` | ~2–3 s after W1 starts, run `A2b-mitigated-session2.sql` | While W1 is in its `WAITFOR DELAY` pause, run `evidence-blocking.sql` **in Window 1**; after W1 completes, run `A2c-mitigated-verify.sql` | W2 prints error **51009** (overlap refused); evidence shows W2 blocked on the anchor (`LCK_M_U`, `blocking_session_id` = W1); overlap offender count = **0** → BR21 **holds** |

### 3.2. Scenario B — auto (instant) booking vs manual approval

| Step | Window 1 | Window 2 | Then run (any window) | Expected |
|------|----------|----------|------------------------|----------|
| B0 | Run `scenario-B/B0-setup.sql` | — | — | test space/users/B4 created (B3 is created by the instant path) |
| B1 | Run `B1a-unmitigated-session1.sql` | As soon as W1 waits for *"t2_checked"* (printed), run `B1b-unmitigated-session2.sql` | `B1c-unmitigated-verify.sql` | Overlap offender count = **2** → BR21 **violated** (B3 instant + B4 approved overlap) |
| B2 | Run `B3-cleanup.sql`, then `B0-setup.sql` again | — | — | reset test space |
| B3 | Run `B2a-mitigated-session1.sql` | ~2–3 s after W1 starts, run `B2b-mitigated-session2.sql` | While W1 is in its `WAITFOR DELAY` pause, run `evidence-blocking.sql` **in Window 1**; after W1 completes, run `B2c-mitigated-verify.sql` | W2 prints error **51009**; evidence shows W2 blocked on the anchor; overlap offender count = **0** → BR21 **holds** |

### 3.3. Teardown

After all demos, run `99-teardown.sql` in any window. It deletes all test data and
drops the test helper objects (`tt_SetSignal`, `tt_WaitSignal`,
`TT_Concurrency_Control`).

> **Re-running a demo:** always re-run the scenario `A0/B0-setup.sql` first — it
> resets the signal table so the forced interleave is re-armed, and it guards
> inserts so it is safe to run repeatedly.

---

## 4. How the interleave is forced (validity of the demo)

The two sessions coordinate through the tiny `dbo.TT_Concurrency_Control`
table (`tt_SetSignal` writes it, `tt_WaitSignal` polls it). Each direction of
an interleave owns its **own** control row (Scenario A: T1 → Id 1, T2 → Id 11;
Scenario B: T2 → Id 2, T1 → Id 12) so a session's signal write can never block
the peer's signal write. `tt_WaitSignal` deliberately reads the control table
with `READUNCOMMITTED` so a waiter can see the peer's signal even while the peer
is still mid-transaction — which is exactly the state the forced interleave needs.

- **Unmitigated (A):** W1 (T1) runs its overlap check, updates `B1 → Approved`
  and writes its `Approval` row **without committing**, then signals `t1_updated`.
  W2 (T2) only then runs its overlap check — under READ COMMITTED it cannot see
  T1's uncommitted change, so it also passes — updates `B2`, commits, signals
  `t2_committed`, then T1 commits. T2's check uses `READPAST` so it skips the
  row T1 is currently locking instead of blocking on it (an application check
  that ignores in-flight rows — the classic insufficient check). This is exactly
  the Step 11 §2.1 timeline.
- **Unmitigated (B):** W2 (T2, manual) runs its overlap check **before** B3
  exists and signals `t2_checked`; W1 (T1, instant) then inserts B3 (Approved) +
  `Approval` with `ApproverID = -1` and commits (`t1_committed`); only then does
  T2 approve B4. T2's earlier check could never have seen the phantom B3 — the
  Step 11 §3.1 timeline.
- **Mitigated (both):** W1 runs the **actual** Step 12 procedure inside an outer
  transaction, so the procedure's `UPDLOCK, HOLDLOCK` anchor on the `Space` row
  is held until W1's outer `COMMIT` (~30 s later). W2 runs the **actual** Step 12
  procedure and genuinely blocks on that anchor; when W1 commits, W2's check
  finally runs *after* T1's committed state is visible, so it refuses the overlap
  (error 51009) and rolls back.

---

## 5. Evidence captured

- `evidence-blocking.sql` (run in Window 1 during the mitigated pause) reads
  `sys.dm_exec_requests` + `sys.dm_tran_locks` and proves:
  - Window 2's request is `suspended`, `wait_type = LCK_M_U` (or similar
    `LCK_M_*`), `wait_resource` = the anchor key, `blocking_session_id` =
    Window 1's session; and
  - Window 1 holds the `UPDLOCK`/exclusive lock on the anchor `Space` key.
- The `*c-*-verify.sql` queries count **approved bookings that participate in at
  least one overlap** on the test space:
  - **2** after an unmitigated demo (both racers approved → BR21 violated), and
  - **0** after a mitigated demo (only the first racer approved; the second stays
    `Pending` and was refused → BR21 holds).

---

## 6. Expected final state per demo

| Demo | W2 outcome | Final bookings on test space | Overlap offender count | BR21 |
|------|------------|------------------------------|------------------------|------|
| A unmitigated | commits B2 approval | B1 + B2 both `Approved` | 2 | **violated** (proves fix necessary) |
| A mitigated | blocks, then error 51009 | B1 `Approved`, B2 `Pending` | 0 | **holds** (proves fix effective) |
| B unmitigated | commits B4 approval | B3 + B4 both `Approved` | 2 | **violated** (proves fix necessary) |
| B mitigated | blocks, then error 51009 | B3 `Approved`, B4 `Pending` | 0 | **holds** (proves fix effective) |

---

## 7. Files

```
13-concurrency-tests-G10/
├── README.md                        this document
├── 00-setup.sql                     test control table + tt_SetSignal / tt_WaitSignal
├── evidence-blocking.sql            DMV proof of blocking + anchor lock (mitigated demos)
├── scenario-A/
│   ├── A0-setup.sql                 test space TEST-CC-A, staff A/B, student, B1, B2 (Pending)
│   ├── A1a-unmitigated-session1.sql T1: check→update B1→hold uncommitted→wait T2→commit
│   ├── A1b-unmitigated-session2.sql T2: check (sees nothing)→approve B2→commit first
│   ├── A1c-unmitigated-verify.sql   expect overlap offender count = 2
│   ├── A2a-mitigated-session1.sql   T1 via usp_ApproveBooking_Manual, anchor held 30 s
│   ├── A2b-mitigated-session2.sql   T2 via usp_ApproveBooking_Manual (blocks, then 51009)
│   ├── A2c-mitigated-verify.sql     expect overlap offender count = 0
│   └── A3-cleanup.sql               remove scenario-A test data
├── scenario-B/
│   ├── B0-setup.sql                 test space TEST-CC-B, users, B4 (Pending)
│   ├── B1a-unmitigated-session1.sql T1: wait T2 check→insert B3 (Approved)→commit
│   ├── B1b-unmitigated-session2.sql T2: check (B3 absent)→signal→approve B4→commit
│   ├── B1c-unmitigated-verify.sql   expect overlap offender count = 2
│   ├── B2a-mitigated-session1.sql   T1 via usp_ApproveBooking_Auto, anchor held 30 s
│   ├── B2b-mitigated-session2.sql   T2 via usp_ApproveBooking_Manual (blocks, then 51009)
│   ├── B2c-mitigated-verify.sql     expect overlap offender count = 0
│   └── B3-cleanup.sql               remove scenario-B test data
└── 99-teardown.sql                  delete all test data + drop test helpers
```
