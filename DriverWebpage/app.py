from __future__ import annotations

import os
import sys
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, redirect, render_template, request, session, url_for

PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_PATH = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
if str(APP_PATH) not in sys.path:
    sys.path.insert(0, str(APP_PATH))

load_dotenv(PROJECT_ROOT / ".env")

app = Flask(__name__, static_folder="static", template_folder="templates")
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")
SESSION_DAYS = int(os.environ.get("DRIVER_SESSION_DAYS", os.environ.get("PORTAL_SESSION_DAYS", "30")))
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

US_STATE_OPTIONS = [
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
]


def _v(name: str) -> str:
    return request.form.get(name, "").strip()


def _driver_logged_in() -> bool:
    return bool(session.get("driver_logged_in"))


def _driver_session_user() -> dict:
    return session.get("driver_user") or {}


@app.before_request
def _persist_driver_session() -> None:
    if session.get("driver_logged_in"):
        session.permanent = True


def _split_preferences(value: str | None) -> list[str]:
    if not value:
        return []
    return [item.strip() for item in str(value).split(",") if item.strip()]


def _join_preferences(values: list[str]) -> str:
    return ", ".join([v.strip() for v in values if v.strip()])


def _driver_nav_context(current_page: str, **extra):
    ctx = {"current_page": current_page, "user": _driver_session_user()}
    ctx.update(extra)
    return ctx


def _driver_signup_form() -> dict[str, str]:
    return {
        "first_name": "",
        "last_name": "",
        "username": "",
        "email": "",
        "phone": "",
        "preferences": [],
        "date_of_birth": "",
        "license_state": "",
        "license_number": "",
        "license_expires": "",
        "insurance_provider": "",
        "insurance_policy": "",
    }


@app.route("/")
def home():
    if _driver_logged_in():
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

        user = authenticate_portal_user("driver", username, password)
    except Exception as exc:
        app.logger.warning("Driver login failed: %s", exc)
        return render_template("home.html", login_error="Login is unavailable right now (database error).", login_username=username)

    if not user:
        return render_template("home.html", login_error="Invalid driver login.", login_username=username)

    session["driver_logged_in"] = True
    session["driver_user"] = user
    session.permanent = True
    return redirect(url_for("dashboard"))


@app.route("/dashboard")
def dashboard():
    if not session.get("driver_logged_in"):
        return redirect(url_for("home"))
    summary = {"trip_count": 0, "completed_count": 0, "active_count": 0, "avg_given_rating": None, "avg_received_rating": None}
    trips = []
    error = None
    user = _driver_session_user()
    try:
        from Database.admin_queries import fetch_portal_dashboard_summary, fetch_portal_trip_history, fetch_portal_profile

        profile = fetch_portal_profile("driver", int(user.get("account_id")))
        if profile:
            session["driver_user"] = profile
            user = profile
        summary = fetch_portal_dashboard_summary("driver", int(user.get("account_id")))
        trips = fetch_portal_trip_history("driver", int(user.get("account_id")))[:5]
    except Exception as exc:
        app.logger.warning("Driver dashboard load failed: %s", exc)
        error = "Showing basic dashboard only because database details could not be loaded."
    return render_template("dashboard.html", **_driver_nav_context("dashboard", summary=summary, trips=trips, page_error=error))


@app.route("/start", methods=["GET", "POST"])
def start_drive():
    if not _driver_logged_in():
        return redirect(url_for("home"))
    notice = None
    form_data = {"start_loc": "", "end_loc": "", "seats": "1", "availability": "available", "notes": ""}
    if request.method == "POST":
        form_data = {k: _v(k) for k in form_data}
        session["driver_last_start"] = form_data
        notice = "Drive session started (test mode). This is a starter workflow page."
    else:
        form_data.update(session.get("driver_last_start") or {})
    return render_template("driver_start.html", **_driver_nav_context("start", notice=notice, form_data=form_data))


