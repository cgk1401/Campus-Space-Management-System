# 11 — Concurrency Design (Phase 2)

**Role:** Senior Database Designer
**Basis:** updated schema in `outputs/09-updated-erd-and-logical-design-G10.md`; decisions D5 (C5) in `outputs/08-requirement-change-analysis-G10.md`; Phase 2 spec `req/business_requirement_phase_2.md` §1.2.
**Target DBMS:** Microsoft SQL Server (per AGENTS.md).
**Scope:** analytical design only — no executable T-SQL in this document (execution is Step 12, tests are Step 13).

---

## 1. The invariant to protect: BR21

> **BR21** (strengthened BR2/BR17): *No two approved bookings may overlap on the same space, regardless of whether they were created through instant (auto) approval or staff approval, and regardless of concurrent operations.* (§1.2; Step 8 §6.3.)

### 1.1. Schema hooks this design is grounded on

| Element | Where it lives | Role in the race |
|---------|----------------|------------------|
| `BookingRequest.SpaceCode` | column, FK → Space | scopes every conflict to one space |
| `BookingRequest.StartTime` / `EndTime` | columns (CHECK `EndTime > StartTime`) | the two-sided overlap predicate `Start < @End AND End > @Start` |
| `BookingRequest.Status` | column | only statuses `Approved / CheckedIn / Completed / NoShow` occupy the space (assumption A-P2-5); `Pending/Rejected/Cancelled` are ignored by the overlap check |
| `IX_BookingRequest_SpaceTime (SpaceCode, StartTime, EndTime)` | nonclustered index (Phase 1, Step 5) | serves the overlap scan but gives **no** correctness guarantee — it only makes the read fast |
| `Approval.ApproverID` | NOT NULL FK → User | both scenarios write an `Approval` row; auto-approval uses the system actor `UserID = -1` (D4) |

### 1.2. Why application-level checks are not enough

The Phase 1 flow (Step 3 BR17) ran the overlap check in application code under default **READ COMMITTED** isolation. Two transactions can both read "no approved booking exists for this window" **before either one has committed** — the other's uncommitted `UPDATE`/`INSERT` is invisible to the read. This is a classic lost-update / phantom race; the DBMS must be the single source of truth (directive 4, Step 8 §6.2).

The two scenarios below are deliberately drawn from the **two different transaction types** required by §1.2:

- **(A)** two *manual staff-approval* operations racing on the same space, and
- **(B)** an *auto-approval* (instant booking) racing a *manual staff approval*.

---

## 2. Scenario A — Two manual staff approvals racing on the same space

**Source of transaction type:** staff-approval workflow (§1.2). Both T1 and T2 are "approve a pending request" transactions executed by two facility staff members on the same space at semester start.

**Setup:**

| Tx | Operation | Space | Window | Path |
|----|-----------|-------|--------|------|
| T1 | Approve booking **B1** | S | 09:00 – 11:00 | Pending → Approved + `INSERT Approval` |
| T2 | Approve booking **B2** | S | 10:00 – 12:00 | Pending → Approved + `INSERT Approval` |

The windows overlap (10:00 – 11:00). BR21 forbids both being approved.

### 2.1. Unmitigated interleaving (READ COMMITTED, application-only check)

| Step | T1 (approve B1) | T2 (approve B2) | Observable DB state |
|------|-----------------|------------------|---------------------|
| 1 | Overlap check on `(S, 09:00, 11:00)` via `IX_BookingRequest_SpaceTime` → **0 approved rows → PASS** | | B1, B2 both `Pending` |
| 2 | | Overlap check on `(S, 10:00, 12:00)` → **0 approved rows → PASS** | still nothing approved |
| 3 | `UPDATE BookingRequest B1 SET Status='Approved'` | | B1 approved (uncommitted) |
| 4 | | `UPDATE BookingRequest B2 SET Status='Approved'` | B2 approved (uncommitted) |
| 5 | `INSERT Approval (B1, ...)`; **COMMIT** | | B1 committed, approved |
| 6 | | `INSERT Approval (B2, ...)`; **COMMIT** | B2 committed, approved |

**Result:** both checks passed at steps 1–2 because neither transaction could see the other's uncommitted write (READ COMMITTED). Both commit → **B1 and B2 are approved and overlap 10:00–11:00 on space S → BR21 is violated.** `IX_BookingRequest_SpaceTime` made both checks fast but did not prevent anything.

### 2.2. Mitigated solution — anchor lock `UPDLOCK, HOLDLOCK` on the `Space` row

Every booking/approval transaction **first** acquires an update lock held to the end of the transaction (`UPDLOCK, HOLDLOCK`) on the **parent `Space` row** keyed by `SpaceCode`, **then** performs the overlap check, **then** writes. Because every writer for the same space contends on that one anchor row, the check-then-write becomes atomic per space — the check always sees the previous writer's committed state.

