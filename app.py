"""
Flask application for the Campus Facility Maintenance Request Management
System (DBMS Project 41, Review 3).

Serves app.html and exposes a JSON API used by the page for every real
operation (request logging, priority, assignment, work/material entry, status
update, closure, feedback, CRUD, search and reports). All database access goes
through maintenance_service.py.

Run:
    py app.py
"""
import os
import traceback

from flask import Flask, jsonify, request, send_from_directory
from werkzeug.exceptions import HTTPException

import maintenance_service as svc
from db import AppError

APP_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # .../review 3

app = Flask(__name__, static_folder=None)


def body():
    return request.get_json(force=True, silent=True) or {}


@app.errorhandler(AppError)
def handle_app_error(e):
    return jsonify({"error": e.message}), e.status


@app.errorhandler(HTTPException)
def handle_http_exception(e):
    return jsonify({"error": e.description}), e.code


@app.errorhandler(Exception)
def handle_unexpected(e):
    traceback.print_exc()
    return jsonify({"error": "Unexpected server error: " + str(e)}), 500


@app.route("/")
def index():
    return send_from_directory(APP_ROOT, "app.html")


@app.route("/favicon.ico")
def favicon():
    return "", 204


# ---- reference data / dashboard
@app.route("/api/bootstrap")
def api_bootstrap():
    return jsonify(svc.get_bootstrap())


@app.route("/api/dashboard")
def api_dashboard():
    return jsonify(svc.get_dashboard())


@app.route("/api/counts")
def api_counts():
    return jsonify(svc.get_counts())


# ---- requests
@app.route("/api/requests", methods=["GET", "POST"])
def api_requests():
    if request.method == "POST":
        return jsonify(svc.create_request(body())), 201
    a = request.args
    return jsonify({"requests": svc.list_requests(
        status=a.get("status") or None, q=(a.get("q") or "").strip() or None,
        category=a.get("category", type=int), priority=a.get("priority", type=int),
        building=a.get("building", type=int))})


@app.route("/api/requests/<int:rid>")
def api_request_detail(rid):
    return jsonify(svc.get_request(rid))


@app.route("/api/requests/<int:rid>/priority", methods=["PUT"])
def api_priority(rid):
    return jsonify(svc.set_priority(rid, body().get("priorityId")))


@app.route("/api/requests/<int:rid>/technicians")
def api_suggest_techs(rid):
    return jsonify({"technicians": svc.suggest_technicians(rid)})


@app.route("/api/requests/<int:rid>/assign", methods=["POST"])
def api_assign(rid):
    return jsonify(svc.assign_technician(rid, body().get("technicianId")))


@app.route("/api/requests/<int:rid>/unassign", methods=["POST"])
def api_unassign(rid):
    return jsonify(svc.unassign(rid))


@app.route("/api/requests/<int:rid>/status", methods=["PUT"])
def api_status(rid):
    return jsonify(svc.update_status(rid, body().get("status")))


@app.route("/api/requests/<int:rid>/worklog", methods=["POST"])
def api_worklog(rid):
    b = body()
    return jsonify(svc.add_work_log(rid, b.get("hours"), b.get("notes"))), 201


@app.route("/api/requests/<int:rid>/materials", methods=["POST"])
def api_material_use(rid):
    b = body()
    return jsonify(svc.add_material(rid, b.get("materialId"), b.get("quantity"))), 201


@app.route("/api/requests/<int:rid>/close", methods=["POST"])
def api_close(rid):
    return jsonify(svc.close_request(rid, body().get("remarks")))


@app.route("/api/requests/<int:rid>/feedback", methods=["POST"])
def api_feedback(rid):
    b = body()
    return jsonify(svc.submit_feedback(rid, b.get("rating"), b.get("comments"))), 201


# ---- CRUD manager
@app.route("/api/technicians", methods=["GET", "POST"])
def api_technicians():
    if request.method == "POST":
        return jsonify(svc.create_technician(body())), 201
    return jsonify({"technicians": svc.list_technicians()})


@app.route("/api/technicians/<int:tid>", methods=["PUT", "DELETE"])
def api_technician(tid):
    if request.method == "DELETE":
        svc.delete_technician(tid)
        return jsonify({"ok": True})
    return jsonify(svc.update_technician(tid, body()))


@app.route("/api/materials", methods=["GET", "POST"])
def api_materials():
    if request.method == "POST":
        return jsonify(svc.create_material(body())), 201
    return jsonify({"materials": svc.list_materials()})


@app.route("/api/materials/<int:mid>", methods=["PUT", "DELETE"])
def api_material(mid):
    if request.method == "DELETE":
        svc.delete_material(mid)
        return jsonify({"ok": True})
    return jsonify(svc.update_material(mid, body()))


@app.route("/api/buildings", methods=["GET", "POST"])
def api_buildings():
    if request.method == "POST":
        return jsonify(svc.create_building(body())), 201
    return jsonify({"buildings": svc.list_buildings()})


@app.route("/api/buildings/<int:bid>", methods=["DELETE"])
def api_building(bid):
    svc.delete_building(bid)
    return jsonify({"ok": True})


@app.route("/api/rooms", methods=["GET", "POST"])
def api_rooms():
    if request.method == "POST":
        return jsonify(svc.create_room(body())), 201
    return jsonify({"rooms": svc.list_rooms()})


@app.route("/api/rooms/<int:rid>", methods=["DELETE"])
def api_room(rid):
    svc.delete_room(rid)
    return jsonify({"ok": True})


@app.route("/api/users", methods=["GET", "POST"])
def api_users():
    if request.method == "POST":
        return jsonify(svc.create_user(body())), 201
    return jsonify({"users": svc.list_users()})


@app.route("/api/users/<int:uid>", methods=["DELETE"])
def api_user(uid):
    svc.delete_user(uid)
    return jsonify({"ok": True})


# ---- reports
@app.route("/api/reports/pending")
def api_rep_pending():
    return jsonify({"rows": svc.report_pending()})


@app.route("/api/reports/ageing")
def api_rep_ageing():
    return jsonify({"rows": svc.report_ageing()})


@app.route("/api/reports/response-time")
def api_rep_response():
    return jsonify({"rows": svc.report_response_time()})


@app.route("/api/reports/technician-load")
def api_rep_load():
    return jsonify({"rows": svc.report_technician_load()})


@app.route("/api/reports/building-cost")
def api_rep_building():
    return jsonify({"rows": svc.report_building_cost()})


@app.route("/api/reports/material-use")
def api_rep_material():
    return jsonify({"rows": svc.report_material_use()})


@app.route("/api/reports/feedback")
def api_rep_feedback():
    return jsonify(svc.report_feedback())


@app.route("/api/reports/summary")
def api_rep_summary():
    return jsonify(svc.report_summary())


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
