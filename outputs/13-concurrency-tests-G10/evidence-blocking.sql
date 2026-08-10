-- =====================================================================
-- 13 — Concurrency Tests / evidence-blocking.sql
-- =====================================================================
-- Run this file in WINDOW 1 (the session that holds the Space anchor)
-- DURING the mitigated demo's WAITFOR DELAY pause, i.e. while Window 2's
-- approval procedure is genuinely blocked.
--
-- Evidence captured:
--   1. Window 2's blocked request: status = suspended, wait_type = LCK_M_U
--      (update-lock wait on the anchor), blocking_session_id = Window 1.
--   2. Window 1's own lock on the Space anchor key (UPDLOCK, HOLDLOCK held
--      to the end of the outer transaction).
--
-- Expected output (Scenario A and B are identical in shape):
--   blocked_session | wait_type | blocked_by | wait_resource
--   ----------------+-----------+------------+-----------------------------
--   <W2 session id> | LCK_M_U   | <W1 sess>  | KEY: 7a...(...<hex anchor>)
--
-- If Window 2 was started too late and the row set is empty, re-run the
-- mitigated demo (README §3) so the two sessions overlap in time.
-- =====================================================================

USE CampusSpaceManagement;
GO

SET NOCOUNT ON;

PRINT '--- Blocked request(s) from the racing session (Window 2) ---';
SELECT
    r.session_id          AS blocked_session,
    r.status              AS req_status,
    r.wait_type           AS wait_type,
    r.wait_time           AS wait_ms,
    r.blocking_session_id AS blocked_by,
    r.wait_resource       AS wait_resource,
    LEFT(t.[text], 200)   AS blocked_statement
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id <> @@SPID
  AND r.status = 'suspended'
  AND r.wait_type LIKE 'LCK_M_%'
ORDER BY r.session_id;

PRINT '--- Anchor lock held by THIS (Window 1) session ---';
SELECT
    request_mode      AS lock_mode,
    request_status    AS lock_status,
    resource_type     AS resource_type,
    resource_database_id AS db_id,
    resource_description  AS resource_description
FROM sys.dm_tran_locks
WHERE request_session_id = @@SPID
  AND resource_type = 'KEY';
GO
