"""All database-facing business logic for the Campus Maintenance app.

Multi-step operations (assign, close, log work + materials) run inside ONE
transaction through db.get_cursor(): they commit together or roll back
together. Business rules are ALSO enforced by the database (CHECKs/triggers),
so the app cannot corrupt data even if validation here is bypassed.
"""
import re
from datetime import datetime

import db
from db import AppError

VALID_ROLES = {"STUDENT", "FACULTY", "STAFF", "ADMIN"}
ROOM_TYPES = {"Classroom", "Lab", "Office", "Hostel", "Washroom", "Library", "Auditorium", "Other"}
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
PHONE_RE = re.compile(r"^[0-9+\-\s]{7,15}$")
# Statuses a user may request through the generic status endpoint.
# ASSIGNED is reached via assign_technician; CLOSED via close_request.
USER_STATUS_TARGETS = {"IN_PROGRESS", "ON_HOLD", "RESOLVED", "CANCELLED", "OPEN"}


# ---------------------------------------------------------------- helpers
def _dt(v):
    return v.strftime("%Y-%m-%d %H:%M") if isinstance(v, datetime) else v


def _num(v):
    return float(v) if v is not None else 0.0


def _clean(row, dt_keys=(), num_keys=()):
    for k in dt_keys:
        if k in row:
            row[k] = _dt(row[k])
    for k in num_keys:
        if k in row:
            row[k] = _num(row[k])
    return row


def _need_text(value, label, max_len):
    value = (value or "").strip() if isinstance(value, str) or value is None else str(value).strip()
    if not value:
        raise AppError(f"{label} is required", 400)
    if len(value) > max_len:
        raise AppError(f"{label} must be at most {max_len} characters", 400)
    return value


def _int(value, label, lo=None, hi=None):
    if isinstance(value, bool) or not isinstance(value, int):
        try:
            value = int(value)
        except (TypeError, ValueError):
            raise AppError(f"{label} must be a whole number", 400)
    if lo is not None and value < lo:
        raise AppError(f"{label} must be at least {lo}", 400)
    if hi is not None and value > hi:
        raise AppError(f"{label} must be at most {hi}", 400)
    return value


def _dec(value, label, lo=0.0, hi=1_000_000):
    try:
        value = float(value)
    except (TypeError, ValueError):
        raise AppError(f"{label} must be a number", 400)
    if value < lo:
        raise AppError(f"{label} cannot be negative" if lo == 0 else f"{label} must be at least {lo}", 400)
    if value > hi:
        raise AppError(f"{label} is too large", 400)
    return round(value, 2)


# ---------------------------------------------------------------- bootstrap
def get_bootstrap():
    with db.get_cursor() as (cnx, cur):
        out = {}
        cur.execute("SELECT BuildingID id, Code code, Name name, Floors floors FROM Building ORDER BY Name")
        out["buildings"] = cur.fetchall()
        cur.execute("SELECT r.RoomID id, r.BuildingID buildingId, b.Code buildingCode, r.RoomNo roomNo, r.Floor floor, r.RoomType type "
                    "FROM Room r JOIN Building b ON r.BuildingID=b.BuildingID ORDER BY b.Code, r.RoomNo")
        out["rooms"] = cur.fetchall()
        cur.execute("SELECT CategoryID id, Name name FROM Category ORDER BY Name")
        out["categories"] = cur.fetchall()
        cur.execute("SELECT PriorityID id, Name name, Rank_ rank_, SLAHours sla FROM Priority ORDER BY Rank_")
        out["priorities"] = cur.fetchall()
        cur.execute("SELECT UserID id, Name name, Role role FROM AppUser ORDER BY Name")
        out["users"] = cur.fetchall()
        cur.execute("SELECT t.TechnicianID id, t.Name name, t.CategoryID categoryId, c.Name category, t.IsActive active, t.MaxOpenJobs maxJobs "
                    "FROM Technician t JOIN Category c ON t.CategoryID=c.CategoryID ORDER BY t.Name")
        out["technicians"] = cur.fetchall()
        cur.execute("SELECT MaterialID id, Name name, Unit unit, UnitCost cost, StockQty stock FROM Material ORDER BY Name")
        out["materials"] = [_clean(r, num_keys=("cost",)) for r in cur.fetchall()]
        cur.execute("SELECT AssetID id, AssetTag tag, Name name, RoomID roomId, CategoryID categoryId FROM Asset ORDER BY AssetTag")
        out["assets"] = cur.fetchall()
        cur.execute("SELECT Code code FROM Status ORDER BY Code")
        out["statuses"] = [r["code"] for r in cur.fetchall()]
        cur.execute("SELECT FromStatus f, ToStatus t FROM Status_Transition")
        out["transitions"] = cur.fetchall()
        return out


