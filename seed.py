"""
Review 3 database setup script (Project 41 - Campus Facility Maintenance).

Runs schema.sql (drops & recreates CampusMaintenanceDB) and then loads realistic
sample data: buildings, rooms, categories, assets, priorities, users,
technicians, materials, and ~30 requests in every lifecycle state with
assignments, work logs, material usage, status history and feedback.

Usage:
    py database/seed.py

Environment variables (CAMPUS_DB_PASSWORD is required, never hardcoded):
    CAMPUS_DB_HOST (127.0.0.1)  CAMPUS_DB_PORT (3306)  CAMPUS_DB_USER (root)
"""
import os
import random
import sys
from datetime import datetime, timedelta

import mysql.connector

HOST = os.environ.get("CAMPUS_DB_HOST", "127.0.0.1")
PORT = int(os.environ.get("CAMPUS_DB_PORT", "3306"))
USER = os.environ.get("CAMPUS_DB_USER", "root")
PASSWORD = os.environ.get("CAMPUS_DB_PASSWORD")
DB_NAME = "CampusMaintenanceDB"

if not PASSWORD:
    print("ERROR: set CAMPUS_DB_PASSWORD in the environment before running this script.")
    sys.exit(1)

SCHEMA_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema.sql")
random.seed(41)


def _strip_line_comments(sql_text):
    kept = []
    for ln in sql_text.splitlines():
        if ln.strip().startswith("--"):
            continue
        if " -- " in ln:                      # trailing comment
            ln = ln.split(" -- ")[0]
        kept.append(ln)
    return "\n".join(kept)


def run_schema(cnx):
    """Executes schema.sql. DELIMITER // blocks (triggers) are sent whole."""
    text = open(SCHEMA_PATH, "r", encoding="utf-8").read()
    cur = cnx.cursor()
    out = []                                   # list of statements
    pos = 0
    while True:
        i = text.find("DELIMITER //", pos)
        if i == -1:
            out += [s for s in _strip_line_comments(text[pos:]).split(";")]
            break
        out += [s for s in _strip_line_comments(text[pos:i]).split(";")]
        j = text.find("DELIMITER ;", i)
        block = _strip_line_comments(text[i + len("DELIMITER //"):j])
        out += [b.strip() for b in block.split("//") if b.strip()]
        pos = j + len("DELIMITER ;")
    for stmt in out:
        if stmt.strip():
            cur.execute(stmt)
    cnx.commit()
    cur.close()
    print("Schema created.")