@app.route("/settings", methods=["GET", "POST"])
def settings():
    if not _driver_logged_in():
        return redirect(url_for("home"))

    user = _driver_session_user()
    form_data = {
        "first_name": user.get("first_name", ""),
        "last_name": user.get("last_name", ""),
        "email": user.get("email", ""),
        "phone": user.get("phone", ""),
        "preferences": _split_preferences(user.get("preferences")),
        "date_of_birth": str(user.get("date_of_birth") or ""),
        "license_state": user.get("license_state", "") or "",
        "license_number": user.get("license_number", "") or "",
        "license_expires": str(user.get("license_expires") or ""),
        "insurance_provider": user.get("insurance_provider", "") or "",
        "insurance_policy": user.get("insurance_policy", "") or "",
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
                update_portal_profile("driver", int(user.get("account_id")), payload)
                refreshed = fetch_portal_profile("driver", int(user.get("account_id")))
                if refreshed:
                    session["driver_user"] = refreshed
                    user = refreshed
                success = "Driver settings updated."
            except Exception as exc:
                app.logger.warning("Driver settings update failed: %s", exc)
                error = "Could not save settings right now."

    return render_template(
        "driver_settings.html",
        **_driver_nav_context("settings", form_data=form_data, success=success, error=error, preference_options=PREFERENCE_OPTIONS, state_options=US_STATE_OPTIONS),
    )


@app.route("/reviews")
def reviews():
    if not _driver_logged_in():
        return redirect(url_for("home"))
    review_data = {"received": [], "given": []}
    error = None
    try:
        from Database.admin_queries import fetch_portal_reviews

        review_data = fetch_portal_reviews("driver", int(_driver_session_user().get("account_id")))
    except Exception as exc:
        app.logger.warning("Driver reviews load failed: %s", exc)
        error = "Could not load review history right now."
    return render_template("driver_reviews.html", **_driver_nav_context("reviews", review_data=review_data, error=error))


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return redirect(url_for("home"))


@app.route("/signup", methods=["GET", "POST"])
def signup():
    form_data = _driver_signup_form()
    error = None
    success = None

    if request.method == "POST":
        form_data = {k: _v(k) for k in form_data}
        form_data["preferences"] = request.form.getlist("preferences")
        password = _v("password")
        confirm_password = _v("confirm_password")

        required = [
            "first_name",
            "last_name",
            "username",
            "email",
            "phone",
            "license_state",
            "license_number",
            "insurance_provider",
            "insurance_policy",
        ]
        if any(not form_data[f] for f in required):
            error = "Please fill in all required fields."
        elif len(password) < 6:
            error = "Password must be at least 6 characters."
        elif password != confirm_password:
            error = "Passwords do not match."
        else:
            try:
                from Database.admin_queries import create_driver_signup

                account_id = create_driver_signup(
                    username=form_data["username"],
                    email=form_data["email"],
                    phone=form_data["phone"],
                    password=password,
                    first_name=form_data["first_name"],
                    last_name=form_data["last_name"],
                    preferences=", ".join(form_data["preferences"]),
                    date_of_birth=form_data["date_of_birth"] or None,
                    license_state=form_data["license_state"],
                    license_number=form_data["license_number"],
                    license_expires=form_data["license_expires"] or None,
                    insurance_provider=form_data["insurance_provider"],
                    insurance_policy=form_data["insurance_policy"],
                )
                success = f"Driver account created. Account ID: {account_id} (pending review)."
                form_data = _driver_signup_form()
            except Exception as exc:
                app.logger.warning("Driver signup failed: %s", exc)
                error = "Could not create driver account. Username/email may already exist or the database is unavailable."

    return render_template(
        "signup.html",
        form_data=form_data,
        error=error,
        success=success,
        preference_options=PREFERENCE_OPTIONS,
        state_options=US_STATE_OPTIONS,
    )


if __name__ == "__main__":
    port = int(os.environ.get("DRIVER_PORT", "8002"))
    app.run(host="0.0.0.0", port=port, debug=True)