def get_dashboard():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT COUNT(*) n FROM Request")
        total = cur.fetchone()["n"]
        cur.execute("SELECT COUNT(*) n FROM Request WHERE Status NOT IN ('CLOSED','CANCELLED')")
        pending = cur.fetchone()["n"]
        cur.execute("SELECT COUNT(*) n FROM Request WHERE Status='CLOSED'")
        closed = cur.fetchone()["n"]
        cur.execute("SELECT COUNT(*) n FROM vw_PendingRequests WHERE AgeHours > SLAHours")
        overdue = cur.fetchone()["n"]
        cur.execute("SELECT COALESCE(SUM(LabourCost+MaterialCost),0) c FROM vw_RequestCost")
        cost = _num(cur.fetchone()["c"])
        cur.execute("SELECT ROUND(AVG(Rating),2) a FROM Feedback")
        avg = cur.fetchone()["a"]
        cur.execute("SELECT Status status, COUNT(*) n FROM Request GROUP BY Status")
        by_status = {r["status"]: r["n"] for r in cur.fetchall()}
        cur.execute("SELECT r.RequestID id, r.RequestNo no, r.Title title, r.Status status, p.Name priority "
                    "FROM Request r JOIN Priority p ON r.PriorityID=p.PriorityID ORDER BY r.RequestID DESC LIMIT 6")
        recent = cur.fetchall()
        cur.execute("SELECT c.Name category, COUNT(*) n FROM Request r JOIN Category c ON r.CategoryID=c.CategoryID GROUP BY c.Name ORDER BY n DESC")
        by_cat = cur.fetchall()
        return {"kpis": {"total": total, "pending": pending, "closed": closed, "overdue": overdue,
                         "cost": cost, "avgRating": _num(avg)},
                "byStatus": by_status, "recent": recent, "byCategory": by_cat}


def get_counts():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT COUNT(*) n FROM Request WHERE Status NOT IN ('CLOSED','CANCELLED')")
        pending = cur.fetchone()["n"]
        cur.execute("SELECT COUNT(*) n FROM Request WHERE Status='OPEN'")
        unassigned = cur.fetchone()["n"]
        return {"pending": pending, "unassigned": unassigned}


# ---------------------------------------------------------------- requests
_REQ_SELECT = (
    "SELECT r.RequestID id, r.RequestNo no, r.Title title, r.Description description, r.Status status, "
    "r.CreatedAt createdAt, r.ClosedAt closedAt, r.ClosureRemarks closureRemarks, "
    "u.UserID userId, u.Name requester, c.CategoryID categoryId, c.Name category, "
    "p.PriorityID priorityId, p.Name priority, p.Rank_ priorityRank, p.SLAHours sla, "
    "b.Name building, b.Code buildingCode, rm.RoomID roomId, rm.RoomNo roomNo, a.AssetTag assetTag, a.Name assetName, "
    "TIMESTAMPDIFF(HOUR, r.CreatedAt, COALESCE(r.ClosedAt, NOW())) ageHours, "
    "(SELECT t.Name FROM Assignment x JOIN Technician t ON x.TechnicianID=t.TechnicianID "
    "  WHERE x.RequestID=r.RequestID AND x.IsActive=1) technician "
    "FROM Request r JOIN AppUser u ON r.RequestedBy=u.UserID "
    "JOIN Category c ON r.CategoryID=c.CategoryID JOIN Priority p ON r.PriorityID=p.PriorityID "
    "JOIN Room rm ON r.RoomID=rm.RoomID JOIN Building b ON rm.BuildingID=b.BuildingID "
    "LEFT JOIN Asset a ON r.AssetID=a.AssetID "
)


def _next_request_no(cur):
    year = datetime.now().year
    cur.execute("SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(RequestNo,'-',-1) AS UNSIGNED)),0)+1 n "
                "FROM Request WHERE RequestNo LIKE %s FOR UPDATE", (f"REQ-{year}-%",))
    return f"REQ-{year}-{cur.fetchone()['n']:04d}"


def create_request(p):
    title = _need_text(p.get("title"), "Title", 150)
    desc = (p.get("description") or "").strip()
    if len(desc) > 2000:
        raise AppError("Description must be at most 2000 characters", 400)
    user_id = _int(p.get("userId"), "Requester", 1)
    room_id = _int(p.get("roomId"), "Room", 1)
    cat_id = _int(p.get("categoryId"), "Category", 1)
    prio_id = _int(p.get("priorityId"), "Priority", 1)
    asset_id = p.get("assetId")
    asset_id = _int(asset_id, "Asset", 1) if asset_id not in (None, "", 0) else None

    with db.get_cursor() as (cnx, cur):
        for tbl, col, val, label in (("AppUser", "UserID", user_id, "Requester"), ("Room", "RoomID", room_id, "Room"),
                                     ("Category", "CategoryID", cat_id, "Category"), ("Priority", "PriorityID", prio_id, "Priority")):
            cur.execute(f"SELECT 1 FROM {tbl} WHERE {col}=%s", (val,))
            if not cur.fetchone():
                raise AppError(f"{label} not found", 404)
        if asset_id:
            cur.execute("SELECT RoomID FROM Asset WHERE AssetID=%s", (asset_id,))
            a = cur.fetchone()
            if not a:
                raise AppError("Asset not found", 404)
            if a["RoomID"] != room_id:
                raise AppError("The selected asset is not located in the selected room", 400)
        no = _next_request_no(cur)
        cur.execute("INSERT INTO Request (RequestNo,Title,Description,RequestedBy,RoomID,AssetID,CategoryID,PriorityID) "
                    "VALUES (%s,%s,%s,%s,%s,%s,%s,%s)", (no, title, desc or None, user_id, room_id, asset_id, cat_id, prio_id))
        return {"id": cur.lastrowid, "no": no, "status": "OPEN"}


