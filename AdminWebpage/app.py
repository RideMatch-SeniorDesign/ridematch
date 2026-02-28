from __future__ import annotations

import os
import sys
import time
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any
from flask import Flask, abort, redirect, render_template, request, send_file, session, url_for
from dotenv import load_dotenv, set_key

# Allow running from either project root or AdminWebpage directory.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
ADMIN_PATH = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
if str(ADMIN_PATH) not in sys.path:
    sys.path.insert(0, str(ADMIN_PATH))

ENV_PATH = PROJECT_ROOT / ".env"
load_dotenv(ENV_PATH)

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


def _set_admin_password(new_password: str) -> tuple[bool, str | None]:
    global ADMIN_PASSWORD
    ADMIN_PASSWORD = new_password
    os.environ["ADMIN_TEST_PASSWORD"] = new_password

    try:
        if ENV_PATH.exists():
            set_key(str(ENV_PATH), "ADMIN_TEST_PASSWORD", new_password)
        else:
            with ENV_PATH.open("a", encoding="utf-8") as env_file:
                env_file.write(f"ADMIN_TEST_PASSWORD={new_password}\n")
        return True, None
    except Exception as exc:
        app.logger.warning("Could not persist ADMIN_TEST_PASSWORD to .env: %s", exc)
        return False, "Password changed for this session only; could not update .env."


@app.before_request
def _persist_logged_in_session() -> None:
    if session.get("logged_in"):
        session.permanent = True


def _coerce_date(value: Any) -> date | None:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return date.fromisoformat(text[:10])
        except ValueError:
            return None
    return None


def _coerce_float(value: Any) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def _coerce_int(value: Any) -> int | None:
    if value in (None, ""):
        return None
    try:
        return int(float(str(value).strip()))
    except (TypeError, ValueError):
        return None


def _matches_contact_search(row: dict[str, Any], query: str) -> bool:
    if not query:
        return True
    haystack = " ".join(
        [
            str(row.get("name") or ""),
            str(row.get("email") or ""),
            str(row.get("phone") or ""),
        ]
    ).lower()
    return query in haystack


def _filter_all_drivers(rows: list[dict[str, Any]], filters: dict[str, str]) -> list[dict[str, Any]]:
    query = (filters.get("query") or "").strip().lower()
    status = (filters.get("status") or "").strip().lower()
    since_before = _coerce_date(filters.get("driving_since_before"))
    rating_min = _coerce_float(filters.get("rating_min"))
    rating_max = _coerce_float(filters.get("rating_max"))
    rides_min = _coerce_int(filters.get("rides_min"))
    rides_max = _coerce_int(filters.get("rides_max"))

    filtered: list[dict[str, Any]] = []
    for row in rows:
        if not _matches_contact_search(row, query):
            continue
        row_status = str(row.get("status") or "").strip().lower()
        if status and status != "all" and row_status != status:
            continue

        driving_since = _coerce_date(row.get("date_approved"))
        if since_before and (driving_since is None or driving_since > since_before):
            continue

        rating = _coerce_float(row.get("rating"))
        if rating_min is not None and (rating is None or rating < rating_min):
            continue
        if rating_max is not None and (rating is None or rating > rating_max):
            continue

        rides = _coerce_int(row.get("rides"))
        if rides_min is not None and (rides is None or rides < rides_min):
            continue
        if rides_max is not None and (rides is None or rides > rides_max):
            continue

        filtered.append(row)
    return filtered


def _filter_verification_drivers(rows: list[dict[str, Any]], filters: dict[str, str]) -> list[dict[str, Any]]:
    status = (filters.get("status") or "").strip().lower()
    submitted_before = _coerce_date(filters.get("submitted_before"))

    filtered: list[dict[str, Any]] = []
    for row in rows:
        row_status = str(row.get("status") or "").strip().lower()
        if status and status != "all" and row_status != status:
            continue

        submitted_on = _coerce_date(row.get("date_submitted"))
        if submitted_before and (submitted_on is None or submitted_on > submitted_before):
            continue

        filtered.append(row)
    return filtered


