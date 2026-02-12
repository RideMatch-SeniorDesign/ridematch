from __future__ import annotations

import os
import time
from datetime import timedelta
from flask import Flask, redirect, render_template, request, session, url_for

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
    fallback_data = {
        "new_drivers": [
            {"name": "Bob", "pending_docs": True},
            {"name": "Sally", "pending_docs": True},
            {"name": "Chris", "pending_docs": False},
        ],
        "driver_feedback": [
            {"text": "Bob got 5 stars from Sarah"},
            {"text": "Sally missed pickup once"},
        ],
        "all_drivers": [
            {"name": "Bob Johnson", "rating": "5.0", "rides": 100, "status": "View Info"},
            {"name": "Sally Smith", "rating": "3.5", "rides": 50, "status": "View Info"},
        ],
        "new_applications": [
            {"name": "Ella Patel", "action": "View", "approved": True},
            {"name": "Jim Brown", "action": "View", "approved": False},
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
        "db_error": None,
    }

    try:
        from Database.admin_queries import fetch_dashboard_data

        return fetch_dashboard_data()
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

    return render_template(
        "drivers.html",
        username=session.get("username"),
        current_tab="drivers",
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