def list_requests(status=None, q=None, category=None, priority=None, building=None):
    sql = _REQ_SELECT + "WHERE 1=1 "
    params = []
    if status == "PENDING":
        sql += "AND r.Status NOT IN ('CLOSED','CANCELLED') "
    elif status:
        sql += "AND r.Status=%s "
        params.append(status)
    if q:
        sql += "AND (r.RequestNo LIKE %s OR r.Title LIKE %s OR u.Name LIKE %s) "
        params += [f"%{q}%"] * 3
    if category:
        sql += "AND r.CategoryID=%s "
        params.append(category)
    if priority:
        sql += "AND r.PriorityID=%s "
        params.append(priority)
    if building:
        sql += "AND rm.BuildingID=%s "
        params.append(building)
    sql += "ORDER BY r.RequestID DESC"
    with db.get_cursor() as (cnx, cur):
        cur.execute(sql, params)
        return [_clean(r, dt_keys=("createdAt", "closedAt")) for r in cur.fetchall()]


def get_request(request_id):
    with db.get_cursor() as (cnx, cur):
        cur.execute(_REQ_SELECT + "WHERE r.RequestID=%s", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        _clean(r, dt_keys=("createdAt", "closedAt"))
        cur.execute("SELECT a.AssignmentID id, t.Name technician, t.TechnicianID technicianId, a.AssignedAt assignedAt, "
                    "a.AcceptedAt acceptedAt, a.IsActive active FROM Assignment a JOIN Technician t ON a.TechnicianID=t.TechnicianID "
                    "WHERE a.RequestID=%s ORDER BY a.AssignmentID", (request_id,))
        r["assignments"] = [_clean(x, dt_keys=("assignedAt", "acceptedAt")) for x in cur.fetchall()]
        cur.execute("SELECT w.WorkLogID id, w.AssignmentID assignmentId, w.LogDate logDate, w.HoursSpent hours, w.LabourCost labour, w.Notes notes "
                    "FROM WorkLog w JOIN Assignment a ON w.AssignmentID=a.AssignmentID WHERE a.RequestID=%s ORDER BY w.WorkLogID", (request_id,))
        r["workLogs"] = [_clean(x, dt_keys=("logDate",), num_keys=("hours", "labour")) for x in cur.fetchall()]
        cur.execute("SELECT mu.UsageID id, mu.WorkLogID workLogId, m.Name material, m.Unit unit, mu.Quantity qty, "
                    "mu.UnitCostAtUse unitCost, mu.Quantity*mu.UnitCostAtUse total "
                    "FROM MaterialUsage mu JOIN Material m ON mu.MaterialID=m.MaterialID "
                    "JOIN WorkLog w ON mu.WorkLogID=w.WorkLogID JOIN Assignment a ON w.AssignmentID=a.AssignmentID "
                    "WHERE a.RequestID=%s ORDER BY mu.UsageID", (request_id,))
        r["materials"] = [_clean(x, num_keys=("unitCost", "total")) for x in cur.fetchall()]
        cur.execute("SELECT OldStatus oldStatus, NewStatus newStatus, ChangedAt changedAt FROM StatusHistory WHERE RequestID=%s ORDER BY HistoryID", (request_id,))
        r["history"] = [_clean(x, dt_keys=("changedAt",)) for x in cur.fetchall()]
        cur.execute("SELECT Rating rating, Comments comments, SubmittedAt submittedAt FROM Feedback WHERE RequestID=%s", (request_id,))
        fb = cur.fetchone()
        r["feedback"] = _clean(fb, dt_keys=("submittedAt",)) if fb else None
        cur.execute("SELECT LabourCost l, MaterialCost m FROM vw_RequestCost WHERE RequestID=%s", (request_id,))
        c = cur.fetchone()
        r["cost"] = {"labour": _num(c["l"]), "material": _num(c["m"]), "total": _num(c["l"]) + _num(c["m"])}
        cur.execute("SELECT ToStatus t FROM Status_Transition WHERE FromStatus=%s", (r["status"],))
        r["allowedNext"] = [x["t"] for x in cur.fetchall()]
        return r


def set_priority(request_id, priority_id):
    priority_id = _int(priority_id, "Priority", 1)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT Status FROM Request WHERE RequestID=%s FOR UPDATE", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        if r["Status"] in ("CLOSED", "CANCELLED"):
            raise AppError("Priority of a closed or cancelled request cannot be changed", 409)
        cur.execute("SELECT 1 FROM Priority WHERE PriorityID=%s", (priority_id,))
        if not cur.fetchone():
            raise AppError("Priority not found", 404)
        cur.execute("UPDATE Request SET PriorityID=%s WHERE RequestID=%s", (priority_id, request_id))
        return {"id": request_id, "priorityId": priority_id}


# ---------------------------------------------------------------- assignment
def suggest_technicians(request_id):
    """Technicians of the request's category with their current load (for the UI)."""
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT CategoryID FROM Request WHERE RequestID=%s", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        cur.execute(
            "SELECT t.TechnicianID id, t.Name name, t.IsActive active, t.MaxOpenJobs maxJobs, c.Name category, "
            "(SELECT COUNT(*) FROM Assignment a JOIN Request q ON a.RequestID=q.RequestID "
            "  WHERE a.TechnicianID=t.TechnicianID AND a.IsActive=1 AND q.Status IN ('ASSIGNED','IN_PROGRESS','ON_HOLD')) openJobs, "
            "(t.CategoryID=%s) matches "
            "FROM Technician t JOIN Category c ON t.CategoryID=c.CategoryID WHERE t.IsActive=1 "
            "ORDER BY matches DESC, openJobs ASC, t.Name", (r["CategoryID"],))
        return cur.fetchall()