def _filter_riders(rows: list[dict[str, Any]], filters: dict[str, str]) -> list[dict[str, Any]]:
    query = (filters.get("query") or "").strip().lower()
    since_before = _coerce_date(filters.get("riding_since_before"))
    rating_min = _coerce_float(filters.get("rating_min"))
    rating_max = _coerce_float(filters.get("rating_max"))

    filtered: list[dict[str, Any]] = []
    for row in rows:
        if not _matches_contact_search(row, query):
            continue

        riding_since = _coerce_date(row.get("riding_since"))
        if since_before and (riding_since is None or riding_since > since_before):
            continue

        rating = _coerce_float(row.get("rating"))
        if rating_min is not None and (rating is None or rating < rating_min):
            continue
        if rating_max is not None and (rating is None or rating > rating_max):
            continue

        filtered.append(row)
    return filtered


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
                "date_submitted": today - timedelta(days=120),
                "date_approved": today - timedelta(days=112),
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
                "date_submitted": today - timedelta(days=18),
                "date_approved": None,
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
                "date_submitted": today - timedelta(days=18),
                "date_approved": None,
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
        "all_riders": [
            {"name": "Sofia Ramirez", "email": "sofia.ramirez@example.com", "phone": "319-555-0104", "preferences": "quiet ride", "rating": "4.5", "rides": 8, "riding_since": today - timedelta(days=260)},
            {"name": "Liam Carter", "email": "liam.carter@example.com", "phone": "319-555-0105", "preferences": "music okay", "rating": "4.0", "rides": 5, "riding_since": today - timedelta(days=170)},
            {"name": "Noah Bennett", "email": "noah.bennett@example.com", "phone": "319-555-0106", "preferences": "pet friendly", "rating": "4.8", "rides": 12, "riding_since": today - timedelta(days=330)},
        ],
        "total_rider_count": 6,
        "total_rides": 20,
        "db_error": None,
    }

    try:
        from AdminDatabase.admin_queries import fetch_dashboard_data, fetch_riders, fetch_rider_statistics
        data = fetch_dashboard_data()
        
        # Add rider data
        try:
            riders_list = fetch_riders()
            rider_stats = fetch_rider_statistics()
            data["all_riders"] = riders_list
            data["total_rider_count"] = rider_stats.get("total_rider_count", 0)
            data["total_rides"] = rider_stats.get("total_rides", 0)
        except Exception:
            data["all_riders"] = []
            data["total_rider_count"] = 0
            data["total_rides"] = 0
        
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
        import traceback
        fallback_data["db_error"] = (
            "Showing sample data because database data could not be loaded."
        )
        app.logger.error("Dashboard DB fallback: %s", exc)
        app.logger.error("Traceback: %s", traceback.format_exc())
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

    data = _dashboard_data()
    all_driver_rows = list(data.get("all_drivers", []))
    unapproved_rows = list(data.get("unapproved_drivers", []))
    all_driver_count_raw = len(all_driver_rows)
    pending_driver_count_raw = len(unapproved_rows)
    driver_review_count_raw = len(data.get("driver_reviews", []))

    driver_status_options = sorted(
        {
            str(row.get("status") or "").strip().lower()
            for row in all_driver_rows
            if str(row.get("status") or "").strip()
        }
    )
    verification_status_options = sorted(
        {
            str(row.get("status") or "").strip().lower()
            for row in unapproved_rows
            if str(row.get("status") or "").strip()
        }
    )

    all_driver_filters = {
        "query": request.args.get("driver_query", "").strip(),
        "status": request.args.get("driver_status", "").strip().lower(),
        "driving_since_before": request.args.get("driving_since_before", "").strip(),
        "rating_min": request.args.get("driver_rating_min", "").strip(),
        "rating_max": request.args.get("driver_rating_max", "").strip(),
        "rides_min": request.args.get("driver_rides_min", "").strip(),
        "rides_max": request.args.get("driver_rides_max", "").strip(),
    }
    verification_filters = {
        "status": request.args.get("verification_status", "").strip().lower(),
        "submitted_before": request.args.get("submitted_before", "").strip(),
    }

    data["all_drivers"] = _filter_all_drivers(all_driver_rows, all_driver_filters)
    data["unapproved_drivers"] = _filter_verification_drivers(unapproved_rows, verification_filters)

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
        all_driver_filters=all_driver_filters,
        verification_filters=verification_filters,
        driver_status_options=driver_status_options,
        verification_status_options=verification_status_options,
        all_driver_count_raw=all_driver_count_raw,
        pending_driver_count_raw=pending_driver_count_raw,
        driver_review_count_raw=driver_review_count_raw,
        **data,
    )


