from __future__ import annotations

import os
from flask import Flask, redirect, render_template, request, session, url_for

app = Flask(__name__, static_folder="static", template_folder="templates")
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")
ADMIN_USERNAME = os.environ.get("ADMIN_TEST_USERNAME", "admin")
ADMIN_PASSWORD = os.environ.get("ADMIN_TEST_PASSWORD", "ridematch123")


def _is_logged_in() -> bool:
    return bool(session.get("logged_in"))


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
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        if not username or not password:
            error = "Please enter both a username and password."
        elif username != ADMIN_USERNAME or password != ADMIN_PASSWORD:
            error = "Invalid username or password."
        else:
            session["logged_in"] = True
            session["username"] = ADMIN_USERNAME
            return redirect(url_for("home"))

    return render_template(
        "login.html",
        error=error,
        admin_username=ADMIN_USERNAME,
        admin_password=ADMIN_PASSWORD,
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
