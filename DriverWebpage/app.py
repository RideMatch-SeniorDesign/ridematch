from __future__ import annotations

import os
import re
import sys
import time
import uuid
import mimetypes
from decimal import Decimal
from datetime import date, datetime
from datetime import timedelta
from pathlib import Path

from math import radians, sin, cos, sqrt, atan2

import boto3
from dotenv import load_dotenv
from flask import Flask, abort, jsonify, redirect, render_template, request, send_file, session, url_for
from flask_socketio import SocketIO, emit, join_room

PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_PATH = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
if str(APP_PATH) not in sys.path:
    sys.path.insert(0, str(APP_PATH))

load_dotenv(PROJECT_ROOT / ".env")

app = Flask(__name__, static_folder="static", template_folder="templates")
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")
SESSION_DAYS = int(os.environ.get("DRIVER_SESSION_DAYS", os.environ.get("PORTAL_SESSION_DAYS", "30")))
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(days=SESSION_DAYS)
app.config["SESSION_REFRESH_EACH_REQUEST"] = True
PROFILE_PHOTO_MAX_BYTES = int(os.environ.get("DRIVER_PROFILE_PHOTO_MAX_BYTES", str(5 * 1024 * 1024)))
DRIVER_DOCUMENT_MAX_BYTES = int(os.environ.get("DRIVER_DOCUMENT_MAX_BYTES", str(5 * 1024 * 1024)))
app.config["MAX_CONTENT_LENGTH"] = int(
    os.environ.get("DRIVER_SIGNUP_MAX_BYTES", str(PROFILE_PHOTO_MAX_BYTES + (2 * DRIVER_DOCUMENT_MAX_BYTES)))
)

PROFILE_UPLOAD_DIR = APP_PATH / "uploads" / "driver_profiles"
DOCUMENT_UPLOAD_DIR = APP_PATH / "uploads" / "driver_documents"
ALLOWED_PROFILE_PHOTO_TYPES = {"jpeg", "png", "webp"}
ALLOWED_DRIVER_DOCUMENT_TYPES = {"jpeg", "png"}

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


def _emit_trip_update(event_name: str, trip: dict | None) -> None:
    if not trip:
        return

    def _json_safe(value):
        if isinstance(value, Decimal):
            return float(value)
        if isinstance(value, (datetime, date)):
            return value.isoformat()
        if isinstance(value, dict):
            return {key: _json_safe(val) for key, val in value.items()}
        if isinstance(value, list):
            return [_json_safe(item) for item in value]
        return value

    safe_trip = _json_safe(trip)
    payload = {"event": event_name, "trip": safe_trip}
    rider_id = safe_trip.get("rider_id")
    driver_id = safe_trip.get("driver_id")
    if rider_id:
        socketio.emit("trip_updated", payload, room=f"rider:{rider_id}")
    if driver_id:
        socketio.emit("trip_updated", payload, room=f"driver:{driver_id}")


def _emit_driver_location_update(trip: dict | None) -> None:
    if not trip:
        return

    def _json_safe(value):
        if isinstance(value, Decimal):
            return float(value)
        if isinstance(value, (datetime, date)):
            return value.isoformat()
        if isinstance(value, dict):
            return {key: _json_safe(val) for key, val in value.items()}
        if isinstance(value, list):
            return [_json_safe(item) for item in value]
        return value

    payload = _json_safe({
        "trip": {
            "trip_id": trip.get("trip_id"),
            "rider_id": trip.get("rider_id"),
            "driver_id": trip.get("driver_id"),
            "driver_latitude": trip.get("driver_latitude"),
            "driver_longitude": trip.get("driver_longitude"),
            "driver_location_updated_at": trip.get("driver_location_updated_at"),
        }
    })
    rider_id = trip.get("rider_id")
    driver_id = trip.get("driver_id")
    if rider_id:
        socketio.emit("driver_location_updated", payload, room=f"rider:{rider_id}")
    if driver_id:
        socketio.emit("driver_location_updated", payload, room=f"driver:{driver_id}")


def _emit_popup_notification(
    *,
    target_role: str,
    account_id: int | str | None,
    event_name: str,
    title: str,
    message: str,
    trip: dict | None = None,
    extra: dict | None = None,
) -> None:
    if not account_id:
        return

    def _json_safe(value):
        if isinstance(value, Decimal):
            return float(value)
        if isinstance(value, (datetime, date)):
            return value.isoformat()
        if isinstance(value, dict):
            return {key: _json_safe(val) for key, val in value.items()}
        if isinstance(value, list):
            return [_json_safe(item) for item in value]
        return value

    payload = {
        "title": title,
        "message": message,
        "trip": _json_safe(trip) if trip else None,
    }

    if extra:
        payload.update(_json_safe(extra))

    socketio.emit(event_name, payload, room=f"{target_role}:{account_id}")

@socketio.on("subscribe")
def socket_subscribe(data):
    payload = data if isinstance(data, dict) else {}
    role = str(payload.get("role") or "").strip().lower()
    account_id = str(payload.get("account_id") or "").strip()
    if role not in {"rider", "driver"} or not account_id.isdigit():
        emit("subscription_error", {"error": "Invalid subscription payload."})
        return
    join_room(f"{role}:{account_id}")
    emit("subscribed", {"room": f"{role}:{account_id}"})


@socketio.on("publish_trip_event")
def socket_publish_trip_event(data):
    payload = data if isinstance(data, dict) else {}
    event_name = str(payload.get("event") or "trip_updated").strip() or "trip_updated"
    trip = payload.get("trip")
    if isinstance(trip, dict):
        _emit_trip_update(event_name, trip)


def _v(name: str) -> str:
    return request.form.get(name, "").strip()


def _driver_logged_in() -> bool:
    return bool(session.get("driver_logged_in"))


def _driver_session_user() -> dict:
    return session.get("driver_user") or {}


def _driver_photo_url_if_exists(account_id: int | None) -> str | None:
    if not account_id:
        return None
    try:
        from Database.admin_queries import fetch_driver_profile_photo_path

        existing_path = fetch_driver_profile_photo_path(int(account_id))
    except Exception as exc:
        app.logger.warning("Could not check driver profile photo path for account %s: %s", account_id, exc)
        return None
    if not str(existing_path or "").strip():
        return None
    return f"{url_for('api_driver_photo', driver_id=int(account_id))}?v={int(time.time() * 1000)}"


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
    if len(data) > PROFILE_PHOTO_MAX_BYTES:
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
    moderation_response = client.detect_moderation_labels(
        Image={"Bytes": data},
        MinConfidence=float(os.environ.get("AWS_REKOGNITION_MIN_SCAN_CONFIDENCE", "50")),
    )

    labels = moderation_response.get("ModerationLabels", []) or []
    top_score = 0.0
    moderation_label_names: list[str] = []
    for label in labels:
        name = str(label.get("Name") or "").strip()
        if name:
            moderation_label_names.append(name)
        try:
            conf = float(label.get("Confidence") or 0.0)
        except (TypeError, ValueError):
            conf = 0.0
        if conf > top_score:
            top_score = conf

    detected_label_response = client.detect_labels(
        Image={"Bytes": data},
        MaxLabels=int(os.environ.get("AWS_REKOGNITION_MAX_LABELS", "20")),
        MinConfidence=float(os.environ.get("AWS_REKOGNITION_MIN_HUMAN_CONFIDENCE", "80")),
    )
    detected_labels = detected_label_response.get("Labels", []) or []
    detected_label_names = {str(label.get("Name") or "").strip().lower() for label in detected_labels}
    has_person_label = any(name in {"person", "human", "people"} for name in detected_label_names)

    face_response = client.detect_faces(
        Image={"Bytes": data},
        Attributes=["DEFAULT"],
    )
    face_count = len(face_response.get("FaceDetails", []) or [])
    require_single_face = os.environ.get("AWS_REKOGNITION_REQUIRE_SINGLE_FACE", "false").strip().lower() in {"1", "true", "yes"}
    non_human_flag = (not has_person_label) or (face_count < 1) or (require_single_face and face_count != 1)

    min_flag_conf = float(os.environ.get("AWS_REKOGNITION_MIN_FLAG_CONFIDENCE", "85"))
    if top_score >= min_flag_conf:
        return {
            "status": "flagged",
            "score": round(top_score / 100.0, 4),
            "labels": ", ".join(sorted(set(moderation_label_names))) or "content_warning",
        }

    if non_human_flag:
        non_human_labels = []
        if not has_person_label:
            non_human_labels.append("no_person_detected")
        if face_count < 1:
            non_human_labels.append("no_face_detected")
        if require_single_face and face_count != 1:
            non_human_labels.append(f"face_count_{face_count}")
        return {
            "status": "flagged",
            "score": 1.0,
            "labels": ", ".join(non_human_labels) or "non_human_or_invalid_face",
        }

    if labels:
        return {
            "status": "pending",
            "score": round(top_score / 100.0, 4),
            "labels": ", ".join(sorted(set(moderation_label_names))) or None,
        }

    return {"status": "approved", "score": 0.0, "labels": None}