| Step | T1 (approve B1) | T2 (approve B2) | Locks held / DB state |
|------|-----------------|------------------|------------------------|
| 1 | Acquire `UPDLOCK, HOLDLOCK` on Space **S** → **granted** | | exclusive lock on Space S held by T1 |
| 2 | Overlap check `(S, 09:00, 11:00)` → 0 rows → PASS | | |
| 3 | `UPDATE B1 → Approved`; `INSERT Approval` | | B1 approved (uncommitted) |
| 4 | | Acquire `UPDLOCK, HOLDLOCK` on Space **S** → **BLOCKED** | T1 still holds the anchor |
| 5 | **COMMIT** (lock released) | | B1 committed, approved |
| 6 | | Anchor acquired | |
| 7 | | Overlap check `(S, 10:00, 12:00)` → finds **B1 (09–11) overlaps → FAIL** | B2 stays `Pending`; no conflicting approval is written |

**Result:** T2's check now runs *after* T1 commits, sees the newly approved B1, and refuses to approve B2 → **BR21 restored.** One transaction always goes first; the second either fails its check or waits, never both passing.

### 2.3. Tradeoff justification (Scenario A)

| | `UPDLOCK, HOLDLOCK` on the Space anchor |
|---|---|
| Blocking | Writers on the **same** space serialize (a hot space queues its approvals). Writers on **different** spaces never touch the same anchor row → they proceed in parallel. The critical section is short (one row lock held only from check to commit), so lock-hold time is small. |
| Deadlock risk | Low **provided** the anchor is always the first lock taken in a fixed order. Risk appears only if a transaction takes other locks before the anchor (e.g., a future multi-space operation) — mitigated by a documented lock-ordering convention. |
| Throughput | Best fit: the space is the natural conflict unit — a space has only one usable window anyway, so serializing its writers is semantically justified and does not cap overall system throughput. |
| Verdict | **Right choice for Scenario A** because both racers are simple, short row-update transactions; a narrow, ordered anchor lock gives correctness with minimal collateral blocking. |

---

## 3. Scenario B — Auto-approval (instant booking) racing a manual staff approval

**Source of transaction type:** the two different creation paths in §1.2 — T1 is an **instant booking** (submission-time approval for eligible space types), T2 is the **manual staff-approval** workflow. They must be interchangeable under BR21.

**Setup:**

| Tx | Operation | Space | Window | Path |
|----|-----------|-------|--------|------|
| T1 | Instant-book **B3** | S | 09:30 – 10:30 | `INSERT BookingRequest (Status='Approved')` + `INSERT Approval` with **system actor `ApproverID = -1`** |
| T2 | Approve booking **B4** | S | 10:00 – 11:00 | Pending → Approved + `INSERT Approval` |

The windows overlap (10:00 – 10:30).

### 3.1. Unmitigated interleaving (READ COMMITTED, application-only check)

| Step | T1 (auto-approve B3) | T2 (manual approve B4) | Observable DB state |
|------|----------------------|--------------------------|----------------------|
| 1 | | Overlap check `(S, 10:00, 11:00)` → **0 rows → PASS** | B4 `Pending`; B3 not yet inserted |
| 2 | Overlap check `(S, 09:30, 10:30)` → **0 rows → PASS** | | |
| 3 | `INSERT B3 (Status='Approved')` | | B3 uncommitted |
| 4 | `INSERT Approval (B3, ApproverID=-1)`; **COMMIT** | | B3 committed, approved |
| 5 | | `UPDATE B4 → Approved`; `INSERT Approval`; **COMMIT** | B4 committed, approved |

**Result:** T2's check at step 1 ran *before* B3 existed, and READ COMMITTED hid T1's uncommitted insert at step 3. Both approve → **B3 and B4 overlap 10:00–10:30 on space S → BR21 violated.** The race here is a *phantom*: T1 introduces a brand-new row that T2's earlier scan could not have seen.

### 3.2. Mitigated solution — the same anchor lock, taken by **both** paths