def assign_technician(request_id, technician_id):
    technician_id = _int(technician_id, "Technician", 1)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT Status FROM Request WHERE RequestID=%s FOR UPDATE", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        if r["Status"] != "OPEN":
            raise AppError(f"Only OPEN requests can be assigned (this one is {r['Status']})", 409)
        cur.execute("SELECT TechnicianID FROM Technician WHERE TechnicianID=%s FOR UPDATE", (technician_id,))
        if not cur.fetchone():
            raise AppError("Technician not found", 404)
        # trigger enforces: technician active, below MaxOpenJobs, request OPEN
        cur.execute("INSERT INTO Assignment (RequestID, TechnicianID) VALUES (%s,%s)", (request_id, technician_id))
        aid = cur.lastrowid
        cur.execute("UPDATE Request SET Status='ASSIGNED' WHERE RequestID=%s", (request_id,))
        return {"assignmentId": aid, "status": "ASSIGNED"}


def unassign(request_id):
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT Status FROM Request WHERE RequestID=%s FOR UPDATE", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        if r["Status"] != "ASSIGNED":
            raise AppError("Only a request that is ASSIGNED (not yet started) can be unassigned", 409)
        cur.execute("UPDATE Assignment SET IsActive=0 WHERE RequestID=%s AND IsActive=1", (request_id,))
        cur.execute("UPDATE Request SET Status='OPEN' WHERE RequestID=%s", (request_id,))
        return {"status": "OPEN"}


# ---------------------------------------------------------------- status / closure
def update_status(request_id, new_status):
    if new_status == "CLOSED":
        raise AppError("Use the Close action - closure remarks are required", 400)
    if new_status == "ASSIGNED":
        raise AppError("Use the Assign action to assign a technician", 400)
    if new_status not in USER_STATUS_TARGETS:
        raise AppError("Invalid status", 400)
    if new_status == "OPEN":
        return unassign(request_id)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT Status FROM Request WHERE RequestID=%s FOR UPDATE", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        cur.execute("SELECT 1 FROM Status_Transition WHERE FromStatus=%s AND ToStatus=%s", (r["Status"], new_status))
        if not cur.fetchone():
            raise AppError(f"Invalid status transition: {r['Status']} -> {new_status}", 409)
        cur.execute("UPDATE Request SET Status=%s WHERE RequestID=%s", (new_status, request_id))
        if new_status == "IN_PROGRESS":
            cur.execute("UPDATE Assignment SET AcceptedAt=COALESCE(AcceptedAt, NOW()) WHERE RequestID=%s AND IsActive=1", (request_id,))
        if new_status == "CANCELLED":
            cur.execute("UPDATE Assignment SET IsActive=0 WHERE RequestID=%s AND IsActive=1", (request_id,))
        return {"status": new_status}


def close_request(request_id, remarks):
    remarks = _need_text(remarks, "Closure remarks", 500)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT Status FROM Request WHERE RequestID=%s FOR UPDATE", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        if r["Status"] != "RESOLVED":
            raise AppError(f"Only RESOLVED requests can be closed (this one is {r['Status']})", 409)
        cur.execute("UPDATE Request SET Status='CLOSED', ClosedAt=NOW(), ClosureRemarks=%s WHERE RequestID=%s", (remarks, request_id))
        cur.execute("UPDATE Assignment SET IsActive=0 WHERE RequestID=%s AND IsActive=1", (request_id,))
        return {"status": "CLOSED"}