def _normalize_document_text(value: str | None) -> str:
    return re.sub(r"[^A-Z0-9]+", "", str(value or "").upper())


def _document_text_lines(value: str | None) -> list[str]:
    return [line.strip() for line in str(value or "").splitlines() if line.strip()]


def _clean_document_value(value: str | None, *, max_length: int = 100) -> str | None:
    cleaned = re.sub(r"\s+", " ", str(value or "").strip())
    cleaned = cleaned.strip(" :#-.,;")
    if not cleaned:
        return None
    return cleaned[:max_length]


def _parse_document_date(value: str | None) -> str | None:
    text = str(value or "").strip()
    if not text:
        return None

    candidates = [
        r"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b",
        r"\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b",
        r"\b([A-Z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})\b",
    ]
    month_names = {
        "JAN": 1, "JANUARY": 1,
        "FEB": 2, "FEBRUARY": 2,
        "MAR": 3, "MARCH": 3,
        "APR": 4, "APRIL": 4,
        "MAY": 5,
        "JUN": 6, "JUNE": 6,
        "JUL": 7, "JULY": 7,
        "AUG": 8, "AUGUST": 8,
        "SEP": 9, "SEPT": 9, "SEPTEMBER": 9,
        "OCT": 10, "OCTOBER": 10,
        "NOV": 11, "NOVEMBER": 11,
        "DEC": 12, "DECEMBER": 12,
    }

    for pattern in candidates:
        match = re.search(pattern, text, re.IGNORECASE)
        if not match:
            continue
        try:
            parts = match.groups()
            if parts[0].isalpha():
                month = month_names.get(parts[0].upper().rstrip("."))
                if not month:
                    continue
                day = int(parts[1])
                year = int(parts[2])
            elif len(parts[0]) == 4:
                year = int(parts[0])
                month = int(parts[1])
                day = int(parts[2])
            else:
                month = int(parts[0])
                day = int(parts[1])
                year = int(parts[2])
                if year < 100:
                    year += 2000 if year < 50 else 1900
            return date(year, month, day).isoformat()
        except ValueError:
            continue
    return None


def _find_labeled_document_value(lines: list[str], labels: tuple[str, ...], value_pattern: str) -> str | None:
    label_pattern = "|".join(re.escape(label) for label in sorted(labels, key=len, reverse=True))
    same_line_pattern = re.compile(
        rf"\b(?:{label_pattern})\b\s*(?:NO\.?|NUMBER|NUM|#|:)?\s*[:#-]?\s*({value_pattern})",
        re.IGNORECASE,
    )
    value_only_pattern = re.compile(rf"^\s*({value_pattern})\s*$", re.IGNORECASE)

    for index, line in enumerate(lines):
        match = same_line_pattern.search(line)
        if match:
            return _clean_document_value(match.group(1), max_length=50)
        if re.search(rf"\b(?:{label_pattern})\b", line, re.IGNORECASE) and index + 1 < len(lines):
            next_match = value_only_pattern.search(lines[index + 1])
            if next_match:
                return _clean_document_value(next_match.group(1), max_length=50)
    return None


def _find_labeled_document_date(lines: list[str], labels: tuple[str, ...]) -> str | None:
    label_pattern = "|".join(re.escape(label) for label in sorted(labels, key=len, reverse=True))
    for index, line in enumerate(lines):
        if not re.search(rf"\b(?:{label_pattern})\b", line, re.IGNORECASE):
            continue
        parsed = _parse_document_date(line)
        if parsed:
            return parsed
        if index + 1 < len(lines):
            parsed = _parse_document_date(lines[index + 1])
            if parsed:
                return parsed
    return None


def _clean_person_name(value: str | None) -> str | None:
    cleaned = re.sub(r"[^A-Za-z ,.'-]+", " ", str(value or ""))
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" ,.'-")
    if not cleaned or len(cleaned) < 2:
        return None
    blocked_words = {
        "DRIVER", "LICENSE", "IDENTIFICATION", "CARD", "IOWA", "STATE", "USA",
        "CLASS", "ENDORSEMENTS", "RESTRICTIONS", "SEX", "EYES", "HEIGHT", "DOB",
        "EXP", "ISS", "DLN", "DONOR", "VETERAN", "ADDRESS",
    }
    words = [word for word in re.split(r"\s+", cleaned.upper()) if word]
    if any(word in blocked_words for word in words):
        return None
    return cleaned.title()[:150]


def _name_value_after_numbered_label(lines: list[str], label_number: str) -> str | None:
    same_line_pattern = re.compile(rf"^\s*{re.escape(label_number)}[A-Z]?\s+(.+)$", re.IGNORECASE)
    label_only_pattern = re.compile(rf"^\s*{re.escape(label_number)}[A-Z]?\s*$", re.IGNORECASE)
    for index, line in enumerate(lines):
        same_line = same_line_pattern.match(line)
        if same_line:
            name = _clean_person_name(same_line.group(1))
            if name:
                return name
        if label_only_pattern.match(line) and index + 1 < len(lines):
            name = _clean_person_name(lines[index + 1])
            if name:
                return name
    return None


def _extract_license_full_name(lines: list[str]) -> str | None:
    family_name = _find_labeled_document_value(
        lines,
        ("1 FAMILY NAME", "FAMILY NAME", "LAST NAME", "SURNAME", "LN", "LNAME"),
        r"[A-Z][A-Z '-]{1,50}",
    )
    given_name = _find_labeled_document_value(
        lines,
        ("2 GIVEN NAMES", "GIVEN NAMES", "FIRST NAME", "GIVEN NAME", "FN", "FNAME"),
        r"[A-Z][A-Z '-]{1,60}",
    )
    if family_name and given_name:
        return _clean_person_name(f"{given_name} {family_name}")

    numbered_family_name = _name_value_after_numbered_label(lines, "1")
    numbered_given_name = _name_value_after_numbered_label(lines, "2")
    if numbered_family_name and numbered_given_name:
        return _clean_person_name(f"{numbered_given_name} {numbered_family_name}")

    full_name = _find_labeled_document_value(
        lines,
        ("FULL NAME", "DRIVER NAME", "NAME"),
        r"[A-Z][A-Z ',.-]{3,100}",
    )
    if full_name:
        return _clean_person_name(full_name)

    for line in lines[:8]:
        match = re.match(r"^\s*([A-Z][A-Z '-]{1,50}),\s*([A-Z][A-Z '-]{1,60})\s*$", line, re.IGNORECASE)
        if match:
            return _clean_person_name(f"{match.group(2)} {match.group(1)}")

    return None


