from __future__ import annotations

import os
import sys
import uuid
from datetime import timedelta
from pathlib import Path

import boto3
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
app.config["MAX_CONTENT_LENGTH"] = int(os.environ.get("DRIVER_PROFILE_PHOTO_MAX_BYTES", str(5 * 1024 * 1024)))

PROFILE_UPLOAD_DIR = APP_PATH / "uploads" / "driver_profiles"
ALLOWED_PROFILE_PHOTO_TYPES = {"jpeg", "png", "webp"}

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


def _detect_profile_photo_type(data: bytes) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return "jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return None


def _validate_and_store_driver_profile_photo(*, required: bool = True):
    photo = request.files.get("profile_photo")
    if not photo or not getattr(photo, "filename", ""):
        if not required:
            return None, None
        return None, "Driver profile photo is required."

    data = photo.read()
    if not data:
        return None, "Uploaded profile photo is empty."
    if len(data) > int(app.config.get("MAX_CONTENT_LENGTH") or 0):
        return None, "Profile photo must be 5 MB or smaller."

    image_type = _detect_profile_photo_type(data)
    if image_type not in ALLOWED_PROFILE_PHOTO_TYPES:
        return None, "Profile photo must be a JPG, PNG, or WebP image."

    ext = "jpg" if image_type == "jpeg" else image_type
    PROFILE_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    stored_name = f"{uuid.uuid4().hex}.{ext}"
    stored_path = PROFILE_UPLOAD_DIR / stored_name
    stored_path.write_bytes(data)

    try:
        moderation = _moderate_profile_photo_with_aws(data)
    except Exception as exc:
        app.logger.warning("AWS Rekognition moderation failed: %s", exc)
        moderation = {"status": "pending", "score": None, "labels": "moderation_error"}

    return {
        "storage_path": f"uploads/driver_profiles/{stored_name}",
        "mime_type": f"image/{'jpeg' if image_type == 'jpeg' else image_type}",
        "file_size_bytes": len(data),
        "moderation_status": moderation["status"],
        "moderation_score": moderation["score"],
        "moderation_labels": moderation["labels"],
    }, None


def _moderate_profile_photo_with_aws(data: bytes) -> dict[str, object]:
    region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
    client = boto3.client("rekognition", region_name=region)
    response = client.detect_moderation_labels(
        Image={"Bytes": data},
        MinConfidence=float(os.environ.get("AWS_REKOGNITION_MIN_SCAN_CONFIDENCE", "50")),
    )

    labels = response.get("ModerationLabels", []) or []
    if not labels:
        return {"status": "approved", "score": 0.0, "labels": None}

    top_score = 0.0
    label_names: list[str] = []
    for label in labels:
        name = str(label.get("Name") or "").strip()
        if name:
            label_names.append(name)
        try:
            conf = float(label.get("Confidence") or 0.0)
        except (TypeError, ValueError):
            conf = 0.0
        if conf > top_score:
            top_score = conf

    min_flag_conf = float(os.environ.get("AWS_REKOGNITION_MIN_FLAG_CONFIDENCE", "85"))
    status = "flagged" if top_score >= min_flag_conf else "pending"
    return {
        "status": status,
        "score": round(top_score / 100.0, 4),
        "labels": ", ".join(sorted(set(label_names))) or None,
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
    warning = None
    error = None

    if request.method == "POST":
        form_data = {k: _v(k) for k in form_data}
        form_data["preferences"] = request.form.getlist("preferences")
        if any(not form_data[k] for k in ["first_name", "last_name", "email", "phone"]):
            error = "First name, last name, email, and phone are required."
        else:
            try:
                from Database.admin_queries import (
                    fetch_portal_profile,
                    update_driver_profile_photo,
                    update_portal_profile,
                )

                photo_payload, photo_error = _validate_and_store_driver_profile_photo(required=False)
                if photo_error:
                    error = photo_error
                    photo_payload = None
                    raise ValueError(photo_error)

                payload = dict(form_data)
                payload["preferences"] = _join_preferences(form_data["preferences"])
                update_portal_profile("driver", int(user.get("account_id")), payload)
                if photo_payload:
                    update_driver_profile_photo(int(user.get("account_id")), photo_payload)
                    session_user = _driver_session_user()
                    session_user["status"] = "under_review"
                    session["driver_user"] = session_user
                    warning = "Profile photo changed. Your driver account has been placed under review again."
                refreshed = fetch_portal_profile("driver", int(user.get("account_id")))
                if refreshed:
                    session["driver_user"] = refreshed
                    user = refreshed
                if not error:
                    success = "Driver settings updated."
            except Exception as exc:
                app.logger.warning("Driver settings update failed: %s", exc)
                if not error:
                    error = "Could not save settings right now."

    return render_template(
        "driver_settings.html",
        **_driver_nav_context("settings", form_data=form_data, success=success, warning=warning, error=error, preference_options=PREFERENCE_OPTIONS, state_options=US_STATE_OPTIONS),
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
        photo_payload = None

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
            photo_payload, photo_error = _validate_and_store_driver_profile_photo()
            if photo_error:
                error = photo_error
        if request.method == "POST" and not error:
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
                    profile_photo=photo_payload,
                )
                success = f"Driver account created. Account ID: {account_id} (pending review)."
                form_data = _driver_signup_form()
            except Exception as exc:
                if photo_payload and photo_payload.get("storage_path"):
                    try:
                        (APP_PATH / photo_payload["storage_path"]).unlink(missing_ok=True)
                    except Exception:
                        pass
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