# ---------------------------------------------------------------- work & materials
def add_work_log(request_id, hours, notes):
    hours = _dec(hours, "Hours spent", lo=0.01, hi=24)
    notes = (notes or "").strip()
    if len(notes) > 300:
        raise AppError("Notes must be at most 300 characters", 400)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT a.AssignmentID aid, t.HourlyRate rate FROM Assignment a JOIN Technician t ON a.TechnicianID=t.TechnicianID "
                    "WHERE a.RequestID=%s AND a.IsActive=1", (request_id,))
        a = cur.fetchone()
        if not a:
            raise AppError("This request has no active assignment - assign a technician first", 409)
        cost = round(float(a["rate"]) * hours, 2)
        cur.execute("INSERT INTO WorkLog (AssignmentID,HoursSpent,LabourCost,Notes) VALUES (%s,%s,%s,%s)",
                    (a["aid"], hours, cost, notes or None))      # trigger: job must be live
        return {"workLogId": cur.lastrowid, "labourCost": cost}


def add_material(request_id, material_id, qty):
    material_id = _int(material_id, "Material", 1)
    qty = _int(qty, "Quantity", 1, 10000)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT w.WorkLogID id FROM WorkLog w JOIN Assignment a ON w.AssignmentID=a.AssignmentID "
                    "WHERE a.RequestID=%s AND a.IsActive=1 ORDER BY w.WorkLogID DESC LIMIT 1", (request_id,))
        w = cur.fetchone()
        if not w:
            raise AppError("Log work first - materials are recorded against a work log entry", 409)
        cur.execute("SELECT Name, StockQty, UnitCost FROM Material WHERE MaterialID=%s FOR UPDATE", (material_id,))
        m = cur.fetchone()
        if not m:
            raise AppError("Material not found", 404)
        if m["StockQty"] < qty:
            raise AppError(f"Insufficient stock for {m['Name']}: {m['StockQty']} available, {qty} requested", 409)
        # trigger copies UnitCost into UnitCostAtUse and reduces stock
        cur.execute("INSERT INTO MaterialUsage (WorkLogID,MaterialID,Quantity,UnitCostAtUse) VALUES (%s,%s,%s,%s)",
                    (w["id"], material_id, qty, m["UnitCost"]))
        return {"usageId": cur.lastrowid, "total": round(float(m["UnitCost"]) * qty, 2)}


# ---------------------------------------------------------------- feedback
def submit_feedback(request_id, rating, comments):
    rating = _int(rating, "Rating", 1, 5)
    comments = (comments or "").strip()
    if len(comments) > 500:
        raise AppError("Comments must be at most 500 characters", 400)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT Status FROM Request WHERE RequestID=%s FOR UPDATE", (request_id,))
        r = cur.fetchone()
        if not r:
            raise AppError("Request not found", 404)
        if r["Status"] != "CLOSED":
            raise AppError("Feedback can be given only after the request is CLOSED", 409)
        cur.execute("SELECT 1 FROM Feedback WHERE RequestID=%s", (request_id,))
        if cur.fetchone():
            raise AppError("Feedback has already been submitted for this request", 409)
        cur.execute("INSERT INTO Feedback (RequestID,Rating,Comments) VALUES (%s,%s,%s)", (request_id, rating, comments or None))
        return {"ok": True}


# ---------------------------------------------------------------- CRUD manager
def _guarded_delete(checks, delete_sql, params, block_msg, nf_msg):
    with db.get_cursor() as (cnx, cur):
        for sql in checks:
            cur.execute(sql, params)
            if cur.fetchone()["n"]:
                raise AppError(block_msg, 409)
        cur.execute(delete_sql, params)
        if cur.rowcount == 0:
            raise AppError(nf_msg, 404)


def list_technicians():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT t.TechnicianID id, t.Name name, t.Phone phone, c.Name category, t.CategoryID categoryId, t.HourlyRate rate, "
                    "t.MaxOpenJobs maxJobs, t.IsActive active FROM Technician t JOIN Category c ON t.CategoryID=c.CategoryID ORDER BY t.TechnicianID")
        return [_clean(r, num_keys=("rate",)) for r in cur.fetchall()]


def _tech_fields(p):
    name = _need_text(p.get("name"), "Name", 100)
    phone = (p.get("phone") or "").strip()
    if phone and not PHONE_RE.match(phone):
        raise AppError("Phone must be 7-15 digits", 400)
    return (name, phone or None, _int(p.get("categoryId"), "Category", 1),
            _dec(p.get("rate"), "Hourly rate", hi=100000), _int(p.get("maxJobs", 5), "Max open jobs", 1, 50),
            1 if p.get("active", True) else 0)