def _extract_license_details(text: str) -> dict[str, str]:
    lines = _document_text_lines(text)
    joined = "\n".join(lines)
    details: dict[str, str] = {}

    license_number = _find_labeled_document_value(
        lines,
        (
            "4D DLN", "4D", "DLN", "DLIC", "LIC NO", "LIC NUMBER",
            "LICENSE NO", "LICENSE NUMBER", "DRIVER LICENSE NUMBER",
            "CUSTOMER IDENTIFIER", "ID NO", "DL", "LIC", "ID",
        ),
        r"[A-Z0-9][A-Z0-9 -]{3,24}",
    )
    if license_number:
        details["license_number"] = re.sub(r"\s+", "", license_number.upper())[:50]

    full_name = _extract_license_full_name(lines)
    if full_name:
        details["license_full_name"] = full_name

    state = _find_labeled_document_value(lines, ("STATE", "ISS", "ISSUING STATE"), r"[A-Z]{2}")
    if state and state.upper() in US_STATE_OPTIONS:
        details["license_state"] = state.upper()
    else:
        for possible_state in US_STATE_OPTIONS:
            if re.search(rf"\b{possible_state}\b", joined, re.IGNORECASE):
                details["license_state"] = possible_state
                break
        if "license_state" not in details:
            state_names = {
                "ALABAMA": "AL", "ALASKA": "AK", "ARIZONA": "AZ", "ARKANSAS": "AR",
                "CALIFORNIA": "CA", "COLORADO": "CO", "CONNECTICUT": "CT", "DELAWARE": "DE",
                "FLORIDA": "FL", "GEORGIA": "GA", "HAWAII": "HI", "IDAHO": "ID",
                "ILLINOIS": "IL", "INDIANA": "IN", "IOWA": "IA", "KANSAS": "KS",
                "KENTUCKY": "KY", "LOUISIANA": "LA", "MAINE": "ME", "MARYLAND": "MD",
                "MASSACHUSETTS": "MA", "MICHIGAN": "MI", "MINNESOTA": "MN",
                "MISSISSIPPI": "MS", "MISSOURI": "MO", "MONTANA": "MT", "NEBRASKA": "NE",
                "NEVADA": "NV", "NEW HAMPSHIRE": "NH", "NEW JERSEY": "NJ",
                "NEW MEXICO": "NM", "NEW YORK": "NY", "NORTH CAROLINA": "NC",
                "NORTH DAKOTA": "ND", "OHIO": "OH", "OKLAHOMA": "OK", "OREGON": "OR",
                "PENNSYLVANIA": "PA", "RHODE ISLAND": "RI", "SOUTH CAROLINA": "SC",
                "SOUTH DAKOTA": "SD", "TENNESSEE": "TN", "TEXAS": "TX", "UTAH": "UT",
                "VERMONT": "VT", "VIRGINIA": "VA", "WASHINGTON": "WA",
                "WEST VIRGINIA": "WV", "WISCONSIN": "WI", "WYOMING": "WY",
            }
            for state_name, abbreviation in state_names.items():
                if re.search(rf"\b{re.escape(state_name)}\b", joined, re.IGNORECASE):
                    details["license_state"] = abbreviation
                    break

    expires = _find_labeled_document_date(
        lines,
        ("4B EXP", "4B", "EXPIRATION DATE", "EXP DATE", "EXPIRATION", "EXPIRES", "EXPIRY", "EXP"),
    )
    if expires:
        details["license_expires"] = expires

    issued = _find_labeled_document_date(lines, ("4A ISS", "4A", "ISSUED DATE", "ISSUED", "ISS"))
    if issued:
        details["license_issued"] = issued

    date_of_birth = _find_labeled_document_date(lines, ("DOB", "BIRTH", "DATE OF BIRTH"))
    if date_of_birth:
        details["date_of_birth"] = date_of_birth

    return details


def _extract_insurance_details(text: str) -> dict[str, str]:
    lines = _document_text_lines(text)
    joined = "\n".join(lines)
    details: dict[str, str] = {}

    known_providers = (
        "State Farm", "GEICO", "Progressive", "Allstate", "Farmers", "Liberty Mutual",
        "Nationwide", "USAA", "Travelers", "American Family", "Erie", "Auto-Owners",
        "The Hartford", "MetLife", "Mercury", "Safeco", "Root", "Esurance",
    )
    for provider in known_providers:
        if re.search(rf"\b{re.escape(provider)}\b", joined, re.IGNORECASE):
            details["insurance_provider"] = provider
            break

    if "insurance_provider" not in details:
        provider = _find_labeled_document_value(
            lines,
            ("INSURER", "COMPANY", "PROVIDER", "INSURANCE COMPANY", "CARRIER"),
            r"[A-Z][A-Z0-9 &.'-]{2,60}",
        )
        if provider:
            details["insurance_provider"] = provider.title()[:100]

    policy = _find_labeled_document_value(
        lines,
        ("POLICY", "POLICY NO", "POLICY NUMBER", "POLICY #", "POL"),
        r"[A-Z0-9][A-Z0-9 -]{4,30}",
    )
    if policy:
        details["insurance_policy"] = re.sub(r"\s+", "", policy.upper())[:50]

    effective = _find_labeled_document_date(lines, ("EFFECTIVE", "EFF", "FROM"))
    if effective:
        details["insurance_effective"] = effective

    expires = _find_labeled_document_date(lines, ("EXPIRES", "EXPIRATION", "EXP", "TO"))
    if expires:
        details["insurance_expires"] = expires

    vin = _find_labeled_document_value(lines, ("VIN", "VEHICLE ID", "VEHICLE IDENTIFICATION"), r"[A-HJ-NPR-Z0-9]{11,17}")
    if vin:
        details["vehicle_vin"] = vin.upper()

    plate = _find_labeled_document_value(lines, ("PLATE", "LICENSE PLATE", "TAG"), r"[A-Z0-9 -]{2,12}")
    if plate:
        details["license_plate"] = re.sub(r"\s+", "", plate.upper())[:20]

    known_makes = (
        "Acura", "Audi", "BMW", "Buick", "Cadillac", "Chevrolet", "Chevy", "Chrysler",
        "Dodge", "Ford", "Genesis", "GMC", "Honda", "Hyundai", "Infiniti", "Jaguar",
        "Jeep", "Kia", "Lexus", "Lincoln", "Mazda", "Mercedes", "Mercedes-Benz",
        "Mitsubishi", "Nissan", "Ram", "Subaru", "Tesla", "Toyota", "Volkswagen", "Volvo",
    )
    for line in lines:
        for make in known_makes:
            match = re.search(rf"\b{re.escape(make)}\b\s*([A-Z0-9][A-Z0-9 -]{{1,30}})?", line, re.IGNORECASE)
            if not match:
                continue
            normalized_make = "Chevrolet" if make.lower() == "chevy" else make
            details["vehicle_make"] = normalized_make
            model = _clean_document_value(match.group(1), max_length=50)
            if model:
                details["vehicle_model"] = model.title()
            break
        if details.get("vehicle_make"):
            break

    color = _find_labeled_document_value(lines, ("COLOR", "VEHICLE COLOR"), r"[A-Z]{3,20}")
    if color:
        details["vehicle_color"] = color.title()

    return details