@app.route("/drivers/verify/<int:driver_id>", methods=["POST"])
def verify_driver(driver_id: int):
    if not _is_logged_in():
        return redirect(url_for("login"))

    action = request.form.get("action", "").strip().lower()
    return_to = (request.form.get("return_to") or "").strip()
    redirect_target = url_for("drivers", tab="verification")
    if return_to.startswith("/drivers/detail/"):
        redirect_target = return_to
    if action not in {"approve", "deny"}:
        sep = "&" if "?" in redirect_target else "?"
        return redirect(f"{redirect_target}{sep}notice=invalid_action")

    notice = "update_failed"
    try:
        from AdminDatabase.admin_queries import update_driver_status

        updated = update_driver_status(driver_id, action)
        if updated:
            notice = "approved" if action == "approve" else "denied"
    except Exception as exc:
        app.logger.warning("Driver verification update failed: %s", exc)

    sep = "&" if "?" in redirect_target else "?"
    return redirect(f"{redirect_target}{sep}notice={notice}")


@app.route("/drivers/detail/<int:driver_id>")
def driver_detail(driver_id):
    if not _is_logged_in():
        return redirect(url_for("login"))

    # If DB function exists, use it; otherwise use fallback data
    try:
        from Database.admin_queries import driver_detail as fetch_driver
        driver = fetch_driver(driver_id)
    except Exception:
        # Fallback to finding driver from dashboard data
        all_drivers = _dashboard_data().get("all_drivers", [])
        driver = next(
            (d for d in all_drivers if d.get("account_id") == driver_id),
            None
        )

    if not driver:
        return "Driver not found", 404

    return render_template(
        "driver_detail.html",
        username=session.get("username"),
        current_tab="drivers",
        driver=driver,
        verification_notice=request.args.get("notice"),
    )


@app.route("/drivers/photo/<int:driver_id>")
def driver_photo(driver_id: int):
    if not _is_logged_in():
        return redirect(url_for("login"))

    try:
        from Database.admin_queries import driver_detail as fetch_driver

        driver = fetch_driver(driver_id)
    except Exception as exc:
        app.logger.warning("Could not load driver photo details: %s", exc)
        driver = None

    if not driver:
        abort(404)

    stored_path = str(driver.get("profile_photo_path") or "").strip()
    if not stored_path:
        abort(404)

    photo_root = (PROJECT_ROOT / "DriverWebpage" / "uploads" / "driver_profiles").resolve()
    full_path = (PROJECT_ROOT / "DriverWebpage" / stored_path).resolve()
    if not full_path.is_relative_to(photo_root):
        abort(403)
    if not full_path.is_file():
        abort(404)

    mimetype = str(driver.get("profile_photo_mime_type") or "").strip() or None
    return send_file(full_path, mimetype=mimetype, conditional=True, max_age=0)


@app.route("/riders")
def riders():
    if not _is_logged_in():
        return redirect(url_for("login"))

    data = _dashboard_data()
    rider_rows = list(data.get("all_riders", []))
    rider_filters = {
        "query": request.args.get("rider_query", "").strip(),
        "riding_since_before": request.args.get("riding_since_before", "").strip(),
        "rating_min": request.args.get("rider_rating_min", "").strip(),
        "rating_max": request.args.get("rider_rating_max", "").strip(),
    }
    data["all_riders"] = _filter_riders(rider_rows, rider_filters)

    return render_template(
        "riders.html",
        username=session.get("username"),
        current_tab="riders",
        rider_filters=rider_filters,
        **data,
    )


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


@app.route("/settings", methods=["GET", "POST"])
def settings():
    if not _is_logged_in():
        return redirect(url_for("login"))

    settings_error = None
    settings_success = None

    if request.method == "POST":
        current_password = request.form.get("current_password", "").strip()
        new_password = request.form.get("new_password", "").strip()
        confirm_password = request.form.get("confirm_password", "").strip()

        if not current_password or not new_password or not confirm_password:
            settings_error = "All password fields are required."
        elif current_password != ADMIN_PASSWORD:
            settings_error = "Current password is incorrect."
        elif len(new_password) < 8:
            settings_error = "New password must be at least 8 characters."
        elif new_password != confirm_password:
            settings_error = "New password and confirmation do not match."
        elif new_password == current_password:
            settings_error = "New password must be different from current password."
        else:
            _, warning = _set_admin_password(new_password)
            settings_success = "Password updated successfully."
            if warning:
                settings_success = f"{settings_success} {warning}"

    return render_template(
        "settings.html",
        username=session.get("username"),
        current_tab="settings",
        settings_error=settings_error,
        settings_success=settings_success,
        **_dashboard_data(),
    )


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return redirect(url_for("login"))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=True)