def create_technician(p):
    f = _tech_fields(p)
    with db.get_cursor() as (cnx, cur):
        cur.execute("INSERT INTO Technician (Name,Phone,CategoryID,HourlyRate,MaxOpenJobs,IsActive) VALUES (%s,%s,%s,%s,%s,%s)", f)
        return {"id": cur.lastrowid}


def update_technician(tid, p):
    f = _tech_fields(p)
    with db.get_cursor() as (cnx, cur):
        cur.execute("UPDATE Technician SET Name=%s,Phone=%s,CategoryID=%s,HourlyRate=%s,MaxOpenJobs=%s,IsActive=%s WHERE TechnicianID=%s", f + (tid,))
        if cur.rowcount == 0:
            cur.execute("SELECT 1 FROM Technician WHERE TechnicianID=%s", (tid,))
            if not cur.fetchone():
                raise AppError("Technician not found", 404)
        return {"id": tid}


def delete_technician(tid):
    _guarded_delete(["SELECT COUNT(*) n FROM Assignment WHERE TechnicianID=%s"], "DELETE FROM Technician WHERE TechnicianID=%s", (tid,),
                    "Cannot delete: this technician has assignment history (deactivate instead)", "Technician not found")


def list_materials():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT MaterialID id, Name name, Unit unit, UnitCost cost, StockQty stock FROM Material ORDER BY MaterialID")
        return [_clean(r, num_keys=("cost",)) for r in cur.fetchall()]


def create_material(p):
    name = _need_text(p.get("name"), "Name", 100)
    unit = _need_text(p.get("unit") or "pcs", "Unit", 20)
    cost = _dec(p.get("cost"), "Unit cost", hi=1_000_000)
    stock = _int(p.get("stock", 0), "Stock quantity", 0, 1_000_000)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT 1 FROM Material WHERE Name=%s", (name,))
        if cur.fetchone():
            raise AppError(f"Material '{name}' already exists", 409)
        cur.execute("INSERT INTO Material (Name,Unit,UnitCost,StockQty) VALUES (%s,%s,%s,%s)", (name, unit, cost, stock))
        return {"id": cur.lastrowid}


def update_material(mid, p):
    cost = _dec(p.get("cost"), "Unit cost", hi=1_000_000)
    stock = _int(p.get("stock"), "Stock quantity", 0, 1_000_000)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT 1 FROM Material WHERE MaterialID=%s", (mid,))
        if not cur.fetchone():
            raise AppError("Material not found", 404)
        cur.execute("UPDATE Material SET UnitCost=%s, StockQty=%s WHERE MaterialID=%s", (cost, stock, mid))
        return {"id": mid}


def delete_material(mid):
    _guarded_delete(["SELECT COUNT(*) n FROM MaterialUsage WHERE MaterialID=%s"], "DELETE FROM Material WHERE MaterialID=%s", (mid,),
                    "Cannot delete: this material has usage records", "Material not found")


def list_buildings():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT b.BuildingID id, b.Code code, b.Name name, b.Floors floors, "
                    "(SELECT COUNT(*) FROM Room r WHERE r.BuildingID=b.BuildingID) rooms FROM Building b ORDER BY b.BuildingID")
        return cur.fetchall()


def create_building(p):
    code = _need_text(p.get("code"), "Code", 10).upper()
    name = _need_text(p.get("name"), "Name", 100)
    floors = _int(p.get("floors", 1), "Floors", 1, 100)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT 1 FROM Building WHERE Code=%s", (code,))
        if cur.fetchone():
            raise AppError(f"Building code '{code}' already exists", 409)
        cur.execute("INSERT INTO Building (Code,Name,Floors) VALUES (%s,%s,%s)", (code, name, floors))
        return {"id": cur.lastrowid}


def delete_building(bid):
    _guarded_delete(["SELECT COUNT(*) n FROM Room WHERE BuildingID=%s"], "DELETE FROM Building WHERE BuildingID=%s", (bid,),
                    "Cannot delete: this building still has rooms", "Building not found")


def list_rooms():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT r.RoomID id, b.Code buildingCode, r.BuildingID buildingId, r.RoomNo roomNo, r.Floor floor, r.RoomType type, "
                    "(SELECT COUNT(*) FROM Request q WHERE q.RoomID=r.RoomID) requests "
                    "FROM Room r JOIN Building b ON r.BuildingID=b.BuildingID ORDER BY b.Code, r.RoomNo")
        return cur.fetchall()