def _format_extracted_document_labels(base_label: str, details: dict[str, str]) -> str:
    label_map = {
        "license_state": "License State",
        "license_full_name": "Name on License",
        "license_number": "License Number",
        "license_issued": "License Issued",
        "license_expires": "License Expires",
        "date_of_birth": "DOB",
        "insurance_provider": "Insurance Provider",
        "insurance_policy": "Policy",
        "insurance_effective": "Effective",
        "insurance_expires": "Insurance Expires",
        "vehicle_vin": "VIN",
        "license_plate": "Plate",
        "vehicle_make": "Vehicle Make",
        "vehicle_model": "Vehicle Model",
        "vehicle_color": "Vehicle Color",
    }
    parts = [base_label]
    for key, label in label_map.items():
        value = details.get(key)
        if value:
            parts.append(f"{label}: {value}")
    return "\n".join(parts)[:500]


def _detect_driver_document_type(data: bytes) -> str | None:
    image_type = _detect_profile_photo_type(data)
    if image_type in ALLOWED_DRIVER_DOCUMENT_TYPES:
        return image_type
    return None


def _read_driver_document_upload(field_name: str, label: str) -> tuple[bytes | None, str | None]:
    upload = request.files.get(field_name)
    if not upload or not getattr(upload, "filename", ""):
        return None, f"{label} upload is required."

    data = upload.read()
    if not data:
        return None, f"{label} upload is empty."
    if len(data) > DRIVER_DOCUMENT_MAX_BYTES:
        return None, f"{label} must be 5 MB or smaller."
    if _detect_driver_document_type(data) not in ALLOWED_DRIVER_DOCUMENT_TYPES:
        return None, f"{label} must be a JPG or PNG image."
    return data, None


def _has_driver_document_upload(field_name: str) -> bool:
    upload = request.files.get(field_name)
    return bool(upload and getattr(upload, "filename", ""))


def _detect_text_with_aws_rekognition(data: bytes) -> str:
    region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
    client = boto3.client("rekognition", region_name=region)
    response = client.detect_text(Image={"Bytes": data})
    lines: list[str] = []
    for item in response.get("TextDetections", []) or []:
        if item.get("Type") != "LINE":
            continue
        text = str(item.get("DetectedText") or "").strip()
        if text:
            lines.append(text)
    return "\n".join(lines)


def _validate_license_document_text(text: str) -> str | None:
    normalized_text = _normalize_document_text(text)
    has_license_words = any(
        phrase in normalized_text
        for phrase in ("DRIVERLICENSE", "DRIVERSLICENSE", "DRIVINGLICENSE", "DL", "LICENSE")
    )
    if not has_license_words:
        return "Upload a clear image of a valid U.S. driver's license."
    return None


def _validate_insurance_document_text(text: str) -> str | None:
    normalized_text = _normalize_document_text(text)
    has_insurance_words = any(
        phrase in normalized_text
        for phrase in ("INSURANCE", "AUTOINSURANCE", "VEHICLEINSURANCE", "PROOFOFINSURANCE", "POLICY")
    )
    if not has_insurance_words:
        return "Upload a clear proof of vehicle insurance document."
    return None


def _store_driver_document_payload(
    document_type: str,
    data: bytes,
    labels: str,
    extracted_details: dict[str, str] | None = None,
) -> dict[str, object]:
    DOCUMENT_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    image_type = _detect_driver_document_type(data) or "jpeg"
    ext = "jpg" if image_type == "jpeg" else image_type
    stored_name = f"{uuid.uuid4().hex}.{ext}"
    stored_path = DOCUMENT_UPLOAD_DIR / stored_name
    stored_path.write_bytes(data)
    return {
        "document_type": document_type,
        "storage_path": f"uploads/driver_documents/{stored_name}",
        "mime_type": f"image/{'jpeg' if image_type == 'jpeg' else image_type}",
        "file_size_bytes": len(data),
        "recognition_status": "approved",
        "recognition_labels": labels,
        "extracted_details": extracted_details or {},
    }


def _validate_and_store_license_document() -> tuple[dict[str, object] | None, str | None]:
    license_data, license_error = _read_driver_document_upload("license_document", "Driver's license")
    if license_error:
        return None, license_error

    try:
        license_text = _detect_text_with_aws_rekognition(license_data or b"")
    except Exception as exc:
        app.logger.warning("Driver document recognition failed: %s", exc)
        return None, "Document recognition is unavailable right now. Please try again later."

    license_error = _validate_license_document_text(license_text)
    if license_error:
        return None, license_error

    details = _extract_license_details(license_text)
    labels = _format_extracted_document_labels("license_text_matched", details)
    return _store_driver_document_payload("license", license_data or b"", labels, details), None


def _validate_and_store_insurance_document() -> tuple[dict[str, object] | None, str | None]:
    insurance_data, insurance_error = _read_driver_document_upload("insurance_document", "Proof of vehicle insurance")
    if insurance_error:
        return None, insurance_error

    try:
        insurance_text = _detect_text_with_aws_rekognition(insurance_data or b"")
    except Exception as exc:
        app.logger.warning("Driver document recognition failed: %s", exc)
        return None, "Document recognition is unavailable right now. Please try again later."

    insurance_error = _validate_insurance_document_text(insurance_text)
    if insurance_error:
        return None, insurance_error

    details = _extract_insurance_details(insurance_text)
    labels = _format_extracted_document_labels("insurance_text_matched", details)
    return _store_driver_document_payload("insurance", insurance_data or b"", labels, details), None


def _validate_and_store_driver_documents() -> tuple[list[dict[str, object]] | None, str | None]:
    license_payload, license_error = _validate_and_store_license_document()
    if license_error or not license_payload:
        return None, license_error or "Driver's license upload is required."

    insurance_payload, insurance_error = _validate_and_store_insurance_document()
    if insurance_error or not insurance_payload:
        _delete_stored_driver_documents([license_payload])
        return None, insurance_error or "Proof of vehicle insurance upload is required."

    return [license_payload, insurance_payload], None


def _merge_driver_document_details(documents: list[dict[str, object]] | None) -> dict[str, str]:
    merged: dict[str, str] = {}
    for document in documents or []:
        details = document.get("extracted_details")
        if not isinstance(details, dict):
            continue
        for key, value in details.items():
            cleaned = _clean_document_value(str(value), max_length=100)
            if cleaned:
                merged[str(key)] = cleaned
    return merged


def _delete_stored_driver_documents(documents: list[dict[str, object]] | None) -> None:
    for document in documents or []:
        storage_path = str(document.get("storage_path") or "").strip()
        if not storage_path:
            continue
        try:
            (APP_PATH / storage_path).unlink(missing_ok=True)
        except Exception:
            pass


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


@app.route("/api/driver/login", methods=["POST"])
def api_driver_login():
    payload = request.get_json(silent=True) or {}
    username = str(payload.get("username") or "").strip()
    password = str(payload.get("password") or "").strip()
    if not username or not password:
        return jsonify({"success": False, "error": "Username and password are required."}), 400

    try:
        from Database.admin_queries import authenticate_portal_user

        user = authenticate_portal_user("driver", username, password)
    except Exception as exc:
        app.logger.warning("Driver API login failed: %s", exc)
        return jsonify({"success": False, "error": "Login is unavailable right now (database error)."}), 500

    if not user:
        return jsonify({"success": False, "error": "Invalid driver login."}), 401
    photo_url = _driver_photo_url_if_exists(int(user.get("account_id") or 0))
    if photo_url:
        user["photo_url"] = photo_url

    return jsonify({"success": True, "user": user}), 200


