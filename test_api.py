"""
Automated API tests for Review 3 (Project 41 - Campus Maintenance).

Runs against a LIVE server + database (seeded with database/seed.py). Each test
creates its own request/technician so it does not depend on the demo data.

    cd backend && py app.py          # terminal 1
    py -m pytest tests/test_api.py -v  # terminal 2
"""
import os
import uuid

import requests

BASE = os.environ.get("CAMPUS_API_BASE", "http://127.0.0.1:5000")


def get(path, **kw):
    return requests.get(BASE + path, **kw)


def post(path, body=None):
    return requests.post(BASE + path, json=body or {})


def put(path, body=None):
    return requests.put(BASE + path, json=body or {})


def boot():
    return get("/api/bootstrap").json()


def new_request(category_name="Electrical", priority_name="Medium"):
    b = boot()
    cat = next(c for c in b["categories"] if c["name"] == category_name)
    prio = next(p for p in b["priorities"] if p["name"] == priority_name)
    r = post("/api/requests", {"title": "PyTest " + uuid.uuid4().hex[:6], "description": "auto", "userId": b["users"][0]["id"],
                               "roomId": b["rooms"][0]["id"], "categoryId": cat["id"], "priorityId": prio["id"]})
    assert r.status_code == 201, r.text
    return r.json()


def new_tech(max_jobs=5, active=True, category_name="Electrical"):
    b = boot()
    cat = next(c for c in b["categories"] if c["name"] == category_name)
    r = post("/api/technicians", {"name": "Tech " + uuid.uuid4().hex[:5], "phone": "9999999999", "categoryId": cat["id"],
                                  "rate": 200, "maxJobs": max_jobs, "active": active})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def to_resolved(rid, tech):
    assert post(f"/api/requests/{rid}/assign", {"technicianId": tech}).status_code == 200
    assert put(f"/api/requests/{rid}/status", {"status": "IN_PROGRESS"}).status_code == 200
    assert post(f"/api/requests/{rid}/worklog", {"hours": 2, "notes": "fixed"}).status_code == 201
    assert put(f"/api/requests/{rid}/status", {"status": "RESOLVED"}).status_code == 200


# ---------------------------------------------------------------- basics
def test_bootstrap_and_dashboard():
    assert "buildings" in boot()
    d = get("/api/dashboard").json()
    assert "total" in d["kpis"]


def test_unique_sequential_request_numbers():
    a, b = new_request(), new_request()
    assert a["no"] != b["no"] and a["no"].startswith("REQ-")


# ---------------------------------------------------------------- validation
def test_missing_title_rejected():
    b = boot()
    r = post("/api/requests", {"title": "  ", "userId": b["users"][0]["id"], "roomId": b["rooms"][0]["id"],
                               "categoryId": b["categories"][0]["id"], "priorityId": b["priorities"][0]["id"]})
    assert r.status_code == 400


def test_asset_must_belong_to_room():
    b = boot()
    asset = b["assets"][0]
    other_room = next(r for r in b["rooms"] if r["id"] != asset["roomId"])
    r = post("/api/requests", {"title": "x", "userId": b["users"][0]["id"], "roomId": other_room["id"], "assetId": asset["id"],
                               "categoryId": asset["categoryId"], "priorityId": b["priorities"][0]["id"]})
    assert r.status_code == 400


def test_invalid_email_and_role():
    assert post("/api/users", {"name": "A", "email": "bad", "role": "STUDENT"}).status_code == 400
    assert post("/api/users", {"name": "A", "email": f"{uuid.uuid4().hex[:6]}@x.edu", "role": "BOSS"}).status_code == 400


def test_negative_cost_and_stock_rejected():
    assert post("/api/materials", {"name": "Neg " + uuid.uuid4().hex[:4], "unit": "pcs", "cost": -5, "stock": 1}).status_code == 400
    assert post("/api/materials", {"name": "Neg " + uuid.uuid4().hex[:4], "unit": "pcs", "cost": 5, "stock": -1}).status_code == 400


# ---------------------------------------------------------------- assignment control
def test_inactive_technician_cannot_be_assigned():
    rid = new_request()["id"]
    tech = new_tech(active=False)
    r = post(f"/api/requests/{rid}/assign", {"technicianId": tech})
    assert r.status_code == 409 and "inactive" in r.json()["error"].lower()


def test_max_open_jobs_enforced():
    tech = new_tech(max_jobs=1)
    r1, r2 = new_request()["id"], new_request()["id"]
    assert post(f"/api/requests/{r1}/assign", {"technicianId": tech}).status_code == 200
    r = post(f"/api/requests/{r2}/assign", {"technicianId": tech})
    assert r.status_code == 409 and "maximum" in r.json()["error"].lower()


def test_cannot_assign_twice():
    rid = new_request()["id"]
    assert post(f"/api/requests/{rid}/assign", {"technicianId": new_tech()}).status_code == 200
    assert post(f"/api/requests/{rid}/assign", {"technicianId": new_tech()}).status_code == 409