def create_room(p):
    bid = _int(p.get("buildingId"), "Building", 1)
    room_no = _need_text(p.get("roomNo"), "Room number", 20)
    floor = _int(p.get("floor", 0), "Floor", 0, 100)
    rtype = p.get("type") or "Classroom"
    if rtype not in ROOM_TYPES:
        raise AppError("Invalid room type", 400)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT Floors FROM Building WHERE BuildingID=%s", (bid,))
        b = cur.fetchone()
        if not b:
            raise AppError("Building not found", 404)
        if floor >= b["Floors"] + 1:
            raise AppError(f"This building has only {b['Floors']} floor(s)", 400)
        cur.execute("SELECT 1 FROM Room WHERE BuildingID=%s AND RoomNo=%s", (bid, room_no))
        if cur.fetchone():
            raise AppError(f"Room {room_no} already exists in this building", 409)
        cur.execute("INSERT INTO Room (BuildingID,RoomNo,Floor,RoomType) VALUES (%s,%s,%s,%s)", (bid, room_no, floor, rtype))
        return {"id": cur.lastrowid}


def delete_room(rid):
    _guarded_delete(["SELECT COUNT(*) n FROM Request WHERE RoomID=%s", "SELECT COUNT(*) n FROM Asset WHERE RoomID=%s"],
                    "DELETE FROM Room WHERE RoomID=%s", (rid,),
                    "Cannot delete: this room has assets or requests", "Room not found")


def list_users():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT u.UserID id, u.Name name, u.Email email, u.Phone phone, u.Role role, "
                    "(SELECT COUNT(*) FROM Request r WHERE r.RequestedBy=u.UserID) requests FROM AppUser u ORDER BY u.UserID")
        return cur.fetchall()


def create_user(p):
    name = _need_text(p.get("name"), "Name", 100)
    email = _need_text(p.get("email"), "Email", 120).lower()
    if not EMAIL_RE.match(email):
        raise AppError("Enter a valid email address", 400)
    phone = (p.get("phone") or "").strip()
    if phone and not PHONE_RE.match(phone):
        raise AppError("Phone must be 7-15 digits", 400)
    role = p.get("role")
    if role not in VALID_ROLES:
        raise AppError("Invalid role", 400)
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT 1 FROM AppUser WHERE Email=%s", (email,))
        if cur.fetchone():
            raise AppError(f"A user with email '{email}' already exists", 409)
        cur.execute("INSERT INTO AppUser (Name,Email,Phone,Role) VALUES (%s,%s,%s,%s)", (name, email, phone or None, role))
        return {"id": cur.lastrowid}


def delete_user(uid):
    _guarded_delete(["SELECT COUNT(*) n FROM Request WHERE RequestedBy=%s"], "DELETE FROM AppUser WHERE UserID=%s", (uid,),
                    "Cannot delete: this user has raised requests", "User not found")


# ---------------------------------------------------------------- reports
def report_pending():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT RequestID id, RequestNo no, Title title, Status status, Priority priority, Category category, Building building, "
                    "RoomNo roomNo, CreatedAt createdAt, AgeHours ageHours, SLAHours sla "
                    "FROM vw_PendingRequests ORDER BY PriorityRank, CreatedAt")
        rows = cur.fetchall()
        for r in rows:
            _clean(r, dt_keys=("createdAt",))
            r["overdue"] = r["ageHours"] > r["sla"]
        return rows


def report_ageing():
    """Pending requests bucketed by age (nested query in the FROM clause)."""
    with db.get_cursor() as (cnx, cur):
        cur.execute(
            "SELECT bucket, COUNT(*) n FROM ("
            "  SELECT CASE WHEN AgeHours < 24 THEN '0-1 day' WHEN AgeHours < 72 THEN '1-3 days' "
            "              WHEN AgeHours < 168 THEN '3-7 days' ELSE '7+ days' END bucket "
            "  FROM vw_PendingRequests) x GROUP BY bucket")
        found = {r["bucket"]: r["n"] for r in cur.fetchall()}
        return [{"bucket": b, "count": found.get(b, 0)} for b in ("0-1 day", "1-3 days", "3-7 days", "7+ days")]


def report_response_time():
    """Response time = first assignment time - request creation time, per priority."""
    with db.get_cursor() as (cnx, cur):
        cur.execute(
            "SELECT p.Name priority, p.SLAHours sla, COUNT(*) requests, "
            "ROUND(AVG(TIMESTAMPDIFF(MINUTE, r.CreatedAt, fa.FirstAssigned))/60, 2) avgHours, "
            "SUM(TIMESTAMPDIFF(HOUR, r.CreatedAt, fa.FirstAssigned) <= p.SLAHours) withinSla "
            "FROM Request r JOIN Priority p ON r.PriorityID=p.PriorityID "
            "JOIN (SELECT RequestID, MIN(AssignedAt) FirstAssigned FROM Assignment GROUP BY RequestID) fa ON fa.RequestID=r.RequestID "
            "GROUP BY p.PriorityID, p.Name, p.SLAHours, p.Rank_ ORDER BY p.Rank_")
        rows = cur.fetchall()
        for r in rows:
            r["avgHours"] = _num(r["avgHours"])
            r["withinSla"] = int(r["withinSla"] or 0)
        return rows