@app.route("/api/driver/signup", methods=["POST"])
def api_driver_signup():
    """Multipart signup for mobile (same profile photo rules as the web form: JPG/PNG/WebP, max 5 MB)."""
    content_type = str(request.content_type or "").lower()
    if "multipart/form-data" not in content_type:
        return jsonify(
            {
                "success": False,
                "error": "Send multipart/form-data with a profile_photo file (JPG, PNG, or WebP, max 5 MB).",
            }
        ), 400

    first_name = str(request.form.get("first_name") or "").strip()
    last_name = str(request.form.get("last_name") or "").strip()
    username = str(request.form.get("username") or "").strip()
    email = str(request.form.get("email") or "").strip()
    phone = str(request.form.get("phone") or "").strip()
    date_of_birth = str(request.form.get("date_of_birth") or "").strip()
    password = str(request.form.get("password") or "")
    confirm_password = str(request.form.get("confirm_password") or "")
    preferences = request.form.getlist("preferences")

    required = [
        first_name,
        last_name,
        username,
        email,
        phone,
    ]
    if not all(required):
        return jsonify({"success": False, "error": "Please fill in all required fields."}), 400
    if len(password) < 6:
        return jsonify({"success": False, "error": "Password must be at least 6 characters."}), 400
    if password != confirm_password:
        return jsonify({"success": False, "error": "Passwords do not match."}), 400

    normalized_preferences = [str(item).strip() for item in preferences if str(item).strip()]

    document_payloads, document_error = _validate_and_store_driver_documents()
    if document_error:
        return jsonify({"success": False, "error": document_error}), 400
    document_details = _merge_driver_document_details(document_payloads)

    photo_payload, photo_error = _validate_and_store_driver_profile_photo(required=True)
    if photo_error or not photo_payload:
        _delete_stored_driver_documents(document_payloads)
        return jsonify({"success": False, "error": photo_error or "Driver profile photo is required."}), 400

    try:
        from Database.admin_queries import create_driver_signup

        account_id = create_driver_signup(
            username=username,
            email=email,
            phone=phone,
            password=password,
            first_name=first_name,
            last_name=last_name,
            preferences=", ".join(normalized_preferences),
            date_of_birth=document_details.get("date_of_birth") or date_of_birth or None,
            license_state=document_details.get("license_state"),
            license_number=document_details.get("license_number"),
            license_expires=document_details.get("license_expires"),
            insurance_provider=document_details.get("insurance_provider"),
            insurance_policy=document_details.get("insurance_policy"),
            profile_photo=photo_payload,
            documents=document_payloads,
        )
    except Exception as exc:
        app.logger.warning("Driver API signup failed: %s", exc)
        try:
            if photo_payload and photo_payload.get("storage_path"):
                (APP_PATH / str(photo_payload["storage_path"])).unlink(missing_ok=True)
        except Exception:
            pass
        _delete_stored_driver_documents(document_payloads)
        return jsonify(
            {
                "success": False,
                "error": "Could not create driver account. Username/email may already exist or the database is unavailable.",
            }
        ), 500

    return jsonify(
        {
            "success": True,
            "message": "Driver account created. An administrator must approve your account before you can sign in.",
            "account_id": account_id,
            "pending_review": True,
        }
    ), 201


@app.route("/api/driver/photo/<int:driver_id>")
def api_driver_photo(driver_id: int):
    try:
        from Database.admin_queries import fetch_driver_profile_photo_path

        stored_path = fetch_driver_profile_photo_path(driver_id)
    except Exception as exc:
        app.logger.warning("Driver photo lookup failed: %s", exc)
        stored_path = None

    stored_path = str(stored_path or "").strip()
    if not stored_path:
        abort(404)

    full_path = (APP_PATH / stored_path).resolve()
    photo_root = PROFILE_UPLOAD_DIR.resolve()
    if not full_path.is_relative_to(photo_root) or not full_path.is_file():
        abort(404)

    guessed_mime, _ = mimetypes.guess_type(str(full_path))
    response = send_file(full_path, mimetype=guessed_mime or "application/octet-stream", conditional=False, max_age=0)
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response


@app.route("/api/driver/document/<int:driver_id>/<document_type>")
def api_driver_document(driver_id: int, document_type: str):
    normalized_type = str(document_type or "").strip().lower()
    if normalized_type not in {"license", "insurance"}:
        abort(404)

    try:
        from Database.admin_queries import fetch_driver_document_paths

        document_paths = fetch_driver_document_paths(driver_id)
    except Exception as exc:
        app.logger.warning("Driver document lookup failed: %s", exc)
        document_paths = {}

    stored_path = str(document_paths.get(normalized_type) or "").strip()
    if not stored_path:
        abort(404)

    full_path = (APP_PATH / stored_path).resolve()
    document_root = DOCUMENT_UPLOAD_DIR.resolve()
    if not full_path.is_relative_to(document_root) or not full_path.is_file():
        abort(404)

    guessed_mime, _ = mimetypes.guess_type(str(full_path))
    response = send_file(full_path, mimetype=guessed_mime or "application/octet-stream", conditional=False, max_age=0)
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response


@app.route("/api/driver/profile/photo", methods=["POST"])
def api_driver_profile_photo_update():
    account_id_raw = str(request.form.get("account_id") or "").strip()
    if not account_id_raw.isdigit():
        return jsonify({"success": False, "error": "A valid account_id is required."}), 400
    account_id = int(account_id_raw)

    photo_payload, photo_error = _validate_and_store_driver_profile_photo(required=True)
    if photo_error or not photo_payload:
        return jsonify({"success": False, "error": photo_error or "Profile photo upload failed."}), 400

    try:
        from Database.admin_queries import (
            fetch_driver_profile_photo_path,
            fetch_portal_profile,
            update_driver_profile_photo,
        )

        previous_photo_path = fetch_driver_profile_photo_path(account_id)
        updated = update_driver_profile_photo(account_id, photo_payload)
        if not updated:
            try:
                (APP_PATH / str(photo_payload.get("storage_path") or "")).unlink(missing_ok=True)
            except Exception:
                pass
            return jsonify({"success": False, "error": "Could not update profile photo in database."}), 500

        new_photo_path = str(photo_payload.get("storage_path") or "").strip()
        old_photo_path = str(previous_photo_path or "").strip()
        if old_photo_path and old_photo_path != new_photo_path:
            try:
                (APP_PATH / old_photo_path).unlink(missing_ok=True)
            except Exception as delete_exc:
                app.logger.warning("Could not delete replaced profile photo '%s': %s", old_photo_path, delete_exc)

        user = fetch_portal_profile("driver", account_id) or {"account_id": account_id}
        user["photo_url"] = f"{url_for('api_driver_photo', driver_id=account_id)}?v={int(time.time() * 1000)}"
        user["status"] = "under_review"
        return jsonify(
            {
                "success": True,
                "message": "Profile photo updated. Your account is now under review.",
                "user": user,
                "photo_url": user["photo_url"],
            }
        ), 200
    except Exception as exc:
        app.logger.warning("Driver photo API update failed: %s", exc)
        try:
            (APP_PATH / str(photo_payload.get("storage_path") or "")).unlink(missing_ok=True)
        except Exception:
            pass
        return jsonify({"success": False, "error": "Could not update profile photo right now."}), 500


