from __future__ import annotations

import os
import sys
import time
from datetime import date, timedelta
from pathlib import Path
from flask import Flask, redirect, render_template, request, session, url_for

# Allow running from either project root or AdminWebpage directory.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

app = Flask(__name__, static_folder="static", template_folder="templates")
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")
ADMIN_USERNAME = os.environ.get("ADMIN_TEST_USERNAME", "admin")
ADMIN_PASSWORD = os.environ.get("ADMIN_TEST_PASSWORD", "ridematch123")
MAX_LOGIN_ATTEMPTS = int(os.environ.get("MAX_LOGIN_ATTEMPTS", "5"))
LOGIN_LOCKOUT_SECONDS = int(os.environ.get("LOGIN_LOCKOUT_SECONDS", "300"))
SESSION_DAYS = int(os.environ.get("ADMIN_SESSION_DAYS", "365"))
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(days=SESSION_DAYS)
app.config["SESSION_REFRESH_EACH_REQUEST"] = True


def _is_logged_in() -> bool:
    return bool(session.get("logged_in"))


@app.before_request
def _persist_logged_in_session() -> None:
    if session.get("logged_in"):
        session.permanent = True


def _dashboard_data() -> dict:
    today = date.today()
    upcoming_events = [
        {"title": "License renewal audit", "type": "Compliance", "date": (today + timedelta(days=2)).isoformat()},
        {"title": "Driver onboarding review", "type": "Operations", "date": (today + timedelta(days=4)).isoformat()},
        {"title": "Safety checklist update", "type": "Safety", "date": (today + timedelta(days=7)).isoformat()},
        {"title": "Monthly budget sync", "type": "Finance", "date": (today + timedelta(days=10)).isoformat()},
        {"title": "Top driver recognition", "type": "Team", "date": (today + timedelta(days=14)).isoformat()},
    ]

    fallback_data = {
        "new_drivers": [
            {"name": "Bob Johnson", "pending_docs": True},
            {"name": "Sally Smith", "pending_docs": True},
            {"name": "Chris Ford", "pending_docs": False},
        ],
        "driver_feedback": [],
        "all_drivers": [
            {
                "account_id": 1,
                "name": "Bob Johnson",
                "rating": "5.0",
                "rides": 100,
                "status": "approved",
                "age": 32,
                "license_state": "IA",
                "license_number": "IA-214334",
                "email": "bob.johnson@example.com",
                "phone": "319-555-0201",
            },
            {
                "account_id": 2,
                "name": "Sally Smith",
                "rating": "3.5",
                "rides": 50,
                "status": "pending",
                "age": 29,
                "license_state": "IA",
                "license_number": "IA-992191",
                "email": "sally.smith@example.com",
                "phone": "319-555-0202",
            },
        ],
        "unapproved_drivers": [
            {
                "account_id": 2,
                "name": "Sally Smith",
                "rating": "3.5",
                "rides": 50,
                "status": "pending",
                "age": 29,
                "license_expires": None,
                "insurance_provider": "N/A",
                "email": "sally.smith@example.com",
                "phone": "319-555-0202",
            }
        ],
        "new_applications": [
            {"account_id": 2, "name": "Sally Smith", "approved": False, "status": "pending"},
            {"account_id": 4, "name": "Ella Patel", "approved": False, "status": "under_review"},
            {"account_id": 5, "name": "Jim Brown", "approved": False, "status": "pending"},
        ],
        "reports": [
            {"summary": "Bob Johnson - 1 star from Sarah", "action": "View"},
            {"summary": "Sally Smith - 1 star from Kylie", "action": "View"},
        ],
        "recent_reviews": [
            "5 from Sarah",
            "3 from Allie",
        ],
        "recent_rides": [
            "Bob x Kylie",
        ],
        "driver_reviews": [
            {
                "review_id": 101,
                "driver_id": 1,
                "driver_name": "Bob Johnson",
                "rider_id": 22,
                "rider_name": "Sarah Lee",
                "rating": 5,
                "comment": "Great communication and smooth pickup.",
                "review_date": today - timedelta(days=1),
            },
            {
                "review_id": 102,
                "driver_id": 2,
                "driver_name": "Sally Smith",
                "rider_id": 25,
                "rider_name": "Kylie Ross",
                "rating": 2,
                "comment": "Driver arrived late and route was unclear.",
                "review_date": today - timedelta(days=3),
            },
        ],
        "budget_breakdown": [
            {"label": "Operations", "value": 6800, "color": "#2563eb"},
            {"label": "Driver Incentives", "value": 2900, "color": "#22c55e"},
            {"label": "Safety & Compliance", "value": 2100, "color": "#f59e0b"},
            {"label": "Reserve", "value": 1700, "color": "#7c3aed"},
        ],
        "upcoming_events": upcoming_events,
        "total_driver_count": 3,
        "db_error": None,
    }

    try:
        from Database.admin_queries import fetch_dashboard_data

        data = fetch_dashboard_data()
        pending_count = len(data.get("unapproved_drivers", []))
        review_count = len(data.get("driver_reviews", []))
        total_drivers = int(data.get("total_driver_count") or len(data.get("all_drivers", [])) or 0)
        data.setdefault(
            "budget_breakdown",
            [
                {"label": "Operations", "value": max(total_drivers * 650, 2800), "color": "#2563eb"},
                {"label": "Driver Incentives", "value": max(total_drivers * 260, 1200), "color": "#22c55e"},
                {"label": "Safety & Compliance", "value": max(pending_count * 375, 900), "color": "#f59e0b"},
                {"label": "Reserve", "value": max(review_count * 180, 1000), "color": "#7c3aed"},
            ],
        )
        data.setdefault("upcoming_events", upcoming_events)
        if not data.get("new_applications"):
            data["new_applications"] = [
                {
                    "account_id": row.get("account_id"),
                    "name": row.get("name"),
                    "approved": False,
                    "status": row.get("status"),
                }
                for row in data.get("unapproved_drivers", [])
                if row.get("account_id")
            ]
        return data
    except Exception as exc:
        fallback_data["db_error"] = (
            "Showing sample data because database data could not be loaded."
        )
        app.logger.warning("Dashboard DB fallback: %s", exc)
        return fallback_data