# ---------------------------------------------------------------- status transitions
def test_invalid_transition_blocked():
    rid = new_request()["id"]
    r = put(f"/api/requests/{rid}/status", {"status": "RESOLVED"})      # OPEN -> RESOLVED not allowed
    assert r.status_code == 409


def test_direct_close_requires_resolved():
    rid = new_request()["id"]
    assert post(f"/api/requests/{rid}/close", {"remarks": "done"}).status_code == 409


def test_status_endpoint_refuses_closed():
    rid = new_request()["id"]
    assert put(f"/api/requests/{rid}/status", {"status": "CLOSED"}).status_code == 400


# ---------------------------------------------------------------- full lifecycle
def test_full_lifecycle_with_costs_and_feedback():
    rid = new_request()["id"]
    tech = new_tech()
    mats = boot()["materials"]
    m = next(x for x in mats if x["stock"] >= 5)
    assert post(f"/api/requests/{rid}/assign", {"technicianId": tech}).status_code == 200
    assert put(f"/api/requests/{rid}/status", {"status": "IN_PROGRESS"}).status_code == 200
    assert post(f"/api/requests/{rid}/materials", {"materialId": m["id"], "quantity": 1}).status_code == 409   # no work log yet
    assert post(f"/api/requests/{rid}/worklog", {"hours": 2, "notes": "fix"}).status_code == 201
    assert post(f"/api/requests/{rid}/materials", {"materialId": m["id"], "quantity": 2}).status_code == 201
    assert put(f"/api/requests/{rid}/status", {"status": "RESOLVED"}).status_code == 200
    # closure needs remarks
    assert post(f"/api/requests/{rid}/close", {"remarks": "  "}).status_code == 400
    assert post(f"/api/requests/{rid}/close", {"remarks": "Verified OK"}).status_code == 200
    d = get(f"/api/requests/{rid}").json()
    assert d["status"] == "CLOSED" and d["closedAt"]
    assert abs(d["cost"]["labour"] - 400) < 0.01                      # 2h x 200
    assert abs(d["cost"]["material"] - 2 * m["cost"]) < 0.01
    assert [h["newStatus"] for h in d["history"]] == ["OPEN", "ASSIGNED", "IN_PROGRESS", "RESOLVED", "CLOSED"]
    # feedback
    assert post(f"/api/requests/{rid}/feedback", {"rating": 6}).status_code == 400
    assert post(f"/api/requests/{rid}/feedback", {"rating": 5, "comments": "great"}).status_code == 201
    assert post(f"/api/requests/{rid}/feedback", {"rating": 4}).status_code == 409       # only once


def test_feedback_before_close_rejected():
    rid = new_request()["id"]
    assert post(f"/api/requests/{rid}/feedback", {"rating": 5}).status_code == 409


def test_insufficient_stock_rejected():
    rid = new_request()["id"]
    to_progress = new_tech()
    post(f"/api/requests/{rid}/assign", {"technicianId": to_progress})
    put(f"/api/requests/{rid}/status", {"status": "IN_PROGRESS"})
    post(f"/api/requests/{rid}/worklog", {"hours": 1})
    m = boot()["materials"][0]
    assert post(f"/api/requests/{rid}/materials", {"materialId": m["id"], "quantity": m["stock"] + 1000}).status_code == 409


def test_worklog_hours_validation():
    rid = new_request()["id"]
    post(f"/api/requests/{rid}/assign", {"technicianId": new_tech()})
    put(f"/api/requests/{rid}/status", {"status": "IN_PROGRESS"})
    assert post(f"/api/requests/{rid}/worklog", {"hours": 0}).status_code == 400
    assert post(f"/api/requests/{rid}/worklog", {"hours": 30}).status_code == 400


def test_priority_change_and_search():
    r = new_request(priority_name="Low")
    b = boot()
    high = next(p for p in b["priorities"] if p["name"] == "High")
    assert put(f"/api/requests/{r['id']}/priority", {"priorityId": high["id"]}).status_code == 200
    found = get("/api/requests", params={"q": r["no"]}).json()["requests"]
    assert len(found) == 1 and found[0]["priority"] == "High"


# ---------------------------------------------------------------- CRUD protection
def test_cannot_delete_building_with_rooms():
    b = boot()["buildings"][0]
    assert requests.delete(f"{BASE}/api/buildings/{b['id']}").status_code == 409


def test_cannot_delete_technician_with_history():
    tech = new_tech()
    rid = new_request()["id"]
    post(f"/api/requests/{rid}/assign", {"technicianId": tech})
    assert requests.delete(f"{BASE}/api/technicians/{tech}").status_code == 409


# ---------------------------------------------------------------- reports
def test_all_reports_respond():
    for p in ("pending", "ageing", "response-time", "technician-load", "building-cost", "material-use", "feedback", "summary"):
        assert get(f"/api/reports/{p}").status_code == 200, p


def test_unknown_route_is_json_404():
    r = get("/api/nope")
    assert r.status_code == 404 and "error" in r.json()