@app.route("/api/driver/profile/documents", methods=["POST"])
def api_driver_documents_update():
    account_id_raw = str(request.form.get("account_id") or "").strip()
    if not account_id_raw.isdigit():
        return jsonify({"success": False, "error": "A valid account_id is required."}), 400
    account_id = int(account_id_raw)

    document_payloads: list[dict[str, object]] = []
    if _has_driver_document_upload("license_document"):
        license_payload, license_error = _validate_and_store_license_document()
        if license_error or not license_payload:
            return jsonify({"success": False, "error": license_error or "Could not read driver's license upload."}), 400
        document_payloads.append(license_payload)

    if _has_driver_document_upload("insurance_document"):
        insurance_payload, insurance_error = _validate_and_store_insurance_document()
        if insurance_error or not insurance_payload:
            _delete_stored_driver_documents(document_payloads)
            return jsonify({"success": False, "error": insurance_error or "Could not read proof of vehicle insurance upload."}), 400
        document_payloads.append(insurance_payload)

    if not document_payloads:
        return jsonify({"success": False, "error": "Upload a driver's license or proof of insurance image."}), 400

    try:
        from Database.admin_queries import (
            fetch_driver_document_paths,
            fetch_portal_profile,
            update_driver_documents,
        )

        existing_document_paths = fetch_driver_document_paths(account_id)
        updated = update_driver_documents(account_id, document_payloads)
        if not updated:
            _delete_stored_driver_documents(document_payloads)
            return jsonify({"success": False, "error": "Could not update verification documents in database."}), 500

        for document in document_payloads:
            document_type = str(document.get("document_type") or "").strip().lower()
            new_document_path = str(document.get("storage_path") or "").strip()
            old_document_path = str(existing_document_paths.get(document_type) or "").strip()
            if old_document_path and old_document_path != new_document_path:
                try:
                    (APP_PATH / old_document_path).unlink(missing_ok=True)
                except Exception as delete_exc:
                    app.logger.warning("Could not delete replaced driver document '%s': %s", old_document_path, delete_exc)

        user = fetch_portal_profile("driver", account_id) or {"account_id": account_id}
        user["status"] = "under_review"
        return jsonify(
            {
                "success": True,
                "message": "Verification documents updated. Your driver account is now under review.",
                "user": user,
            }
        ), 200
    except Exception as exc:
        _delete_stored_driver_documents(document_payloads)
        app.logger.warning("Driver document API update failed: %s", exc)
        return jsonify({"success": False, "error": "Could not update verification documents right now."}), 500


@app.route("/api/driver/profile/<int:driver_id>", methods=["GET"])
def api_driver_profile(driver_id: int):
    try:
        from Database.admin_queries import fetch_portal_profile

        user = fetch_portal_profile("driver", driver_id)
    except Exception as exc:
        app.logger.warning("Driver profile API load failed: %s", exc)
        user = None

    if not user:
        return jsonify({"success": False, "error": "Driver profile not found."}), 404

    photo_url = _driver_photo_url_if_exists(driver_id)
    if photo_url:
        user["photo_url"] = photo_url
    else:
        user.pop("photo_url", None)
    return jsonify({"success": True, "user": user}), 200


@app.route("/api/driver/profile/<int:driver_id>", methods=["POST"])
def api_driver_profile_update(driver_id: int):
    payload = request.get_json(silent=True) or {}
    first_name = str(payload.get("first_name") or "").strip()
    last_name = str(payload.get("last_name") or "").strip()
    email = str(payload.get("email") or "").strip()
    phone = str(payload.get("phone") or "").strip()
    preferences = payload.get("preferences") or []

    if not all([first_name, last_name, email, phone]):
        return jsonify({"success": False, "error": "First name, last name, email, and phone are required."}), 400

    if isinstance(preferences, list):
        normalized_preferences = [str(item).strip() for item in preferences if str(item).strip()]
    else:
        normalized_preferences = _split_preferences(str(preferences))

    try:
        from Database.admin_queries import fetch_portal_profile, update_portal_profile

        update_portal_profile(
            "driver",
            driver_id,
            {
                "first_name": first_name,
                "last_name": last_name,
                "email": email,
                "phone": phone,
                "preferences": _join_preferences(normalized_preferences),
            },
        )
        user = fetch_portal_profile("driver", driver_id)
    except Exception as exc:
        app.logger.warning("Driver profile API update failed: %s", exc)
        return jsonify({"success": False, "error": "Could not save settings right now."}), 500

    if not user:
        return jsonify({"success": False, "error": "Driver profile not found after update."}), 404
    photo_url = _driver_photo_url_if_exists(driver_id)
    if photo_url:
        user["photo_url"] = photo_url
    else:
        user.pop("photo_url", None)
    return jsonify({"success": True, "message": "Driver settings updated.", "user": user}), 200


@app.route("/api/driver/change-password", methods=["POST"])
def api_driver_change_password():
    payload = request.get_json(silent=True) or {}
    driver_id = int(payload.get("driver_id") or 0)
    current_password = str(payload.get("current_password") or "")
    new_password = str(payload.get("new_password") or "")
    if not driver_id:
        return jsonify({"success": False, "error": "driver_id is required."}), 400
    if not current_password or not new_password:
        return jsonify({"success": False, "error": "Current and new passwords are required."}), 400
    try:
        from Database.admin_queries import update_driver_password

        ok, message = update_driver_password(driver_id, current_password, new_password)
    except Exception as exc:
        app.logger.warning("Driver change password failed: %s", exc)
        return jsonify({"success": False, "error": "Could not update password right now."}), 500
    if not ok:
        return jsonify({"success": False, "error": message}), 400
    return jsonify({"success": True, "message": message}), 200


@app.route("/api/driver/dispatch/<int:driver_id>", methods=["GET"])
def api_driver_dispatch(driver_id: int):
    try:
        from Database.admin_queries import fetch_active_driver_trip, fetch_driver_availability

        trip = fetch_active_driver_trip(driver_id)
        is_available = fetch_driver_availability(driver_id)
    except Exception as exc:
        app.logger.warning("Driver dispatch API load failed: %s", exc)
        return jsonify({"success": False, "error": "Could not load driver dispatch."}), 500

    return jsonify({"success": True, "trip": trip, "is_available": is_available}), 200


@app.route("/api/driver/availability", methods=["POST"])
def api_driver_availability():
    payload = request.get_json(silent=True) or {}
    driver_id = int(payload.get("driver_id") or 0)
    if not driver_id:
        return jsonify({"success": False, "error": "driver_id is required."}), 400
    is_available = bool(payload.get("is_available"))

    try:
        from Database.admin_queries import fetch_driver_availability, fetch_portal_profile, set_driver_availability

        driver_profile = fetch_portal_profile("driver", driver_id)
        if not driver_profile:
            return jsonify({"success": False, "error": "Driver was not found."}), 404
        if (driver_profile.get("status") or "").strip().lower() != "approved":
            return jsonify({"success": False, "error": "Only approved drivers can go online."}), 409

        set_driver_availability(driver_id, is_available)
        current = fetch_driver_availability(driver_id)
    except Exception as exc:
        app.logger.warning("Driver availability update failed: %s", exc)
        return jsonify({"success": False, "error": "Could not update driver availability."}), 500

    return jsonify({"success": True, "is_available": current}), 200


@app.route("/api/driver/location", methods=["POST"])
def api_driver_location():
    payload = request.get_json(silent=True) or {}
    driver_id = int(payload.get("driver_id") or 0)
    if not driver_id:
        return jsonify({"success": False, "error": "driver_id is required."}), 400

    try:
        latitude = float(payload.get("latitude"))
        longitude = float(payload.get("longitude"))
    except (TypeError, ValueError):
        return jsonify({"success": False, "error": "latitude and longitude are required."}), 400

    try:
        from Database.admin_queries import fetch_active_driver_trip, update_driver_live_location

        update_driver_live_location(driver_id, latitude, longitude)
        trip = fetch_active_driver_trip(driver_id)
        if trip:
            _emit_driver_location_update(trip)
            pickup_lat = trip.get("start_latitude")
            pickup_lng = trip.get("start_longitude")

            if (
                pickup_lat is not None
                and pickup_lng is not None
                and not trip.get("arrival_notified")
            ):
                meters = distance_meters(
                    latitude,
                    longitude,
                    float(pickup_lat),
                    float(pickup_lng),
                )
                if meters <= 50:
                    _emit_popup_notification(
                        target_role="rider",
                        account_id=trip.get("rider_id"),
                        event_name="driver_arrived",
                        title="Driver arrived",
                        message="Your driver is at the pickup location.",
                        trip=trip,
                    )
                    # call DB helper here to mark arrival_notified = 1
    except Exception as exc:
        app.logger.warning("Driver location update failed: %s", exc)
        return jsonify({"success": False, "error": "Could not update driver location."}), 500

    return jsonify({"success": True}), 200