@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if _is_logged_in():
        return redirect(url_for("home"))

    error = None
    lockout_seconds_remaining = 0
    now = time.time()
    lockout_until = session.get("login_lockout_until")

    if lockout_until:
        lockout_seconds_remaining = max(0, int(lockout_until - now))
        if lockout_seconds_remaining == 0:
            session.pop("login_lockout_until", None)
            session.pop("failed_login_attempts", None)
            lockout_until = None

    if request.method == "POST":
        if lockout_until and lockout_seconds_remaining > 0:
            error = "Too many failed attempts. Try again in a moment."
            return render_template(
                "login.html",
                error=error,
                admin_username=ADMIN_USERNAME,
                admin_password=ADMIN_PASSWORD,
                lockout_seconds_remaining=lockout_seconds_remaining,
            )

        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        if not username or not password:
            error = "Please enter both a username and password."
        elif username != ADMIN_USERNAME or password != ADMIN_PASSWORD:
            failed_attempts = int(session.get("failed_login_attempts", 0)) + 1
            session["failed_login_attempts"] = failed_attempts

            if failed_attempts >= MAX_LOGIN_ATTEMPTS:
                session["failed_login_attempts"] = 0
                session["login_lockout_until"] = now + LOGIN_LOCKOUT_SECONDS
                lockout_seconds_remaining = LOGIN_LOCKOUT_SECONDS
                error = "Too many failed attempts. Try again in a moment."
            else:
                attempts_left = MAX_LOGIN_ATTEMPTS - failed_attempts
                error = (
                    "Invalid username or password. "
                    f"{attempts_left} attempt(s) remaining."
                )
        else:
            session.permanent = True
            session["logged_in"] = True
            session["username"] = ADMIN_USERNAME
            session.pop("failed_login_attempts", None)
            session.pop("login_lockout_until", None)
            return redirect(url_for("home"))

    return render_template(
        "login.html",
        error=error,
        admin_username=ADMIN_USERNAME,
        admin_password=ADMIN_PASSWORD,
        lockout_seconds_remaining=lockout_seconds_remaining,
    )


@app.route("/home")
def home():
    if not _is_logged_in():
        return redirect(url_for("login"))

    return render_template("home.html", username=session.get("username"), current_tab="home", **_dashboard_data())


@app.route("/drivers")
def drivers():
    if not _is_logged_in():
        return redirect(url_for("login"))

    active_tab = request.args.get("tab", "all")
    if active_tab not in {"all", "verification", "reviews"}:
        active_tab = "all"

    selected_driver_id = request.args.get("driver_id", type=int)
    selected_driver = None
    if selected_driver_id:
        try:
            from Database.admin_queries import driver_detail

            selected_driver = driver_detail(selected_driver_id)
        except Exception as exc:
            app.logger.warning("Driver detail load failed: %s", exc)

    return render_template(
        "drivers.html",
        username=session.get("username"),
        current_tab="drivers",
        active_driver_tab=active_tab,
        selected_driver=selected_driver,
        verification_notice=request.args.get("notice"),
        **_dashboard_data(),
    )


@app.route("/drivers/verify/<int:driver_id>", methods=["POST"])
def verify_driver(driver_id: int):
    if not _is_logged_in():
        return redirect(url_for("login"))

    action = request.form.get("action", "").strip().lower()
    if action not in {"approve", "deny"}:
        return redirect(url_for("drivers", tab="verification", notice="invalid_action"))

    notice = "update_failed"
    try:
        from Database.admin_queries import update_driver_status

        updated = update_driver_status(driver_id, action)
        if updated:
            notice = "approved" if action == "approve" else "denied"
    except Exception as exc:
        app.logger.warning("Driver verification update failed: %s", exc)

    return redirect(url_for("drivers", tab="verification", notice=notice))


@app.route("/analytics")
def analytics():
    if not _is_logged_in():
        return redirect(url_for("login"))

    return render_template(
        "analytics.html",
        username=session.get("username"),
        current_tab="analytics",
        **_dashboard_data(),
    )


@app.route("/settings")
def settings():
    if not _is_logged_in():
        return redirect(url_for("login"))

    return render_template(
        "settings.html",
        username=session.get("username"),
        current_tab="settings",
        **_dashboard_data(),
    )


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return redirect(url_for("login"))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=True)
