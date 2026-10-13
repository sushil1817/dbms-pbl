# Project 41 - Campus Facility Maintenance Request Management System (Review 3)

Python (Flask) + MySQL 8 + single-page front end. Same layout as the Project 17 reference.

```
review 3/
  app.html                   front end (served by Flask at /)
  backend/  app.py  maintenance_service.py  db.py  config.py  requirements.txt
  database/ schema.sql  seed.py  queries.sql
  tests/    test_api.py  requirements.txt
```

## Run (Windows / PowerShell)
```
pip install -r backend/requirements.txt
$env:CAMPUS_DB_PASSWORD = 'your-mysql-root-password'
py database/seed.py          # drops & recreates CampusMaintenanceDB, loads sample data
cd backend ; py app.py       # open http://127.0.0.1:5000
```
Tests (server running): `pip install -r tests/requirements.txt` then `py -m pytest tests/test_api.py -v`

Optional env vars: CAMPUS_DB_HOST, CAMPUS_DB_PORT, CAMPUS_DB_USER, CAMPUS_DB_NAME.

## Where each required feature lives
| Requirement | UI | Code |
|---|---|---|
| Request logging | Log Request | `create_request` |
| Priority setting | Request modal -> Set priority | `set_priority` |
| Technician assignment | Assignment Desk / modal | `assign_technician`, trigger `trg_assignment_control` |
| Work & material entry | Request modal (IN_PROGRESS) | `add_work_log`, `add_material`, trigger `trg_usage_stock` |
| Status update | Request modal buttons | `update_status`, trigger `trg_request_status_check` |
| Closure | Request modal (RESOLVED) | `close_request`, CHECK `chk_closure_details` |
| Feedback | Request modal (CLOSED) | `submit_feedback`, trigger `trg_feedback_closed_only` |
| CRUD + search | CRUD Manager, All Requests filters | `*_technician/material/building/room/user`, `list_requests` |
| Reports | Reports (pending, ageing, response time, technician load, building cost, material use, feedback) | `report_*`, views `vw_PendingRequests`, `vw_RequestCost` |

## Business rules (enforced in the database, not just the app)
1. Unique request numbers - `UNIQUE(RequestNo)`; app generates `REQ-YYYY-NNNN`.
2. Closure details required - CHECK on Request + trigger (needs ClosedAt and remarks).
3. Non-negative materials/costs - CHECK on UnitCost, StockQty, Quantity, LabourCost, HourlyRate, UnitCostAtUse.
4. Valid status transitions - table `Status_Transition` consulted by trigger.
   OPEN->ASSIGNED/CANCELLED; ASSIGNED->IN_PROGRESS/OPEN/CANCELLED; IN_PROGRESS->ON_HOLD/RESOLVED;
   ON_HOLD->IN_PROGRESS/CANCELLED; RESOLVED->CLOSED/IN_PROGRESS.
5. Assignment control - trigger: technician must be active, request must be OPEN, technician below
   `MaxOpenJobs`; generated column + UNIQUE gives at most one active assignment per request.

## Transactions & indexing
Every operation runs in one transaction (`db.get_cursor`: commit/rollback). Assign locks the request
and technician rows with `SELECT ... FOR UPDATE`. Indexes: see the INDEXES section of `schema.sql`.

## 3NF notes (for the viva)
- Priority -> SLAHours lives in Priority (not Request). Category name lives in Category.
- Building/Room/Asset are separate; Request stores RoomID (building derived via Room).
- Material cost is stored once in Material; `UnitCostAtUse` in MaterialUsage is a deliberate snapshot of the
  price at the time of use (history), not a transitive dependency.
- Costs per request are NOT stored; they are derived by view `vw_RequestCost`.
- Status history is its own table written by triggers.