def distance_meters(lat1, lon1, lat2, lon2):
    r = 6371000
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return r * c


@app.route("/api/config/maps", methods=["GET"])
def api_maps_config():
    return jsonify(
        {
            "success": True,
            "geoapify_api_key": os.environ.get("GEOAPIFY_API_KEY", "").strip(),
        }
    ), 200


@app.route("/api/driver/dashboard/<int:driver_id>", methods=["GET"])
def api_driver_dashboard(driver_id: int):
    summary = {
        "trip_count": 0,
        "completed_count": 0,
        "active_count": 0,
        "avg_given_rating": None,
        "avg_received_rating": None,
    }
    trips = []
    user = None
    try:
        from Database.admin_queries import fetch_portal_dashboard_summary, fetch_portal_profile, fetch_portal_trip_history

        user = fetch_portal_profile("driver", driver_id)
        summary = fetch_portal_dashboard_summary("driver", driver_id)
        trips = fetch_portal_trip_history("driver", driver_id)[:10]
    except Exception as exc:
        app.logger.warning("Driver dashboard API load failed: %s", exc)
        return jsonify({"success": False, "error": "Could not load dashboard right now."}), 500

    if not user:
        return jsonify({"success": False, "error": "Driver profile not found."}), 404
    return jsonify({"success": True, "user": user, "summary": summary, "trips": trips}), 200


@app.route("/api/driver/reviews/<int:driver_id>", methods=["GET"])
def api_driver_reviews(driver_id: int):
    try:
        from Database.admin_queries import fetch_portal_reviews

        review_data = fetch_portal_reviews("driver", driver_id)
    except Exception as exc:
        app.logger.warning("Driver reviews API load failed: %s", exc)
        return jsonify({"success": False, "error": "Could not load review history right now."}), 500
    return jsonify({"success": True, "review_data": review_data}), 200


@app.route("/api/driver/pending-reviews/<int:driver_id>", methods=["GET"])
def api_driver_pending_reviews(driver_id: int):
    try:
        from Database.admin_queries import fetch_trips_pending_driver_rating

        pending = fetch_trips_pending_driver_rating(driver_id)
    except Exception as exc:
        app.logger.warning("Driver pending reviews API failed: %s", exc)
        return jsonify({"success": False, "error": "Could not load pending reviews."}), 500
    return jsonify({"success": True, "pending": pending}), 200


@app.route("/api/driver/trips/<int:driver_id>", methods=["GET"])
def api_driver_trips(driver_id: int):
    try:
        from Database.admin_queries import fetch_portal_trip_history

        trips = fetch_portal_trip_history("driver", driver_id)
    except Exception as exc:
        app.logger.warning("Driver trip history API failed: %s", exc)
        return jsonify({"success": False, "error": "Could not load trip history right now."}), 500
    return jsonify({"success": True, "trips": trips}), 200


@app.route("/api/driver/trip/<int:trip_id>/review", methods=["POST"])
def api_driver_trip_review(trip_id: int):
    payload = request.get_json(silent=True) or {}
    driver_id = int(payload.get("driver_id") or 0)
    rating_raw = payload.get("rating")
    comment = str(payload.get("comment") or "").strip()
    if not driver_id:
        return jsonify({"success": False, "error": "driver_id is required."}), 400
    try:
        rating = int(rating_raw)
    except (TypeError, ValueError):
        return jsonify({"success": False, "error": "rating must be a number between 1 and 5."}), 400
    try:
        from Database.admin_queries import submit_driver_rating_for_rider

        ok, message = submit_driver_rating_for_rider(
            driver_id,
            trip_id,
            rating,
            comment or None,
        )
    except Exception as exc:
        app.logger.warning("Driver trip review submit failed: %s", exc)
        return jsonify({"success": False, "error": "Could not submit review right now."}), 500
    if not ok:
        return jsonify({"success": False, "error": message}), 400
    return jsonify({"success": True, "message": message}), 200


@app.route("/api/driver/income/<int:driver_id>", methods=["GET"])
def api_driver_income(driver_id: int):
    try:
        from Database.admin_queries import fetch_driver_income_stats

        stats = fetch_driver_income_stats(driver_id)
    except Exception as exc:
        app.logger.warning("Driver income API failed: %s", exc)
        return jsonify({"success": False, "error": "Could not load income right now."}), 500
    return jsonify({"success": True, "stats": stats}), 200


@app.route("/api/driver/trip/<int:trip_id>/accept", methods=["POST"])
def api_driver_accept_trip(trip_id: int):
    payload = request.get_json(silent=True) or {}
    driver_id = int(payload.get("driver_id") or 0)
    if not driver_id:
        return jsonify({"success": False, "error": "driver_id is required."}), 400

    try:
        from Database.admin_queries import update_trip_status_for_driver

        trip = update_trip_status_for_driver(trip_id=trip_id, driver_id=driver_id, next_status="accepted")
    except Exception as exc:
        app.logger.warning("Driver accept trip failed: %s", exc)
        return jsonify({"success": False, "error": "Could not accept trip right now."}), 500

    if not trip:
        return jsonify({"success": False, "error": "Trip is no longer available to accept."}), 409
    _emit_trip_update("trip_accepted", trip)
    #driver accepting a trip is the key event that riders need to be notified about, so we send a specific notification for this with a clear message (instead of relying on the more generic trip update handling on the client)
    _emit_popup_notification(
        target_role="rider",
        account_id=trip.get("rider_id"),
        event_name="ride_request_accepted",
        title="Ride accepted",
        message="Your driver accepted the request and is heading to pickup.",
        trip=trip,
    )
    return jsonify({"success": True, "trip": trip}), 200


@app.route("/api/driver/trip/<int:trip_id>/start", methods=["POST"])
def api_driver_start_trip(trip_id: int):
    payload = request.get_json(silent=True) or {}
    driver_id = int(payload.get("driver_id") or 0)
    if not driver_id:
        return jsonify({"success": False, "error": "driver_id is required."}), 400

    try:
        from Database.admin_queries import update_trip_status_for_driver

        trip = update_trip_status_for_driver(trip_id=trip_id, driver_id=driver_id, next_status="in_progress")
    except Exception as exc:
        app.logger.warning("Driver start trip failed: %s", exc)
        return jsonify({"success": False, "error": "Could not start trip right now."}), 500

    if not trip:
        return jsonify({"success": False, "error": "Trip cannot be started from its current state."}), 409
    _emit_trip_update("trip_started", trip)
    return jsonify({"success": True, "trip": trip}), 200


