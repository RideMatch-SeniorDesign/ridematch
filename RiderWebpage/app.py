from __future__ import annotations

import os
import sys
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify, redirect, render_template, request, session, url_for

PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_PATH = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
if str(APP_PATH) not in sys.path:
    sys.path.insert(0, str(APP_PATH))

from realtime import publish_trip_event, realtime_client_script_url, realtime_public_url

load_dotenv(PROJECT_ROOT / ".env")

app = Flask(__name__, static_folder="static", template_folder="templates")
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")
SESSION_DAYS = int(os.environ.get("RIDER_SESSION_DAYS", os.environ.get("PORTAL_SESSION_DAYS", "30")))
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(days=SESSION_DAYS)
app.config["SESSION_REFRESH_EACH_REQUEST"] = True

PREFERENCE_OPTIONS = [
    "quiet ride",
    "music okay",
    "music low",
    "conversation okay",
    "no conversation",
    "pet friendly",
    "temperature cool",
    "temperature warm",
    "no highway",
]


def _v(name: str) -> str:
    return request.form.get(name, "").strip()


def _rider_logged_in() -> bool:
    return bool(session.get("rider_logged_in"))


def _rider_session_user() -> dict:
    return session.get("rider_user") or {}


@app.before_request
def _persist_rider_session() -> None:
    if session.get("rider_logged_in"):
        session.permanent = True


def _split_preferences(value: str | None) -> list[str]:
    if not value:
        return []
    return [item.strip() for item in str(value).split(",") if item.strip()]


def _join_preferences(values: list[str]) -> str:
    return ", ".join([v.strip() for v in values if v.strip()])


def _rider_nav_context(current_page: str, **extra):
    ctx = {"current_page": current_page, "user": _rider_session_user()}
    ctx.update(extra)
    return ctx


def _rider_signup_form() -> dict[str, str]:
    return {
        "first_name": "",
        "last_name": "",
        "username": "",
        "email": "",
        "phone": "",
        "preferences": [],
    }


@app.route("/")
def home():
    if _rider_logged_in():
        return redirect(url_for("dashboard"))
    return render_template("home.html", login_error=None, login_username="")


@app.route("/login", methods=["POST"])
def login():
    username = _v("username")
    password = _v("password")
    if not username or not password:
        return render_template("home.html", login_error="Please enter both username and password.", login_username=username)

    try:
        from Database.admin_queries import authenticate_portal_user

        user = authenticate_portal_user("rider", username, password)
    except Exception as exc:
        app.logger.warning("Rider login failed: %s", exc)
        return render_template("home.html", login_error="Login is unavailable right now (database error).", login_username=username)

    if not user:
        return render_template("home.html", login_error="Invalid rider login.", login_username=username)

    session["rider_logged_in"] = True
    session["rider_user"] = user
    session.permanent = True
    return redirect(url_for("dashboard"))


@app.route("/dashboard")
def dashboard():
    if not _rider_logged_in():
        return redirect(url_for("home"))
    summary = {"trip_count": 0, "completed_count": 0, "active_count": 0, "avg_given_rating": None, "avg_received_rating": None}
    trips = []
    error = None
    user = _rider_session_user()
    try:
        from Database.admin_queries import fetch_portal_dashboard_summary, fetch_portal_trip_history, fetch_portal_profile

        profile = fetch_portal_profile("rider", int(user.get("account_id")))
        if profile:
            session["rider_user"] = profile
            user = profile
        summary = fetch_portal_dashboard_summary("rider", int(user.get("account_id")))
        trips = fetch_portal_trip_history("rider", int(user.get("account_id")))[:5]
    except Exception as exc:
        app.logger.warning("Rider dashboard load failed: %s", exc)
        error = "Showing basic dashboard only because database details could not be loaded."
    return render_template("dashboard.html", **_rider_nav_context("dashboard", summary=summary, trips=trips, page_error=error))


@app.route("/start", methods=["GET", "POST"])
def start_ride():
    if not _rider_logged_in():
        return redirect(url_for("home"))
    notice = None
    error = None
    form_data = {
        "start_loc": "",
        "end_loc": "",
        "ride_type": "standard",
        "time_pref": "asap",
        "notes": "",
        "start_lat": "",
        "start_lng": "",
        "end_lat": "",
        "end_lng": "",
    }
    active_trip = None
    user = _rider_session_user()
    if request.method == "POST":
        form_data = {k: _v(k) for k in form_data}
        session["rider_last_start"] = form_data
        if not form_data["start_loc"] or not form_data["end_loc"]:
            error = "Pickup and dropoff locations are required."
        else:
            try:
                from Database.admin_queries import create_matched_trip

                active_trip = create_matched_trip(
                    rider_id=int(user.get("account_id")),
                    start_loc=form_data["start_loc"],
                    end_loc=form_data["end_loc"],
                    ride_type=form_data["ride_type"],
                    notes=form_data["notes"],
                )
                publish_trip_event("trip_created", active_trip)
                notice = f"Ride request sent to {active_trip.get('driver_name') or 'a driver'}."
            except ValueError as exc:
                error = str(exc)
            except Exception as exc:
                app.logger.warning("Rider ride request failed: %s", exc)
                error = "Could not request a ride right now."
    else:
        form_data.update(session.get("rider_last_start") or {})
    if active_trip is None:
        try:
            from Database.admin_queries import fetch_active_rider_trip

            active_trip = fetch_active_rider_trip(int(user.get("account_id")))
        except Exception as exc:
            app.logger.warning("Rider active trip lookup failed: %s", exc)
    last_start_data = session.get("rider_last_start") or {}
    return render_template(
        "rider_start.html",
        **_rider_nav_context(
            "start",
            notice=notice,
            error=error,
            form_data=form_data,
            active_trip=active_trip,
            last_start_data=last_start_data,
            realtime_server_url=realtime_public_url(),
            realtime_client_script_url=realtime_client_script_url(),
            geoapify_api_key=os.environ.get("GEOAPIFY_API_KEY", "").strip(),
        ),
    )