def report_technician_load():
    with db.get_cursor() as (cnx, cur):
        cur.execute(
            "SELECT t.TechnicianID id, t.Name name, c.Name category, t.IsActive active, t.MaxOpenJobs maxJobs, "
            "COALESCE(SUM(a.IsActive=1 AND r.Status IN ('ASSIGNED','IN_PROGRESS','ON_HOLD')),0) openJobs, "
            "COUNT(a.AssignmentID) totalJobs, "
            "COALESCE(SUM(r.Status='CLOSED'),0) closedJobs "
            "FROM Technician t JOIN Category c ON t.CategoryID=c.CategoryID "
            "LEFT JOIN Assignment a ON a.TechnicianID=t.TechnicianID LEFT JOIN Request r ON a.RequestID=r.RequestID "
            "GROUP BY t.TechnicianID, t.Name, c.Name, t.IsActive, t.MaxOpenJobs ORDER BY openJobs DESC, t.Name")
        rows = cur.fetchall()
        for r in rows:
            for k in ("openJobs", "closedJobs"):
                r[k] = int(r[k])
            r["loadPct"] = round(r["openJobs"] / r["maxJobs"] * 100) if r["maxJobs"] else 0
        return rows


def report_building_cost():
    with db.get_cursor() as (cnx, cur):
        cur.execute(
            "SELECT b.Name building, b.Code code, COUNT(r.RequestID) requests, "
            "COALESCE(SUM(vc.LabourCost),0) labour, COALESCE(SUM(vc.MaterialCost),0) material, "
            "COALESCE(SUM(vc.LabourCost+vc.MaterialCost),0) total "
            "FROM Building b LEFT JOIN Room rm ON rm.BuildingID=b.BuildingID LEFT JOIN Request r ON r.RoomID=rm.RoomID "
            "LEFT JOIN vw_RequestCost vc ON vc.RequestID=r.RequestID GROUP BY b.BuildingID, b.Name, b.Code ORDER BY total DESC")
        return [_clean(r, num_keys=("labour", "material", "total")) for r in cur.fetchall()]


def report_material_use():
    with db.get_cursor() as (cnx, cur):
        cur.execute(
            "SELECT m.Name material, m.Unit unit, m.StockQty stock, COALESCE(SUM(mu.Quantity),0) used, "
            "COALESCE(SUM(mu.Quantity*mu.UnitCostAtUse),0) cost FROM Material m "
            "LEFT JOIN MaterialUsage mu ON mu.MaterialID=m.MaterialID GROUP BY m.MaterialID, m.Name, m.Unit, m.StockQty ORDER BY cost DESC")
        rows = cur.fetchall()
        for r in rows:
            r["used"] = int(r["used"])
            r["cost"] = _num(r["cost"])
        return rows


def report_feedback():
    with db.get_cursor() as (cnx, cur):
        cur.execute(
            "SELECT t.Name technician, COUNT(f.FeedbackID) responses, ROUND(AVG(f.Rating),2) avgRating "
            "FROM Technician t JOIN Assignment a ON a.TechnicianID=t.TechnicianID JOIN Feedback f ON f.RequestID=a.RequestID "
            "GROUP BY t.TechnicianID, t.Name ORDER BY avgRating DESC")
        by_tech = [_clean(r, num_keys=("avgRating",)) for r in cur.fetchall()]
        cur.execute("SELECT Rating rating, COUNT(*) n FROM Feedback GROUP BY Rating ORDER BY Rating DESC")
        dist = {r["rating"]: r["n"] for r in cur.fetchall()}
        cur.execute("SELECT r.RequestNo no, r.Title title, f.Rating rating, f.Comments comments FROM Feedback f "
                    "JOIN Request r ON f.RequestID=r.RequestID WHERE f.Rating <= (SELECT AVG(Rating) FROM Feedback) - 1 "
                    "ORDER BY f.Rating, f.SubmittedAt DESC LIMIT 8")
        low = cur.fetchall()
        return {"byTechnician": by_tech, "distribution": [{"rating": k, "count": dist.get(k, 0)} for k in (5, 4, 3, 2, 1)], "belowAverage": low}


def report_summary():
    with db.get_cursor() as (cnx, cur):
        cur.execute("SELECT COALESCE(SUM(LabourCost),0) l, COALESCE(SUM(MaterialCost),0) m FROM vw_RequestCost")
        c = cur.fetchone()
        cur.execute("SELECT ROUND(AVG(TIMESTAMPDIFF(HOUR, CreatedAt, ClosedAt)),1) h FROM Request WHERE Status='CLOSED'")
        res = cur.fetchone()["h"]
        cur.execute("SELECT ROUND(AVG(Rating),2) a FROM Feedback")
        avg = cur.fetchone()["a"]
        cur.execute("SELECT COUNT(*) n FROM vw_PendingRequests WHERE AgeHours > SLAHours")
        overdue = cur.fetchone()["n"]
        return {"labour": _num(c["l"]), "material": _num(c["m"]), "avgResolutionHours": _num(res),
                "avgRating": _num(avg), "overdue": overdue}
