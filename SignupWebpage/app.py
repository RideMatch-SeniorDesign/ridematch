from __future__ import annotations

import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, redirect, render_template, request, session, url_for

# Allow running from either project root or SignupWebpage directory.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
SIGNUP_PATH = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
if str(SIGNUP_PATH) not in sys.path:
    sys.path.insert(0, str(SIGNUP_PATH))

ENV_PATH = PROJECT_ROOT / ".env"
load_dotenv(ENV_PATH)

app = Flask(__name__, static_folder="static", template_folder="templates")
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")


def _clean_form_value(name: str) -> str:
    return request.form.get(name, "").strip()


def _home_context() -> dict:
    return {
        "driver_login": {"username": ""},
        "rider_login": {"username": ""},
        "driver_error": None,
        "rider_error": None,
    }


@app.route("/")
def signup_home():
    return render_template("signup_home.html", **_home_context())


@app.route("/login/<role>", methods=["POST"])
def portal_login(role: str):
    role = (role or "").strip().lower()
    if role not in {"driver", "rider"}:
        return redirect(url_for("signup_home"))

    username = _clean_form_value("username")
    password = _clean_form_value("password")
    context = _home_context()
    context[f"{role}_login"]["username"] = username

    if not username or not password:
        context[f"{role}_error"] = "Please enter both username and password."
        return render_template("signup_home.html", **context)

    try:
        from Database.admin_queries import authenticate_portal_user

        user = authenticate_portal_user(role, username, password)
    except Exception as exc:
        app.logger.warning("%s login failed: %s", role.title(), exc)
        context[f"{role}_error"] = "Login is unavailable right now (database error)."
        return render_template("signup_home.html", **context)

    if not user:
        context[f"{role}_error"] = "Invalid credentials for this account type."
        return render_template("signup_home.html", **context)

    session["portal_logged_in"] = True
    session["portal_role"] = role
    session["portal_user"] = user
    return redirect(url_for("portal_dashboard"))


@app.route("/dashboard")
def portal_dashboard():
    if not session.get("portal_logged_in"):
        return redirect(url_for("signup_home"))

    user = session.get("portal_user") or {}
    role = session.get("portal_role")
    return render_template("dashboard.html", user=user, role=role)


@app.route("/logout", methods=["POST"])
def portal_logout():
    session.pop("portal_logged_in", None)
    session.pop("portal_role", None)
    session.pop("portal_user", None)
    return redirect(url_for("signup_home"))


@app.route("/signup/rider", methods=["GET", "POST"])
def rider_signup():
    form_data = {
        "first_name": "",
        "last_name": "",
        "username": "",
        "email": "",
        "phone": "",
        "preferences": "",
    }
    error = None
    success = None

    if request.method == "POST":
        form_data = {key: _clean_form_value(key) for key in form_data}
        password = _clean_form_value("password")
        confirm_password = _clean_form_value("confirm_password")

        required_fields = ["first_name", "last_name", "username", "email", "phone"]
        if any(not form_data[field] for field in required_fields):
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
                    preferences=form_data["preferences"],
                )
                success = f"Rider sign-up submitted successfully. Account ID: {account_id}."
                form_data = {key: "" for key in form_data}
            except Exception as exc:
                app.logger.warning("Rider signup failed: %s", exc)
                error = "Could not create rider account. Username/email may already exist or the database is unavailable."

    return render_template("rider_signup.html", form_data=form_data, error=error, success=success)


@app.route("/signup/driver", methods=["GET", "POST"])
def driver_signup():
    form_fields = [
        "first_name",
        "last_name",
        "username",
        "email",
        "phone",
        "preferences",
        "date_of_birth",
        "license_state",
        "license_number",
        "license_expires",
        "insurance_provider",
        "insurance_policy",
    ]
    form_data = {field: "" for field in form_fields}
    error = None
    success = None

    if request.method == "POST":
        form_data = {field: _clean_form_value(field) for field in form_fields}
        password = _clean_form_value("password")
        confirm_password = _clean_form_value("confirm_password")

        required_fields = [
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
        if any(not form_data[field] for field in required_fields):
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
                    preferences=form_data["preferences"],
                    date_of_birth=form_data["date_of_birth"] or None,
                    license_state=form_data["license_state"],
                    license_number=form_data["license_number"],
                    license_expires=form_data["license_expires"] or None,
                    insurance_provider=form_data["insurance_provider"],
                    insurance_policy=form_data["insurance_policy"],
                )
                success = (
                    f"Driver sign-up submitted successfully. Account ID: {account_id}. "
                    "Status has been set to pending review."
                )
                form_data = {field: "" for field in form_fields}
            except Exception as exc:
                app.logger.warning("Driver signup failed: %s", exc)
                error = "Could not create driver account. Username/email may already exist or the database is unavailable."

    return render_template("driver_signup.html", form_data=form_data, error=error, success=success)


if __name__ == "__main__":
    port = int(os.environ.get("SIGNUP_PORT", "8001"))
    app.run(host="0.0.0.0", port=port, debug=True)