@app.route("/start/cancel", methods=["POST"])
def cancel_active_ride():
    if not _rider_logged_in():
        return redirect(url_for("home"))
    trip_id_raw = str(request.form.get("trip_id") or "").strip()
    if not trip_id_raw.isdigit():
        return redirect(url_for("start_ride"))
    try:
        from Database.admin_queries import cancel_trip_for_rider, fetch_trip_by_id

        trip_before_cancel = fetch_trip_by_id(int(trip_id_raw))

        canceled = cancel_trip_for_rider(
            trip_id=int(trip_id_raw),
            rider_id=int(_rider_session_user().get("account_id")),
        )
        if canceled and trip_before_cancel:
            trip_before_cancel["status"] = "canceled"
            publish_trip_event("trip_canceled", trip_before_cancel)
        if not canceled:
            app.logger.warning("Rider cancel request had no effect for trip_id=%s", trip_id_raw)
    except Exception as exc:
        app.logger.warning("Rider cancel request failed: %s", exc)
    return redirect(url_for("start_ride"))


@app.route("/api/rider/active-trip/<int:rider_id>")
def api_rider_active_trip(rider_id: int):
    try:
        from Database.admin_queries import fetch_active_rider_trip

        trip = fetch_active_rider_trip(rider_id)
    except Exception as exc:
        app.logger.warning("Rider active trip API failed: %s", exc)
        return jsonify({"success": False, "error": "Could not load active trip."}), 500

    return jsonify({"success": True, "trip": trip}), 200


@app.route("/settings", methods=["GET", "POST"])
def settings():
    if not _rider_logged_in():
        return redirect(url_for("home"))

    user = _rider_session_user()
    form_data = {
        "first_name": user.get("first_name", ""),
        "last_name": user.get("last_name", ""),
        "email": user.get("email", ""),
        "phone": user.get("phone", ""),
        "preferences": _split_preferences(user.get("preferences")),
    }
    success = None
    error = None

    if request.method == "POST":
        form_data = {k: _v(k) for k in form_data}
        form_data["preferences"] = request.form.getlist("preferences")
        if any(not form_data[k] for k in ["first_name", "last_name", "email", "phone"]):
            error = "First name, last name, email, and phone are required."
        else:
            try:
                from Database.admin_queries import update_portal_profile, fetch_portal_profile

                payload = dict(form_data)
                payload["preferences"] = _join_preferences(form_data["preferences"])
                update_portal_profile("rider", int(user.get("account_id")), payload)
                refreshed = fetch_portal_profile("rider", int(user.get("account_id")))
                if refreshed:
                    session["rider_user"] = refreshed
                success = "Rider settings updated."
            except Exception as exc:
                app.logger.warning("Rider settings update failed: %s", exc)
                error = "Could not save settings right now."

    return render_template(
        "rider_settings.html",
        **_rider_nav_context("settings", form_data=form_data, success=success, error=error, preference_options=PREFERENCE_OPTIONS),
    )


@app.route("/reviews")
def reviews():
    if not _rider_logged_in():
        return redirect(url_for("home"))
    review_data = {"received": [], "given": []}
    error = None
    try:
        from Database.admin_queries import fetch_portal_reviews

        review_data = fetch_portal_reviews("rider", int(_rider_session_user().get("account_id")))
    except Exception as exc:
        app.logger.warning("Rider reviews load failed: %s", exc)
        error = "Could not load review history right now."
    return render_template("rider_reviews.html", **_rider_nav_context("reviews", review_data=review_data, error=error))


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return redirect(url_for("home"))


@app.route("/signup", methods=["GET", "POST"])
def signup():
    form_data = _rider_signup_form()
    error = None
    success = None

    if request.method == "POST":
        form_data = {k: _v(k) for k in form_data}
        form_data["preferences"] = request.form.getlist("preferences")
        password = _v("password")
        confirm_password = _v("confirm_password")

        required = ["first_name", "last_name", "username", "email", "phone"]
        if any(not form_data[f] for f in required):
            error = "Please fill in all required fields."
        elif len(password) < 6:
            error = "Password must be at least 6 characters."
        elif password != confirm_password:
            error = "Passwords do not match."
        else:
            try:
                from Database.admin_queries import create_rider_signup

                account_id = create_rider_signup(
                    username=form_data["username"],
                    email=form_data["email"],
                    phone=form_data["phone"],
                    password=password,
                    first_name=form_data["first_name"],
                    last_name=form_data["last_name"],
                    preferences=", ".join(form_data["preferences"]),
                )
                success = f"Rider account created. Account ID: {account_id}."
                form_data = _rider_signup_form()
            except Exception as exc:
                app.logger.warning("Rider signup failed: %s", exc)
                error = "Could not create rider account. Username/email may already exist or the database is unavailable."

    return render_template(
        "signup.html",
        form_data=form_data,
        error=error,
        success=success,
        preference_options=PREFERENCE_OPTIONS,
    )


if __name__ == "__main__":
    port = int(os.environ.get("RIDER_PORT", "8003"))
    app.run(host="0.0.0.0", port=port, debug=True)
