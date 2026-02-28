from __future__ import annotations

import os
import sys
import time
from datetime import date, datetime, timedelta
from pathlib import Path
from flask import Flask, redirect, render_template, request, session, url_for
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
                "submitted_at": today - timedelta(days=110),
                "approved_at": today - timedelta(days=103),
                "driver_since_days": 103,
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
                "submitted_at": today - timedelta(days=4),
                "approved_at": None,
                "driver_since_days": None,
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
                "submitted_at": today - timedelta(days=4),
                "approved_at": None,
                "driver_since_days": None,
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
        "all_riders": [
            {"name": "Sofia Ramirez", "email": "sofia.ramirez@example.com", "phone": "319-555-0104", "preferences": "quiet ride", "rating": "4.5", "rides": 8},
            {"name": "Liam Carter", "email": "liam.carter@example.com", "phone": "319-555-0105", "preferences": "music okay", "rating": "4.0", "rides": 5},
            {"name": "Noah Bennett", "email": "noah.bennett@example.com", "phone": "319-555-0106", "preferences": "pet friendly", "rating": "4.8", "rides": 12},
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


def _coerce_float(value) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _coerce_int(value) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _driver_directory_rows(data: dict) -> list[dict]:
    merged_by_id: dict[int, dict] = {}

    for source in ("all_drivers", "unapproved_drivers"):
        for row in data.get(source, []):
            account_id = _coerce_int(row.get("account_id"))
            if account_id is None:
                continue

            existing = merged_by_id.get(account_id)
            if existing is None:
                merged_by_id[account_id] = dict(row)
                continue

            for key, value in row.items():
                if existing.get(key) in {None, ""} and value not in {None, ""}:
                    existing[key] = value

    return sorted(
        merged_by_id.values(),
        key=lambda row: ((row.get("name") or "").lower(), _coerce_int(row.get("account_id")) or 0),
    )


def _filter_driver_directory(
    rows: list[dict],
    search: str,
    status: str,
    min_rating: float | None,
    min_rides: int | None,
) -> list[dict]:
    lowered_search = search.lower()
    status = status.lower()

    filtered: list[dict] = []
    for row in rows:
        row_status = (row.get("status") or "").strip().lower()
        row_rating = _coerce_float(row.get("rating")) or 0.0
        row_rides = _coerce_int(row.get("rides")) or 0

        if lowered_search:
            searchable_values = (
                str(row.get("name") or "").lower(),
                str(row.get("email") or "").lower(),
                str(row.get("phone") or "").lower(),
            )
            if not any(lowered_search in value for value in searchable_values):
                continue

        if status and status != "all" and row_status != status:
            continue
        if min_rating is not None and row_rating < min_rating:
            continue
        if min_rides is not None and row_rides < min_rides:
            continue

        filtered.append(row)

    return filtered


def _as_date(value) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        candidate = value.strip()
        if not candidate:
            return None
        try:
            return datetime.fromisoformat(candidate).date()
        except ValueError:
            try:
                return date.fromisoformat(candidate[:10])
            except ValueError:
                return None
    return None


def _filter_verification_rows(
    rows: list[dict],
    search: str,
    submitted_date: date | None,
) -> list[dict]:
    lowered_search = search.lower()
    filtered: list[dict] = []

    for row in rows:
        if lowered_search:
            searchable_values = (
                str(row.get("name") or "").lower(),
                str(row.get("email") or "").lower(),
                str(row.get("phone") or "").lower(),
            )
            if not any(lowered_search in value for value in searchable_values):
                continue

        row_submitted_date = _as_date(row.get("submitted_at"))
        if submitted_date is not None:
            # Keep drivers submitted on or before the selected cutoff date.
            if row_submitted_date is None or row_submitted_date > submitted_date:
                continue

        filtered.append(row)

    return filtered


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

    search = request.args.get("search", "").strip()
    status_filter = request.args.get("status", "all").strip().lower() or "all"

    min_rating = None
    min_rating_input = request.args.get("min_rating", "").strip()
    if min_rating_input:
        parsed_rating = _coerce_float(min_rating_input)
        if parsed_rating is not None:
            min_rating = max(0.0, min(5.0, parsed_rating))
            min_rating_input = f"{min_rating:g}"
        else:
            min_rating_input = ""

    min_rides = None
    min_rides_input = request.args.get("min_rides", "").strip()
    if min_rides_input:
        parsed_rides = _coerce_int(min_rides_input)
        if parsed_rides is not None:
            min_rides = max(0, parsed_rides)
            min_rides_input = str(min_rides)
        else:
            min_rides_input = ""

    data = _dashboard_data()
    driver_directory_all = _driver_directory_rows(data)
    status_options = sorted(
        {
            (row.get("status") or "").strip().lower()
            for row in driver_directory_all
            if (row.get("status") or "").strip()
        }
    )
    if status_filter != "all" and status_filter not in status_options:
        status_filter = "all"

    driver_directory = _filter_driver_directory(
        driver_directory_all,
        search=search,
        status=status_filter,
        min_rating=min_rating,
        min_rides=min_rides,
    )

    verification_search = request.args.get("verification_search", "").strip()
    verification_submitted_date_input = request.args.get("verification_submitted_date", "").strip()
    verification_submitted_date = None
    if verification_submitted_date_input:
        try:
            verification_submitted_date = date.fromisoformat(verification_submitted_date_input)
        except ValueError:
            verification_submitted_date_input = ""

    verification_rows_all = list(data.get("unapproved_drivers", []))
    verification_rows = _filter_verification_rows(
        verification_rows_all,
        search=verification_search,
        submitted_date=verification_submitted_date,
    )

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
        driver_directory=driver_directory,
        driver_directory_total=len(driver_directory_all),
        driver_directory_filtered=len(driver_directory),
        driver_search=search,
        driver_status_filter=status_filter,
        driver_status_options=status_options,
        driver_min_rating=min_rating_input,
        driver_min_rides=min_rides_input,
        verification_driver_directory=verification_rows,
        verification_driver_total=len(verification_rows_all),
        verification_driver_filtered=len(verification_rows),
        verification_search=verification_search,
        verification_submitted_date=verification_submitted_date_input,
        selected_driver=selected_driver,
        verification_notice=request.args.get("notice"),
        **data,
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
        from AdminDatabase.admin_queries import update_driver_status

        updated = update_driver_status(driver_id, action)
        if updated:
            notice = "approved" if action == "approve" else "denied"
    except Exception as exc:
        app.logger.warning("Driver verification update failed: %s", exc)

    redirect_args = {"tab": "verification", "notice": notice}
    verification_search = request.form.get("verification_search", "").strip()
    verification_submitted_date = request.form.get("verification_submitted_date", "").strip()
    if verification_search:
        redirect_args["verification_search"] = verification_search
    if verification_submitted_date:
        redirect_args["verification_submitted_date"] = verification_submitted_date

    return redirect(url_for("drivers", **redirect_args))


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
    )


@app.route("/riders")
def riders():
    if not _is_logged_in():
        return redirect(url_for("login"))

    return render_template(
        "riders.html",
        username=session.get("username"),
        current_tab="riders",
        **_dashboard_data(),
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