@app.route("/api/driver/trip/<int:trip_id>/complete", methods=["POST"])
def api_driver_complete_trip(trip_id: int):
    payload = request.get_json(silent=True) or {}
    driver_id = int(payload.get("driver_id") or 0)
    if not driver_id:
        return jsonify({"success": False, "error": "driver_id is required."}), 400

    final_cost_raw = payload.get("final_cost")
    if final_cost_raw is None or str(final_cost_raw).strip() == "":
        final_cost = None
    else:
        try:
            final_cost = float(final_cost_raw)
        except (TypeError, ValueError):
            return jsonify({"success": False, "error": "final_cost must be numeric."}), 400

    try:
        from Database.admin_queries import update_trip_status_for_driver

        trip = update_trip_status_for_driver(
            trip_id=trip_id,
            driver_id=driver_id,
            next_status="completed",
            final_cost=final_cost,
        )
    except Exception as exc:
        app.logger.warning("Driver complete trip failed: %s", exc)
        return jsonify({"success": False, "error": "Could not complete trip right now."}), 500

    if not trip:
        return jsonify({"success": False, "error": "Trip cannot be completed from its current state."}), 409
    _emit_trip_update("trip_completed", trip)
    return jsonify({"success": True, "trip": trip}), 200


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
    current_photo_url = None
    current_license_document_url = None
    current_insurance_document_url = None

    account_id = int(user.get("account_id") or 0)
    if account_id:
        try:
            from Database.admin_queries import fetch_driver_document_paths, fetch_driver_profile_photo_path

            if fetch_driver_profile_photo_path(account_id):
                current_photo_url = url_for("api_driver_photo", driver_id=account_id)
            document_paths = fetch_driver_document_paths(account_id)
            if document_paths.get("license"):
                current_license_document_url = url_for("api_driver_document", driver_id=account_id, document_type="license")
            if document_paths.get("insurance"):
                current_insurance_document_url = url_for("api_driver_document", driver_id=account_id, document_type="insurance")
        except Exception as exc:
            app.logger.warning("Could not load current driver uploaded media paths: %s", exc)

    if request.method == "POST":
        form_data = {k: _v(k) for k in form_data}
        form_data["preferences"] = request.form.getlist("preferences")
        if any(not form_data[k] for k in ["first_name", "last_name", "email", "phone"]):
            error = "First name, last name, email, and phone are required."
        else:
            try:
                from Database.admin_queries import (
                    fetch_driver_document_paths,
                    fetch_driver_profile_photo_path,
                    fetch_portal_profile,
                    update_driver_documents,
                    update_driver_profile_photo,
                    update_portal_profile,
                )

                photo_payload, photo_error = _validate_and_store_driver_profile_photo(required=False)
                documents_saved = False
                if photo_error:
                    error = photo_error
                    photo_payload = None
                    raise ValueError(photo_error)

                document_payloads: list[dict[str, object]] = []
                if _has_driver_document_upload("license_document"):
                    license_payload, license_error = _validate_and_store_license_document()
                    if license_error or not license_payload:
                        error = license_error or "Could not read driver's license upload."
                        raise ValueError(error)
                    document_payloads.append(license_payload)

                if _has_driver_document_upload("insurance_document"):
                    insurance_payload, insurance_error = _validate_and_store_insurance_document()
                    if insurance_error or not insurance_payload:
                        _delete_stored_driver_documents(document_payloads)
                        error = insurance_error or "Could not read proof of vehicle insurance upload."
                        raise ValueError(error)
                    document_payloads.append(insurance_payload)

                payload = dict(form_data)
                payload["preferences"] = _join_preferences(form_data["preferences"])
                update_portal_profile("driver", int(user.get("account_id")), payload)
                if photo_payload:
                    existing_photo_path = fetch_driver_profile_photo_path(int(user.get("account_id")))
                    update_driver_profile_photo(int(user.get("account_id")), photo_payload)
                    new_photo_path = str(photo_payload.get("storage_path") or "").strip()
                    old_photo_path = str(existing_photo_path or "").strip()
                    if old_photo_path and old_photo_path != new_photo_path:
                        try:
                            (APP_PATH / old_photo_path).unlink(missing_ok=True)
                        except Exception as delete_exc:
                            app.logger.warning("Could not delete replaced profile photo '%s': %s", old_photo_path, delete_exc)
                    session_user = _driver_session_user()
                    session_user["status"] = "under_review"
                    session["driver_user"] = session_user
                    warning = "Profile photo changed. Your driver account has been placed under review again."
                if document_payloads:
                    existing_document_paths = fetch_driver_document_paths(int(user.get("account_id")))
                    update_driver_documents(int(user.get("account_id")), document_payloads)
                    documents_saved = True
                    for document in document_payloads:
                        document_type = str(document.get("document_type") or "").strip().lower()
                        new_document_path = str(document.get("storage_path") or "").strip()
                        old_document_path = str(existing_document_paths.get(document_type) or "").strip()
                        if old_document_path and old_document_path != new_document_path:
                            try:
                                (APP_PATH / old_document_path).unlink(missing_ok=True)
                            except Exception as delete_exc:
                                app.logger.warning("Could not delete replaced driver document '%s': %s", old_document_path, delete_exc)
                    session_user = _driver_session_user()
                    session_user["status"] = "under_review"
                    session["driver_user"] = session_user
                    warning = "Verification document changed. Your driver account has been placed under review again."
                refreshed = fetch_portal_profile("driver", int(user.get("account_id")))
                if refreshed:
                    session["driver_user"] = refreshed
                    user = refreshed
                if not error:
                    success = "Driver settings updated."
            except Exception as exc:
                if "document_payloads" in locals() and not locals().get("documents_saved", False):
                    _delete_stored_driver_documents(document_payloads)
                app.logger.warning("Driver settings update failed: %s", exc)
                if not error:
                    error = "Could not save settings right now."

    return render_template(
        "driver_settings.html",
        **_driver_nav_context(
            "settings",
            form_data=form_data,
            success=success,
            warning=warning,
            error=error,
            preference_options=PREFERENCE_OPTIONS,
            state_options=US_STATE_OPTIONS,
            current_photo_url=current_photo_url,
            current_license_document_url=current_license_document_url,
            current_insurance_document_url=current_insurance_document_url,
        ),
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
        document_payloads = None

        required = [
            "first_name",
            "last_name",
            "username",
            "email",
            "phone",
        ]
        if any(not form_data[f] for f in required):
            error = "Please fill in all required fields."
        elif len(password) < 6:
            error = "Password must be at least 6 characters."
        elif password != confirm_password:
            error = "Passwords do not match."
        else:
            document_payloads, document_error = _validate_and_store_driver_documents()
            if document_error:
                error = document_error

        if request.method == "POST" and not error:
            photo_payload, photo_error = _validate_and_store_driver_profile_photo()
            if photo_error:
                error = photo_error
                _delete_stored_driver_documents(document_payloads)
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
                    license_state=None,
                    license_number=None,
                    license_expires=None,
                    insurance_provider=None,
                    insurance_policy=None,
                    profile_photo=photo_payload,
                    documents=document_payloads,
                )
                success = f"Driver account created. Account ID: {account_id} (pending review)."
                form_data = _driver_signup_form()
            except Exception as exc:
                if photo_payload and photo_payload.get("storage_path"):
                    try:
                        (APP_PATH / photo_payload["storage_path"]).unlink(missing_ok=True)
                    except Exception:
                        pass
                _delete_stored_driver_documents(document_payloads)
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

def is_internal_authorized(req) -> bool:
    return req.headers.get("X-Internal-Key") == os.environ.get("INTERNAL_API_KEY", "change-this-key")


@app.route("/internal/notify", methods=["POST"])
def internal_notify():
    if not is_internal_authorized(request):
        return jsonify({"success": False, "error": "Unauthorized"}), 401

    payload = request.get_json(silent=True) or {}
    event_name = str(payload.get("event") or "").strip()
    inner = payload.get("payload") or {}

    target_role = str(inner.get("target_role") or "").strip()
    account_id = inner.get("account_id")

    if event_name == "" or target_role not in {"rider", "driver"} or not account_id:
        return jsonify({"success": False, "error": "Invalid payload"}), 400

    _emit_popup_notification(
        target_role=target_role,
        account_id=account_id,
        event_name=event_name,
        title=str(inner.get("title") or "Notification"),
        message=str(inner.get("message") or ""),
        trip=inner.get("trip") if isinstance(inner.get("trip"), dict) else None,
        extra=inner.get("extra") if isinstance(inner.get("extra"), dict) else None,
    )
    return jsonify({"success": True}), 200


if __name__ == "__main__":
    port = int(os.environ.get("DRIVER_PORT", "8002"))
    socketio.run(app, host="0.0.0.0", port=port, debug=True, allow_unsafe_werkzeug=True)