def seed_data(cnx):
    cur = cnx.cursor()
    now = datetime.now().replace(microsecond=0)

    # ---- Buildings / Rooms ----
    buildings = [("AB1", "Academic Block 1", 4), ("AB2", "Academic Block 2", 3),
                 ("LIB", "Central Library", 3), ("HST", "Boys Hostel", 5),
                 ("ADM", "Administration Block", 2)]
    cur.executemany("INSERT INTO Building (Code,Name,Floors) VALUES (%s,%s,%s)", buildings)
    cnx.commit()
    cur.execute("SELECT BuildingID, Code FROM Building")
    bid = {c: i for i, c in cur.fetchall()}

    rooms = []
    for code, n in (("AB1", 6), ("AB2", 5)):
        for k in range(n):
            fl = k // 2 + 1
            rooms.append((bid[code], f"{fl}0{k % 2 + 1}", fl, "Lab" if k % 3 == 2 else "Classroom"))
    rooms += [(bid["LIB"], "G01", 0, "Library"), (bid["LIB"], "201", 2, "Library"),
              (bid["HST"], "101", 1, "Hostel"), (bid["HST"], "204", 2, "Hostel"),
              (bid["HST"], "WC-1", 1, "Washroom"), (bid["ADM"], "A-12", 1, "Office"),
              (bid["ADM"], "AUD", 0, "Auditorium")]
    cur.executemany("INSERT INTO Room (BuildingID,RoomNo,Floor,RoomType) VALUES (%s,%s,%s,%s)", rooms)
    cnx.commit()
    cur.execute("SELECT RoomID, BuildingID, RoomNo FROM Room ORDER BY RoomID")
    room_rows = cur.fetchall()
    room_ids = [r[0] for r in room_rows]

    # ---- Categories / Priorities ----
    cats = [("Electrical", "Wiring, fans, lights, switches"), ("Plumbing", "Taps, pipes, flush, leakage"),
            ("Furniture", "Benches, desks, chairs, doors"), ("Classroom Equipment", "Projector, board, AV"),
            ("Civil / Painting", "Walls, ceiling, paint")]
    cur.executemany("INSERT INTO Category (Name,Description) VALUES (%s,%s)", cats)
    cur.executemany("INSERT INTO Priority (Name,Rank_,SLAHours) VALUES (%s,%s,%s)",
                    [("Critical", 1, 4), ("High", 2, 24), ("Medium", 3, 72), ("Low", 4, 168)])
    cnx.commit()
    cur.execute("SELECT CategoryID, Name FROM Category")
    cid = {n: i for i, n in cur.fetchall()}
    cur.execute("SELECT PriorityID, Name FROM Priority")
    pid = {n: i for i, n in cur.fetchall()}

    # ---- Assets ----
    asset_defs = [("Ceiling Fan", "Electrical"), ("LED Tube Light", "Electrical"),
                  ("Projector", "Classroom Equipment"), ("Whiteboard", "Classroom Equipment"),
                  ("Water Tap", "Plumbing"), ("Student Bench", "Furniture")]
    assets = []
    n = 1
    for rid in room_ids:
        for name, cat in random.sample(asset_defs, 3):
            assets.append((f"AST-{n:04d}", name, cid[cat], rid,
                           (now - timedelta(days=random.randint(200, 2000))).date()))
            n += 1
    cur.executemany("INSERT INTO Asset (AssetTag,Name,CategoryID,RoomID,PurchaseDate) VALUES (%s,%s,%s,%s,%s)", assets)
    cnx.commit()

    # ---- Users ----
    users = [("Ananya Reddy", "ananya.reddy@campus.edu", "9000000001", "STUDENT"),
             ("Rohit Verma", "rohit.verma@campus.edu", "9000000002", "STUDENT"),
             ("Sneha Iyer", "sneha.iyer@campus.edu", "9000000003", "STUDENT"),
             ("Karthik Rao", "karthik.rao@campus.edu", "9000000004", "STUDENT"),
             ("Dr. Meera Nair", "meera.nair@campus.edu", "9000000005", "FACULTY"),
             ("Prof. Suresh Babu", "suresh.babu@campus.edu", "9000000006", "FACULTY"),
             ("Lakshmi Devi", "lakshmi.devi@campus.edu", "9000000007", "STAFF"),
             ("Facility Admin", "facility.admin@campus.edu", "9000000008", "ADMIN")]
    cur.executemany("INSERT INTO AppUser (Name,Email,Phone,Role) VALUES (%s,%s,%s,%s)", users)

    # ---- Technicians ----
    techs = [("Ramesh Kumar", "9100000001", "Electrical", 250, 5, 1),
             ("Imran Shaikh", "9100000002", "Electrical", 230, 4, 1),
             ("Venkat Rao", "9100000003", "Plumbing", 220, 5, 1),
             ("Suresh Goud", "9100000004", "Plumbing", 200, 3, 1),
             ("Naresh Chary", "9100000005", "Furniture", 210, 5, 1),
             ("Anil Das", "9100000006", "Classroom Equipment", 300, 4, 1),
             ("Prakash Yadav", "9100000007", "Civil / Painting", 240, 4, 1),
             ("Mohan Lal", "9100000008", "Electrical", 240, 5, 0)]   # inactive: tests assignment control
    cur.executemany("INSERT INTO Technician (Name,Phone,CategoryID,HourlyRate,MaxOpenJobs,IsActive) VALUES (%s,%s,%s,%s,%s,%s)",
                    [(a, b, cid[c], d, e, f) for a, b, c, d, e, f in techs])

    # ---- Materials ----
    mats = [("LED Tube 18W", "pcs", 180, 100), ("Ceiling Fan Capacitor", "pcs", 95, 100),
            ("Switch 6A", "pcs", 45, 120), ("Copper Wire 1.5mm", "m", 22, 500),
            ("Tap Cartridge", "pcs", 140, 80), ("PVC Pipe 1in", "m", 85, 100),
            ("Flush Valve", "pcs", 320, 70), ("Wood Screws Box", "box", 60, 90),
            ("Bench Hinge", "pcs", 75, 90), ("Projector Lamp", "pcs", 2800, 70),
            ("HDMI Cable", "pcs", 350, 70), ("Wall Putty 5kg", "bag", 410, 70)]
    cur.executemany("INSERT INTO Material (Name,Unit,UnitCost,StockQty) VALUES (%s,%s,%s,%s)", mats)
    cnx.commit()

    cur.execute("SELECT UserID FROM AppUser WHERE Role <> 'ADMIN'")
    requesters = [r[0] for r in cur.fetchall()]
    cur.execute("SELECT TechnicianID, CategoryID FROM Technician WHERE IsActive=1")
    tech_by_cat = {}
    for t, c in cur.fetchall():
        tech_by_cat.setdefault(c, []).append(t)
    cur.execute("SELECT MaterialID, Name FROM Material")
    mid = {n: i for i, n in cur.fetchall()}
    cur.execute("SELECT AssetID, RoomID, CategoryID FROM Asset")
    assets_by_cat = {}
    for a, r, c in cur.fetchall():
        assets_by_cat.setdefault(c, []).append((a, r))

    complaints = {
        "Electrical": [("Ceiling fan not working", ["Ceiling Fan Capacitor"]), ("Tube light flickering", ["LED Tube 18W"]),
                       ("Switch board sparking", ["Switch 6A", "Copper Wire 1.5mm"])],
        "Plumbing": [("Tap leaking continuously", ["Tap Cartridge"]), ("Flush not working", ["Flush Valve"]),
                     ("Pipe burst near wash area", ["PVC Pipe 1in"])],
        "Furniture": [("Bench broken", ["Wood Screws Box", "Bench Hinge"]), ("Door hinge loose", ["Bench Hinge"])],
        "Classroom Equipment": [("Projector not displaying", ["Projector Lamp"]), ("HDMI port faulty", ["HDMI Cable"])],
        "Civil / Painting": [("Ceiling seepage and peeling paint", ["Wall Putty 5kg"])],
    }
    cat_names = list(complaints)
    prio_names = ["Critical", "High", "Medium", "Medium", "Low"]

    # Target end-state per request. Each is built by REAL status updates so
    # the triggers (transition rules, history, assignment control) run.
    plan = (["CLOSED"] * 14 + ["RESOLVED"] * 2 + ["IN_PROGRESS"] * 4 + ["ON_HOLD"] * 2 +
            ["ASSIGNED"] * 3 + ["OPEN"] * 5 + ["CANCELLED"] * 2)
    random.shuffle(plan)

    for idx, target in enumerate(plan, start=1):
        cat = random.choice(cat_names)
        title, mat_names = random.choice(complaints[cat])
        if assets_by_cat.get(cid[cat]):
            asset_id, room_id = random.choice(assets_by_cat[cid[cat]])
        else:                                   # e.g. wall/ceiling issues: no tagged asset
            asset_id, room_id = None, random.choice(room_ids)
        prio = random.choice(prio_names)
        age_h = random.randint(2, 24 * 40) if target in ("CLOSED", "RESOLVED") else random.randint(1, 24 * 12)
        created = now - timedelta(hours=age_h + 6)
        reqno = f"REQ-{created.year}-{idx:04d}"
        cur.execute(
            "INSERT INTO Request (RequestNo,Title,Description,RequestedBy,RoomID,AssetID,CategoryID,PriorityID,Status,CreatedAt) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'OPEN',%s)",
            (reqno, title, f"{title}. Reported by user; please inspect at the earliest.",
             random.choice(requesters), room_id, asset_id, cid[cat], pid[prio], created))
        rid = cur.lastrowid
        history = [("OPEN", created)]

        def move(new, at):
            cur.execute("UPDATE Request SET Status=%s WHERE RequestID=%s", (new, rid))
            history.append((new, at))

        if target == "CANCELLED":
            move("CANCELLED", created + timedelta(hours=2))
        elif target != "OPEN":
            tech = random.choice(tech_by_cat[cid[cat]])
            assigned = created + timedelta(minutes=random.randint(20, 600))
            cur.execute("INSERT INTO Assignment (RequestID,TechnicianID,AssignedAt) VALUES (%s,%s,%s)", (rid, tech, assigned))
            aid = cur.lastrowid
            move("ASSIGNED", assigned)
            if target != "ASSIGNED":
                started = assigned + timedelta(hours=random.randint(1, 8))
                cur.execute("UPDATE Assignment SET AcceptedAt=%s WHERE AssignmentID=%s", (started, aid))
                move("IN_PROGRESS", started)
                hrs = round(random.choice([0.5, 1, 1.5, 2, 3, 4]), 2)
                cur.execute("SELECT HourlyRate FROM Technician WHERE TechnicianID=%s", (tech,))
                rate = cur.fetchone()[0]
                cur.execute("INSERT INTO WorkLog (AssignmentID,LogDate,HoursSpent,LabourCost,Notes) VALUES (%s,%s,%s,%s,%s)",
                            (aid, started + timedelta(hours=1), hrs, float(rate) * hrs, "Inspected and carried out repair"))
                wl = cur.lastrowid
                for mn in mat_names:
                    cur.execute("INSERT INTO MaterialUsage (WorkLogID,MaterialID,Quantity,UnitCostAtUse) VALUES (%s,%s,%s,0)",
                                (wl, mid[mn], random.randint(1, 2)))
                if target == "ON_HOLD":
                    move("ON_HOLD", started + timedelta(hours=3))
                elif target in ("RESOLVED", "CLOSED"):
                    done = started + timedelta(hours=hrs + 2)
                    move("RESOLVED", done)
                    if target == "CLOSED":
                        closed = done + timedelta(hours=random.randint(1, 20))
                        cur.execute("UPDATE Request SET Status='CLOSED', ClosedAt=%s, ClosureRemarks=%s WHERE RequestID=%s",
                                    (closed, "Issue fixed and verified by requester.", rid))
                        history.append(("CLOSED", closed))
                        if random.random() < 0.85:
                            rating = random.choices([5, 4, 3, 2, 1], [40, 30, 15, 10, 5])[0]
                            cur.execute("INSERT INTO Feedback (RequestID,Rating,Comments,SubmittedAt) VALUES (%s,%s,%s,%s)",
                                        (rid, rating, random.choice(["Quick and neat work.", "Took longer than expected.",
                                                                     "Problem solved, thanks.", "Technician was polite.",
                                                                     "Had to follow up twice."]), closed + timedelta(hours=3)))
        # Re-stamp history so ages / response times are realistic
        cur.execute("DELETE FROM StatusHistory WHERE RequestID=%s", (rid,))
        prev = None
        for st, at in history:
            cur.execute("INSERT INTO StatusHistory (RequestID,OldStatus,NewStatus,ChangedAt) VALUES (%s,%s,%s,%s)", (rid, prev, st, at))
            prev = st
    cnx.commit()
    cur.close()
    print("Sample data loaded.")


def main():
    cnx = mysql.connector.connect(host=HOST, port=PORT, user=USER, password=PASSWORD)
    run_schema(cnx)
    cnx.database = DB_NAME
    seed_data(cnx)
    cur = cnx.cursor()
    for t in ("Building", "Room", "Asset", "AppUser", "Technician", "Material", "Request",
              "Assignment", "WorkLog", "MaterialUsage", "StatusHistory", "Feedback"):
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        print(f"  {t:<14}{cur.fetchone()[0]}")
    cnx.close()


if __name__ == "__main__":
    main()
