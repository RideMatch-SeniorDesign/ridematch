from __future__ import annotations

import os
import sys
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
    return redirect(url_for("dashboard"))


@app.route("/dashboard")
def dashboard():
    if not session.get("driver_logged_in"):
        return redirect(url_for("home"))
    return render_template("dashboard.html", user=session.get("driver_user") or {})


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