Correctness requires that the two transaction types become interchangeable: **every** booking writer — instant or manual — must acquire the identical `UPDLOCK, HOLDLOCK` anchor on `Space.SpaceCode` before checking and writing. That makes T1 and T2 behave exactly like Scenario A, and it removes the phantom ambiguity entirely (a row inserted after a check can never go unnoticed, because the writer held the space's anchor the whole time).

| Step | T1 (auto-approve B3) | T2 (manual approve B4) | Locks held / DB state |
|------|----------------------|--------------------------|------------------------|
| 1 | Acquire `UPDLOCK, HOLDLOCK` on Space **S** → **granted** | | exclusive lock on Space S held by T1 |
| 2 | Overlap check `(S, 09:30, 10:30)` → 0 rows → PASS | | |
| 3 | `INSERT B3 (Status='Approved')`; `INSERT Approval (ApproverID=-1)` | | B3 uncommitted |
| 4 | | Acquire `UPDLOCK, HOLDLOCK` on Space **S** → **BLOCKED** | T1 holds the anchor |
| 5 | **COMMIT** (lock released) | | B3 committed, approved |
| 6 | | Anchor acquired | |
| 7 | | Overlap check `(S, 10:00, 11:00)` → finds **B3 (09:30–10:30) overlaps → FAIL** | B4 not approved; no conflicting approval |

**Result:** even though T1 *inserted* its booking (a phantom for any reader), T2 never got to run its check until T1 released the anchor, so the check saw B3 → **BR21 restored.** The instant path and the manual path now share one lock discipline and are interchangeable, exactly as §1.2 requires.

### 3.3. Why `SERIALIZABLE` alone is not the primary answer here (and when to use it)

`SERIALIZABLE` would add **key-range locks** along `IX_BookingRequest_SpaceTime` to block phantom inserts. However:

- The index is ordered by `(SpaceCode, StartTime, EndTime)`, so the `EndTime > @Start` half of the overlap predicate is a *residual* filter, not a contiguous key range. Whether the resulting range locks close the whole phantom window depends on the query plan — a fragile guarantee for a two-sided predicate.
- The anchor lock closes the window by construction: one lock, one key (`SpaceCode`), independent of predicate shape or plan. It is the robust choice.

**If `SERIALIZABLE` is used instead** (e.g., for a code path that cannot guarantee anchor-first ordering, or as defense-in-depth):
- **Blocking:** locks every range scanned, not just the space's anchor → much larger lock footprint and longer hold times under the semester-start burst.
- **Deadlock risk:** higher — more locks, more lock-ordering interactions (e.g., with the maintenance-escalation transaction that also scans overlapping `BookingRequest` ranges).
- **Throughput:** acceptable only at low transaction volume; the anchor approach scales better.
- **Verdict:** `SERIALIZABLE` is the conservative fallback / second layer, **not** the default. The **recommended solution for Scenario B is `UPDLOCK, HOLDLOCK` on the Space anchor, applied by both the instant and the manual path** — with `SERIALIZABLE` optionally layered on the short auto-approval transaction as belt-and-suspenders where its cost is bearable.

---

## 4. Solution comparison

| Criterion | Scenario A (manual vs manual) | Scenario B (auto vs manual) |
|-----------|-------------------------------|------------------------------|
| Race shape | lost-update on an existing row's `Status` | phantom (new row inserted by instant path) |
| Primary solution | `UPDLOCK, HOLDLOCK` on `Space.SpaceCode` anchor | `UPDLOCK, HOLDLOCK` on `Space.SpaceCode` anchor, **both paths** |
| Fallback / second layer | — | `SERIALIZABLE` (range locks) where anchor ordering cannot be guaranteed |
| Lock scope | one anchor row per space | one anchor row per space (same) |
| Main risk | hot-space writer queueing | same; plus keeping the two code paths on one lock discipline |
| BR21 after fix | restored (§2.2) | restored (§3.2) |

---

## 5. BR21 traceability

| # | Unmitigated | Mitigated |
|---|--------------|-----------|
| A | Both approval checks pass before either commits → B1 & B2 overlap 10:00–11:00 (BR21 violated) | T2 blocks on the anchor, re-checks after T1 commits, finds overlap → B2 not approved (BR21 restored) |
| B | Manual check runs before the instant booking exists; phantom insert commits → B3 & B4 overlap 10:00–10:30 (BR21 violated) | T2 blocks on the anchor held by T1, re-checks after T1 commits, finds overlap → B4 not approved (BR21 restored) |

In both cases the **uncommitted** state of the racing transaction was invisible to the other under READ COMMITTED; the anchor lock converts "read-then-write" into a serialized critical section per space, which is exactly the DB-level single source of truth demanded by C5/directive 4.

---

## 6. Implementation implications (for Step 12)

- The anchor-lock transaction must be a **short** critical section: acquire the `Space` lock **only after** the human decision (or auto-eligibility) has been made, immediately before the overlap check + write. No human think-time may be spent holding the lock.
- **Lock ordering convention:** anchor (`Space`) first, then `BookingRequest`, then `Approval`/`UsageSession`. Any future transaction that updates `MaintenanceRecord`/`Space.CurrentStatus` for an escalation must take the same anchor first to avoid deadlock with approval transactions.
- The system actor `ApproverID = -1` keeps the auto path schema-identical to the manual path (§1.1), so the same locked stored-procedure template can serve both.

---

## 7. Assumptions & open questions carried forward

- Same as Step 8 §9 A-P2-5: overlap-check "approved" = `Status IN ('Approved','CheckedIn','Completed','NoShow')`.
- **Q-P2-5** (from Step 8 §10): whether `SERIALIZABLE` on the whole transaction is acceptable for the expected booking volume vs. the narrower anchor lock — this design recommends the anchor lock as the standard and reserves `SERIALIZABLE` as fallback; index/performance evidence for the chosen approach is delivered in Step 15.

---

## 8. Next steps (not executed in this step)

1. **Step 12 — Concurrency Implementation** (`outputs/12-concurrency-implementation-G10/`): DBA implements the anchor-lock transactions (lock hints + isolation settings) as the DB-level gate.
2. **Step 13 — Concurrency Tests** (`outputs/13-concurrency-tests-G10.md`): scripts demonstrating both races (Scenario A and B) and proving BR21 holds after the fix.
