from __future__ import annotations

import os
from datetime import datetime, timedelta
from typing import Any

from Database.db_con import get_connection


_PAYOUT_SCHEDULE_LABELS = {
    "per_trip": "After each ride",
    "weekly": "Weekly",
    "biweekly": "Biweekly",
    "monthly": "Monthly",
}


def _normalize_payout_schedule(value: str | None) -> str:
    key = str(value or "").strip().lower().replace("-", "_").replace(" ", "_")
    if key in _PAYOUT_SCHEDULE_LABELS:
        return key
    return "weekly"


def _load_payout_schedule() -> str:
    return _normalize_payout_schedule(os.environ.get("DRIVER_PAYOUT_SCHEDULE", "weekly"))


def _load_driver_fare_share() -> float:
    raw = str(os.environ.get("DRIVER_FARE_SHARE", "")).strip()
    if raw:
        try:
            v = float(raw)
            return min(max(v, 0.0), 1.0)
        except ValueError:
            pass
    pct = str(os.environ.get("ADMIN_FARE_SHARE_PCT", "")).strip()
    if pct:
        try:
            admin = min(max(float(pct) / 100.0, 0.0), 1.0)
            return 1.0 - admin
        except ValueError:
            pass
    return 0.75


def _pay_period_window(schedule: str) -> tuple[datetime, datetime, str]:
    """Inclusive start, exclusive end, human-readable range label."""
    now = datetime.now()
    schedule = _normalize_payout_schedule(schedule)
    if schedule == "monthly":
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        if start.month == 12:
            end = start.replace(year=start.year + 1, month=1)
        else:
            end = start.replace(month=start.month + 1)
        label = f"{start.strftime('%b %d, %Y')} – {(end - timedelta(seconds=1)).strftime('%b %d, %Y')}"
        return start, end, label
    if schedule == "weekly":
        # Week starts Monday
        weekday = now.weekday()
        start = (now - timedelta(days=weekday)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = start + timedelta(days=7)
        label = f"{start.strftime('%b %d')} – {(end - timedelta(days=1)).strftime('%b %d, %Y')}"
        return start, end, label
    if schedule == "biweekly":
        year_start = datetime(now.year, 1, 1)
        delta_days = max(0, (now - year_start).days)
        period_idx = delta_days // 14
        start = year_start + timedelta(days=period_idx * 14)
        end = start + timedelta(days=14)
        label = f"{start.strftime('%b %d, %Y')} – {(end - timedelta(seconds=1)).strftime('%b %d, %Y')}"
        return start, end, label
    # per_trip: show current week as reporting window (payouts are per ride)
    weekday = now.weekday()
    start = (now - timedelta(days=weekday)).replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=7)
    label = f"{start.strftime('%b %d')} – {(end - timedelta(days=1)).strftime('%b %d, %Y')} · {_PAYOUT_SCHEDULE_LABELS['per_trip']}"
    return start, end, label


def _aggregate_driver_trips_for_income(
    driver_id: int,
    driver_share: float,
    *,
    period_start: datetime | None = None,
    period_end_exclusive: datetime | None = None,
) -> dict[str, Any]:
    if not _table_exists("trip"):
        return {
            "trip_count": 0,
            "fare_earnings": 0.0,
            "total_tips": 0.0,
            "estimated_payout": 0.0,
        }
    where = "DriverID = %s AND Status = 'completed'"
    params: list[Any] = [driver_id]
    if period_start is not None and period_end_exclusive is not None:
        where += " AND CompletedAt IS NOT NULL AND CompletedAt >= %s AND CompletedAt < %s"
        params.extend([period_start, period_end_exclusive])
    rows = _fetch_all(
        f"""
        SELECT
            COUNT(*) AS trip_count,
            COALESCE(SUM(FinalCost), 0) AS gross_fare,
            COALESCE(SUM(TipAmount), 0) AS total_tips
        FROM trip
        WHERE {where}
        """,
        tuple(params),
    )
    row = rows[0] if rows else {}
    trip_count = int(row.get("trip_count") or 0)
    gross = float(row.get("gross_fare") or 0)
    tips = float(row.get("total_tips") or 0)
    fare_earnings = round(gross * driver_share, 2)
    estimated_payout = round(fare_earnings + tips, 2)
    return {
        "trip_count": trip_count,
        "fare_earnings": fare_earnings,
        "total_tips": round(tips, 2),
        "estimated_payout": estimated_payout,
    }


def _fetch_all(query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    conn = get_connection()
    try:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(query, params)
            return cursor.fetchall()
    finally:
        conn.close()


def _execute(query: str, params: tuple[Any, ...] = ()) -> int:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            conn.commit()
            return cursor.rowcount
    finally:
        conn.close()


def _insert_returning_id(query: str, params: tuple[Any, ...] = ()) -> int:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            conn.commit()
            return int(cursor.lastrowid)
    finally:
        conn.close()


def _table_exists(table_name: str) -> bool:
    rows = _fetch_all(
        """
        SELECT 1 AS has_table
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = %s
        LIMIT 1
        """,
        (table_name,),
    )
    return bool(rows)


def _column_exists(table_name: str, column_name: str) -> bool:
    rows = _fetch_all(
        """
        SELECT 1 AS has_column
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = %s
          AND column_name = %s
        LIMIT 1
        """,
        (table_name, column_name),
    )
    return bool(rows)


def _ensure_driver_dispatch_state_table() -> None:
    _execute(
        """
        CREATE TABLE IF NOT EXISTS driver_dispatch_state (
            DriverID INT NOT NULL PRIMARY KEY,
            IsAvailable TINYINT(1) NOT NULL DEFAULT 0,
            UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
            CONSTRAINT fk_driver_dispatch_state_driver
                FOREIGN KEY (DriverID) REFERENCES driver(AccountID)
                ON DELETE CASCADE
        )
        """
    )


def _ensure_driver_live_location_table() -> None:
    _execute(
        """
        CREATE TABLE IF NOT EXISTS driver_live_location (
            DriverID INT NOT NULL PRIMARY KEY,
            Latitude DECIMAL(10, 7) NOT NULL,
            Longitude DECIMAL(10, 7) NOT NULL,
            UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
            CONSTRAINT fk_driver_live_location_driver
                FOREIGN KEY (DriverID) REFERENCES driver(AccountID)
                ON DELETE CASCADE
        )
        """
    )


def _ensure_rider_match_swipe_table() -> None:
    _execute(
        """
        CREATE TABLE IF NOT EXISTS rider_match_swipe (
            SwipeID INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            RiderID INT NOT NULL,
            DriverID INT NOT NULL,
            Direction VARCHAR(8) NOT NULL,
            StartLoc VARCHAR(255) NULL,
            EndLoc VARCHAR(255) NULL,
            RideType VARCHAR(50) NULL,
            Notes TEXT NULL,
            CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
            CONSTRAINT fk_rider_match_swipe_rider
                FOREIGN KEY (RiderID) REFERENCES rider(AccountID)
                ON DELETE CASCADE,
            CONSTRAINT fk_rider_match_swipe_driver
                FOREIGN KEY (DriverID) REFERENCES driver(AccountID)
                ON DELETE CASCADE,
            CONSTRAINT uq_rider_match_swipe UNIQUE (RiderID, DriverID)
        )
        """
    )


def _ensure_dispatch_query_tables() -> None:
    """Tables joined by _dispatch_trip_select() must exist before any dispatch query."""
    _ensure_driver_live_location_table()


def _split_preference_csv(value: str | None) -> set[str]:
    if not value:
        return set()
    return {item.strip().lower() for item in str(value).split(",") if item.strip()}


def _ensure_trip_location_columns() -> None:
    """Widen address fields so geocoded / autocomplete strings do not fail inserts."""
    if not _table_exists("trip"):
        return
    rows = _fetch_all(
        """
        SELECT CHARACTER_MAXIMUM_LENGTH AS len
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'trip'
          AND column_name = 'StartLoc'
        LIMIT 1
        """,
    )
    if not rows:
        return
    try:
        max_len = int(rows[0].get("len") or 0)
    except (TypeError, ValueError):
        max_len = 0
    if max_len > 0 and max_len < 255:
        _execute("ALTER TABLE trip MODIFY StartLoc VARCHAR(255) NOT NULL")
        _execute("ALTER TABLE trip MODIFY EndLoc VARCHAR(255) NOT NULL")


def _ensure_trip_completed_at_column() -> None:
    if not _table_exists("trip") or _column_exists("trip", "CompletedAt"):
        return
    _execute("ALTER TABLE trip ADD COLUMN CompletedAt TIMESTAMP(6) NULL DEFAULT NULL")


def _ensure_tip_amount_column() -> None:
    if not _table_exists("trip") or _column_exists("trip", "TipAmount"):
        return
    _execute("ALTER TABLE trip ADD COLUMN TipAmount DECIMAL(10, 2) NOT NULL DEFAULT 0.00")


def _driver_info_mode() -> str | None:
    if _table_exists("driver_information"):
        return "driver_information"
    if _table_exists("driver_verification"):
        return "driver_verification"
    return None


def _driver_reviews() -> list[dict[str, Any]]:
    if not _table_exists("driver_review"):
        return []

    return _fetch_all(
        """
        SELECT
            dr.ReviewID AS review_id,
            dr.DriverID AS driver_id,
            CONCAT(dacc.FirstName, ' ', dacc.LastName) AS driver_name,
            dr.RiderID AS rider_id,
            CONCAT(racc.FirstName, ' ', racc.LastName) AS rider_name,
            dr.Rating AS rating,
            dr.Comment AS comment,
            dr.ReviewDate AS review_date
        FROM driver_review dr
        JOIN account dacc ON dacc.AccountID = dr.DriverID
        JOIN account racc ON racc.AccountID = dr.RiderID
        ORDER BY dr.ReviewDate DESC, dr.ReviewID DESC
        """
    )


def _driver_summary_rows() -> list[dict[str, Any]]:
    info_mode = _driver_info_mode()
    has_trip = _table_exists("trip")
    has_review = _table_exists("driver_review")
    has_profile_photo = _table_exists("driver_profile_photo")
    has_date_submitted = _column_exists("driver", "DateSubmitted")
    has_date_approved = _column_exists("driver", "DateApproved")

    if info_mode == "driver_information":
        info_select = """
            COALESCE(di.FirstName, a.FirstName) AS first_name,
            COALESCE(di.LastName, a.LastName) AS last_name,
            COALESCE(di.Email, a.Email) AS email,
            COALESCE(di.PhoneNum, a.PhoneNum) AS phone,
            CONCAT(COALESCE(di.FirstName, a.FirstName), ' ', COALESCE(di.LastName, a.LastName)) AS name,
            di.DateOfBirth AS date_of_birth,
            TIMESTAMPDIFF(YEAR, di.DateOfBirth, CURDATE()) AS age,
            di.LicenseState AS license_state,
            di.LicenseNumber AS license_number,
            di.LicenseExpires AS license_expires,
            di.InsuranceProvider AS insurance_provider,
            di.InsurancePolicy AS insurance_policy,
        """
        info_join = "LEFT JOIN driver_information di ON di.DriverID = d.AccountID"
        info_group_by = [
            "di.FirstName",
            "di.LastName",
            "di.Email",
            "di.PhoneNum",
            "di.DateOfBirth",
            "di.LicenseState",
            "di.LicenseNumber",
            "di.LicenseExpires",
            "di.InsuranceProvider",
            "di.InsurancePolicy",
        ]
    elif info_mode == "driver_verification":
        info_select = """
            a.FirstName AS first_name,
            a.LastName AS last_name,
            a.Email AS email,
            a.PhoneNum AS phone,
            CONCAT(a.FirstName, ' ', a.LastName) AS name,
            dv.DateOfBirth AS date_of_birth,
            TIMESTAMPDIFF(YEAR, dv.DateOfBirth, CURDATE()) AS age,
            dv.LicenseState AS license_state,
            dv.LicenseNumber AS license_number,
            dv.LicenseExpires AS license_expires,
            dv.InsuranceProvider AS insurance_provider,
            dv.InsurancePolicy AS insurance_policy,
        """
        info_join = "LEFT JOIN driver_verification dv ON dv.DriverID = d.AccountID"
        info_group_by = [
            "dv.DateOfBirth",
            "dv.LicenseState",
            "dv.LicenseNumber",
            "dv.LicenseExpires",
            "dv.InsuranceProvider",
            "dv.InsurancePolicy",
        ]
    else:
        info_select = """
            a.FirstName AS first_name,
            a.LastName AS last_name,
            a.Email AS email,
            a.PhoneNum AS phone,
            CONCAT(a.FirstName, ' ', a.LastName) AS name,
            NULL AS date_of_birth,
            NULL AS age,
            NULL AS license_state,
            NULL AS license_number,
            NULL AS license_expires,
            NULL AS insurance_provider,
            NULL AS insurance_policy,
        """
        info_join = ""
        info_group_by = []

    rating_expr = "ROUND(COALESCE(AVG(dr.Rating), 0), 1)" if has_review else "0.0"
    rides_expr = "COUNT(DISTINCT t.TripID)" if has_trip else "0"
    photo_select = """
            dpp.ModerationStatus AS photo_moderation_status,
            dpp.ModerationLabels AS photo_moderation_labels,
    """ if has_profile_photo else """
            NULL AS photo_moderation_status,
            NULL AS photo_moderation_labels,
    """
    date_select = f"""
            {"d.DateSubmitted" if has_date_submitted else "NULL"} AS date_submitted,
            {"d.DateApproved" if has_date_approved else "NULL"} AS date_approved,
    """

    joins: list[str] = []
    if info_join:
        joins.append(info_join)
    if has_profile_photo:
        joins.append("LEFT JOIN driver_profile_photo dpp ON dpp.DriverID = d.AccountID")
    if has_trip:
        joins.append("LEFT JOIN trip t ON t.DriverID = d.AccountID")
    if has_review:
        joins.append("LEFT JOIN driver_review dr ON dr.DriverID = d.AccountID")

    group_by_parts = [
        "d.AccountID",
        "a.FirstName",
        "a.LastName",
        "a.Email",
        "a.PhoneNum",
        "d.Status",
    ]
    if has_date_submitted:
        group_by_parts.append("d.DateSubmitted")
    if has_date_approved:
        group_by_parts.append("d.DateApproved")
    if has_profile_photo:
        group_by_parts.extend(["dpp.ModerationStatus", "dpp.ModerationLabels"])
    group_by_parts.extend(info_group_by)

    query = f"""
        SELECT
            d.AccountID AS account_id,
            d.Status AS status,
            {date_select}
            {photo_select}
            {info_select}
            {rating_expr} AS rating,
            {rides_expr} AS rides
        FROM driver d
        JOIN account a ON a.AccountID = d.AccountID
        {' '.join(joins)}
        GROUP BY {', '.join(group_by_parts)}
        ORDER BY last_name, first_name
    """
    return _fetch_all(query)


def driver_detail(driver_id: int) -> dict[str, Any] | None:
    info_mode = _driver_info_mode()
    has_trip = _table_exists("trip")
    has_review = _table_exists("driver_review")
    has_profile_photo = _table_exists("driver_profile_photo")
    has_date_submitted = _column_exists("driver", "DateSubmitted")
    has_date_approved = _column_exists("driver", "DateApproved")

    if info_mode == "driver_information":
        info_select = """
            COALESCE(di.FirstName, a.FirstName) AS first_name,
            COALESCE(di.LastName, a.LastName) AS last_name,
            COALESCE(di.Email, a.Email) AS email,
            COALESCE(di.PhoneNum, a.PhoneNum) AS phone,
            CONCAT(COALESCE(di.FirstName, a.FirstName), ' ', COALESCE(di.LastName, a.LastName)) AS name,
            di.DateOfBirth AS date_of_birth,
            TIMESTAMPDIFF(YEAR, di.DateOfBirth, CURDATE()) AS age,
            di.LicenseState AS license_state,
            di.LicenseNumber AS license_number,
            di.LicenseExpires AS license_expires,
            di.InsuranceProvider AS insurance_provider,
            di.InsurancePolicy AS insurance_policy,
            di.InformationNotes AS driver_notes,
        """
        info_join = "LEFT JOIN driver_information di ON di.DriverID = d.AccountID"
        info_group_by = [
            "di.FirstName",
            "di.LastName",
            "di.Email",
            "di.PhoneNum",
            "di.DateOfBirth",
            "di.LicenseState",
            "di.LicenseNumber",
            "di.LicenseExpires",
            "di.InsuranceProvider",
            "di.InsurancePolicy",
            "di.InformationNotes",
        ]
    elif info_mode == "driver_verification":
        info_select = """
            a.FirstName AS first_name,
            a.LastName AS last_name,
            a.Email AS email,
            a.PhoneNum AS phone,
            CONCAT(a.FirstName, ' ', a.LastName) AS name,
            dv.DateOfBirth AS date_of_birth,
            TIMESTAMPDIFF(YEAR, dv.DateOfBirth, CURDATE()) AS age,
            dv.LicenseState AS license_state,
            dv.LicenseNumber AS license_number,
            dv.LicenseExpires AS license_expires,
            dv.InsuranceProvider AS insurance_provider,
            dv.InsurancePolicy AS insurance_policy,
            dv.VerificationNotes AS driver_notes,
        """
        info_join = "LEFT JOIN driver_verification dv ON dv.DriverID = d.AccountID"
        info_group_by = [
            "dv.DateOfBirth",
            "dv.LicenseState",
            "dv.LicenseNumber",
            "dv.LicenseExpires",
            "dv.InsuranceProvider",
            "dv.InsurancePolicy",
            "dv.VerificationNotes",
        ]
    else:
        info_select = """
            a.FirstName AS first_name,
            a.LastName AS last_name,
            a.Email AS email,
            a.PhoneNum AS phone,
            CONCAT(a.FirstName, ' ', a.LastName) AS name,
            NULL AS date_of_birth,
            NULL AS age,
            NULL AS license_state,
            NULL AS license_number,
            NULL AS license_expires,
            NULL AS insurance_provider,
            NULL AS insurance_policy,
            NULL AS driver_notes,
        """
        info_join = ""
        info_group_by = []

    rating_expr = "COALESCE(AVG(dr.Rating), 0)" if has_review else "0"
    rides_expr = "COUNT(DISTINCT t.TripID)" if has_trip else "0"
    review_count_expr = "COUNT(DISTINCT dr.ReviewID)" if has_review else "0"
    date_submitted_expr = "d.DateSubmitted" if has_date_submitted else "NULL"
    date_approved_expr = "d.DateApproved" if has_date_approved else "NULL"
    photo_select = """
            dpp.StoragePath AS profile_photo_path,
            dpp.MimeType AS profile_photo_mime_type,
            dpp.FileSizeBytes AS profile_photo_file_size_bytes,
            dpp.ModerationStatus AS photo_moderation_status,
            dpp.ModerationScore AS photo_moderation_score,
            dpp.ModerationLabels AS photo_moderation_labels,
            dpp.ReviewedAt AS photo_reviewed_at,
    """ if has_profile_photo else """
            NULL AS profile_photo_path,
            NULL AS profile_photo_mime_type,
            NULL AS profile_photo_file_size_bytes,
            NULL AS photo_moderation_status,
            NULL AS photo_moderation_score,
            NULL AS photo_moderation_labels,
            NULL AS photo_reviewed_at,
    """

    joins: list[str] = []
    if info_join:
        joins.append(info_join)
    if has_profile_photo:
        joins.append("LEFT JOIN driver_profile_photo dpp ON dpp.DriverID = d.AccountID")
    if has_trip:
        joins.append("LEFT JOIN trip t ON t.DriverID = d.AccountID")
    if has_review:
        joins.append("LEFT JOIN driver_review dr ON dr.DriverID = d.AccountID")

    group_by_parts = [
        "d.AccountID",
        "a.FirstName",
        "a.LastName",
        "a.Email",
        "a.PhoneNum",
        "d.Status",
        "d.Preferences",
    ]
    if has_date_submitted:
        group_by_parts.append("d.DateSubmitted")
    if has_date_approved:
        group_by_parts.append("d.DateApproved")
    if has_profile_photo:
        group_by_parts.extend([
            "dpp.StoragePath",
            "dpp.MimeType",
            "dpp.FileSizeBytes",
            "dpp.ModerationStatus",
            "dpp.ModerationScore",
            "dpp.ModerationLabels",
            "dpp.ReviewedAt",
        ])
    group_by_parts.extend(info_group_by)

    rows = _fetch_all(
        f"""
        SELECT
            d.AccountID AS account_id,
            d.Status AS status,
            d.Preferences AS preferences,
            {date_submitted_expr} AS date_submitted,
            {date_approved_expr} AS date_approved,
            {photo_select}
            {info_select}
            {rating_expr} AS avg_rating,
            {rides_expr} AS total_rides,
            {review_count_expr} AS total_reviews
        FROM driver d
        JOIN account a ON a.AccountID = d.AccountID
        {' '.join(joins)}
        WHERE d.AccountID = %s
        GROUP BY {', '.join(group_by_parts)}
        """,
        (driver_id,),
    )
    return rows[0] if rows else None


def update_driver_status(driver_id: int, action: str) -> bool:
    status = "approved" if action == "approve" else "denied"
    has_date_submitted = _column_exists("driver", "DateSubmitted")
    has_date_approved = _column_exists("driver", "DateApproved")

    assignments: list[str] = ["Status = %s"]
    params: list[Any] = [status]
    if has_date_submitted:
        assignments.append("DateSubmitted = COALESCE(DateSubmitted, CURDATE())")
    if has_date_approved:
        assignments.append("DateApproved = CASE WHEN %s = 'approved' THEN CURDATE() ELSE NULL END")
        params.append(status)

    params.append(driver_id)
    rows = _execute(
        f"""
        UPDATE driver
        SET {', '.join(assignments)}
        WHERE AccountID = %s
        """,
        tuple(params),
    )
    return rows > 0


def fetch_dashboard_data() -> dict[str, Any]:
    all_driver_rows = _driver_summary_rows()
    review_rows = _driver_reviews()

    if _table_exists("driver_review"):
        driver_feedback_rows = _fetch_all(
            """
            SELECT
                CONCAT(
                    CONCAT(dacc.FirstName, ' ', dacc.LastName),
                    ' rated ',
                    dr.Rating,
                    '/5 by ',
                    CONCAT(racc.FirstName, ' ', racc.LastName)
                ) AS text
            FROM driver_review dr
            JOIN account dacc ON dacc.AccountID = dr.DriverID
            JOIN account racc ON racc.AccountID = dr.RiderID
            ORDER BY dr.ReviewDate DESC, dr.ReviewID DESC
            LIMIT 6
            """
        )
    else:
        driver_feedback_rows = []

    if _table_exists("trip"):
        recent_rides_rows = _fetch_all(
            """
            SELECT
                CONCAT(
                    CONCAT(dacc.FirstName, ' ', dacc.LastName),
                    ' with ',
                    CONCAT(racc.FirstName, ' ', racc.LastName)
                ) AS ride
            FROM trip t
            JOIN account dacc ON dacc.AccountID = t.DriverID
            JOIN account racc ON racc.AccountID = t.RiderID
            ORDER BY t.TripID DESC
            LIMIT 6
            """
        )
    else:
        recent_rides_rows = []

    active_driver_rows = [
        row
        for row in all_driver_rows
        if (row.get("status") or "").lower() in {"approved", "pending", "under_review", "denied", "rejected"}
    ]
    pending_verification = [
        row
        for row in all_driver_rows
        if (row.get("status") or "").lower() in {"pending", "under_review"}
    ]

    return {
        "new_drivers": [
            {"name": row["name"], "pending_docs": (row["status"] or "").lower() != "approved"}
            for row in pending_verification[:5]
        ],
        "driver_feedback": driver_feedback_rows,
        "all_drivers": active_driver_rows,
        "new_applications": [
            {
                "account_id": row["account_id"],
                "name": row["name"],
                "approved": (row["status"] or "").lower() == "approved",
                "status": row["status"],
            }
            for row in pending_verification
        ],
        "reports": [
            {
                "summary": (
                    f"{row['driver_name']} rated {row['rating']}/5 by "
                    f"{row['rider_name']}"
                ),
                "action": "View",
            }
            for row in review_rows[:8]
        ],
        "recent_reviews": [
            f"{row['rating']}/5 from {row['rider_name']} to {row['driver_name']}"
            for row in review_rows[:5]
        ],
        "recent_rides": [row["ride"] for row in recent_rides_rows],
        "driver_reviews": review_rows,
        "unapproved_drivers": pending_verification,
        "total_driver_count": len(all_driver_rows),
        "db_error": None,
    }


def create_rider_signup(
    *,
    username: str,
    email: str,
    phone: str,
    password: str,
    first_name: str,
    last_name: str,
    preferences: str,
) -> int:
    account_id = _insert_returning_id(
        """
        INSERT INTO account (UserName, Email, PhoneNum, Password, FirstName, LastName)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (username, email, phone, password, first_name, last_name),
    )
    if _column_exists("rider", "RidingSince"):
        _execute(
            """
            INSERT INTO rider (AccountID, Preferences, RidingSince)
            VALUES (%s, %s, CURDATE())
            """,
            (account_id, preferences or None),
        )
    else:
        _execute(
            """
            INSERT INTO rider (AccountID, Preferences)
            VALUES (%s, %s)
            """,
            (account_id, preferences or None),
        )
    return account_id


def create_driver_signup(
    *,
    username: str,
    email: str,
    phone: str,
    password: str,
    first_name: str,
    last_name: str,
    preferences: str,
    date_of_birth: str | None,
    license_state: str,
    license_number: str,
    license_expires: str | None,
    insurance_provider: str,
    insurance_policy: str,
    profile_photo: dict[str, Any] | None = None,
) -> int:
    account_id = _insert_returning_id(
        """
        INSERT INTO account (UserName, Email, PhoneNum, Password, FirstName, LastName)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (username, email, phone, password, first_name, last_name),
    )

    if _column_exists("driver", "DateSubmitted"):
        _execute(
            """
            INSERT INTO driver (AccountID, Preferences, Status, DateSubmitted)
            VALUES (%s, %s, %s, CURDATE())
            """,
            (account_id, preferences or None, "pending"),
        )
    else:
        _execute(
            """
            INSERT INTO driver (AccountID, Preferences, Status)
            VALUES (%s, %s, %s)
            """,
            (account_id, preferences or None, "pending"),
        )

    if _table_exists("driver_information"):
        _execute(
            """
            INSERT INTO driver_information
            (
                DriverID, FirstName, LastName, Email, PhoneNum, DateOfBirth,
                LicenseState, LicenseNumber, LicenseExpires, InsuranceProvider, InsurancePolicy
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                account_id,
                first_name,
                last_name,
                email,
                phone,
                date_of_birth or None,
                license_state,
                license_number,
                license_expires or None,
                insurance_provider,
                insurance_policy,
            ),
        )
    elif _table_exists("driver_verification"):
        _execute(
            """
            INSERT INTO driver_verification
            (
                DriverID, DateOfBirth, LicenseState, LicenseNumber, LicenseExpires,
                InsuranceProvider, InsurancePolicy
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                account_id,
                date_of_birth or None,
                license_state,
                license_number,
                license_expires or None,
                insurance_provider,
                insurance_policy,
            ),
        )

    if profile_photo and _table_exists("driver_profile_photo"):
        _execute(
            """
            INSERT INTO driver_profile_photo
            (
                DriverID, StoragePath, MimeType, FileSizeBytes,
                ModerationStatus, ModerationScore, ModerationLabels
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                account_id,
                profile_photo.get("storage_path"),
                profile_photo.get("mime_type"),
                profile_photo.get("file_size_bytes"),
                profile_photo.get("moderation_status") or "pending",
                profile_photo.get("moderation_score"),
                profile_photo.get("moderation_labels"),
            ),
        )

    return account_id


def authenticate_portal_user(role: str, username: str, password: str) -> dict[str, Any] | None:
    role = (role or "").strip().lower()
    if role not in {"driver", "rider"}:
        return None

    table_name = "driver" if role == "driver" else "rider"
    rows = _fetch_all(
        f"""
        SELECT
            a.AccountID AS account_id,
            a.UserName AS username,
            a.FirstName AS first_name,
            a.LastName AS last_name,
            a.Email AS email,
            a.PhoneNum AS phone,
            {table_name}.Preferences AS preferences
            {", driver.Status AS status" if role == "driver" else ""}
        FROM account a
        JOIN {table_name} ON {table_name}.AccountID = a.AccountID
        WHERE a.UserName = %s AND a.Password = %s
        LIMIT 1
        """,
        (username, password),
    )
    return rows[0] if rows else None


def fetch_portal_profile(role: str, account_id: int) -> dict[str, Any] | None:
    role = (role or "").strip().lower()
    if role == "rider":
        rows = _fetch_all(
            """
            SELECT
                a.AccountID AS account_id,
                a.UserName AS username,
                a.FirstName AS first_name,
                a.LastName AS last_name,
                a.Email AS email,
                a.PhoneNum AS phone,
                r.Preferences AS preferences
            FROM account a
            JOIN rider r ON r.AccountID = a.AccountID
            WHERE a.AccountID = %s
            LIMIT 1
            """,
            (account_id,),
        )
        return rows[0] if rows else None

    if role != "driver":
        return None

    info_mode = _driver_info_mode()
    if info_mode == "driver_information":
        info_select = """
            di.DateOfBirth AS date_of_birth,
            di.LicenseState AS license_state,
            di.LicenseNumber AS license_number,
            di.LicenseExpires AS license_expires,
            di.InsuranceProvider AS insurance_provider,
            di.InsurancePolicy AS insurance_policy
        """
        info_join = "LEFT JOIN driver_information di ON di.DriverID = d.AccountID"
    elif info_mode == "driver_verification":
        info_select = """
            dv.DateOfBirth AS date_of_birth,
            dv.LicenseState AS license_state,
            dv.LicenseNumber AS license_number,
            dv.LicenseExpires AS license_expires,
            dv.InsuranceProvider AS insurance_provider,
            dv.InsurancePolicy AS insurance_policy
        """
        info_join = "LEFT JOIN driver_verification dv ON dv.DriverID = d.AccountID"
    else:
        info_select = """
            NULL AS date_of_birth,
            NULL AS license_state,
            NULL AS license_number,
            NULL AS license_expires,
            NULL AS insurance_provider,
            NULL AS insurance_policy
        """
        info_join = ""

    rows = _fetch_all(
        f"""
        SELECT
            a.AccountID AS account_id,
            a.UserName AS username,
            a.FirstName AS first_name,
            a.LastName AS last_name,
            a.Email AS email,
            a.PhoneNum AS phone,
            d.Preferences AS preferences,
            d.Status AS status,
            {info_select}
        FROM account a
        JOIN driver d ON d.AccountID = a.AccountID
        {info_join}
        WHERE a.AccountID = %s
        LIMIT 1
        """,
        (account_id,),
    )
    return rows[0] if rows else None


def fetch_portal_dashboard_summary(role: str, account_id: int) -> dict[str, Any]:
    role = (role or "").strip().lower()
    data = {
        "trip_count": 0,
        "completed_count": 0,
        "active_count": 0,
        "avg_given_rating": None,
        "avg_received_rating": None,
    }
    if not _table_exists("trip"):
        return data

    if role == "driver":
        rows = _fetch_all(
            """
            SELECT
                COUNT(*) AS trip_count,
                SUM(CASE WHEN Status = 'completed' THEN 1 ELSE 0 END) AS completed_count,
                SUM(CASE WHEN Status IN ('requested','accepted','in_progress') THEN 1 ELSE 0 END) AS active_count,
                ROUND(AVG(DriverRate), 1) AS avg_given_rating,
                ROUND(AVG(RiderRate), 1) AS avg_received_rating
            FROM trip
            WHERE DriverID = %s
            """,
            (account_id,),
        )
    else:
        rows = _fetch_all(
            """
            SELECT
                COUNT(*) AS trip_count,
                SUM(CASE WHEN Status = 'completed' THEN 1 ELSE 0 END) AS completed_count,
                SUM(CASE WHEN Status IN ('requested','accepted','in_progress') THEN 1 ELSE 0 END) AS active_count,
                ROUND(AVG(RiderRate), 1) AS avg_given_rating,
                ROUND(AVG(DriverRate), 1) AS avg_received_rating
            FROM trip
            WHERE RiderID = %s
            """,
            (account_id,),
        )
    row = rows[0] if rows else {}
    for key in data:
        value = row.get(key) if isinstance(row, dict) else None
        data[key] = value if value is not None else data[key]
    return data


def fetch_portal_reviews(role: str, account_id: int) -> dict[str, list[dict[str, Any]]]:
    role = (role or "").strip().lower()
    result = {"received": [], "given": []}

    if role == "driver" and _table_exists("driver_review"):
        result["received"] = _fetch_all(
            """
            SELECT
                dr.ReviewID AS review_id,
                dr.ReviewDate AS review_date,
                dr.Rating AS rating,
                dr.Comment AS comment,
                CONCAT(racc.FirstName, ' ', racc.LastName) AS counterpart_name,
                'rider_to_driver' AS source
            FROM driver_review dr
            JOIN account racc ON racc.AccountID = dr.RiderID
            WHERE dr.DriverID = %s
            ORDER BY dr.ReviewDate DESC, dr.ReviewID DESC
            """,
            (account_id,),
        )

    if _table_exists("trip"):
        if role == "driver":
            result["given"] = _fetch_all(
                """
                SELECT
                    t.TripID AS review_id,
                    NULL AS review_date,
                    t.DriverRate AS rating,
                    NULL AS comment,
                    CONCAT(racc.FirstName, ' ', racc.LastName) AS counterpart_name,
                    t.Status AS trip_status,
                    'driver_to_rider' AS source
                FROM trip t
                JOIN account racc ON racc.AccountID = t.RiderID
                WHERE t.DriverID = %s
                  AND t.DriverRate IS NOT NULL
                ORDER BY t.TripID DESC
                """,
                (account_id,),
            )
        else:
            result["received"] = _fetch_all(
                """
                SELECT
                    t.TripID AS review_id,
                    NULL AS review_date,
                    t.DriverRate AS rating,
                    NULL AS comment,
                    'Anonymous' AS counterpart_name,
                    t.Status AS trip_status,
                    'driver_to_rider' AS source
                FROM trip t
                JOIN account dacc ON dacc.AccountID = t.DriverID
                WHERE t.RiderID = %s
                  AND t.DriverRate IS NOT NULL
                ORDER BY t.TripID DESC
                """,
                (account_id,),
            )
            result["given"] = _fetch_all(
                """
                SELECT
                    COALESCE(dr.ReviewID, t.TripID) AS review_id,
                    dr.ReviewDate AS review_date,
                    COALESCE(dr.Rating, t.RiderRate) AS rating,
                    dr.Comment AS comment,
                    CONCAT(dacc.FirstName, ' ', dacc.LastName) AS counterpart_name,
                    t.Status AS trip_status,
                    CASE WHEN dr.ReviewID IS NULL THEN 'rider_trip_rating' ELSE 'rider_to_driver' END AS source
                FROM trip t
                JOIN account dacc ON dacc.AccountID = t.DriverID
                LEFT JOIN driver_review dr
                  ON dr.TripID = t.TripID
                 AND dr.RiderID = t.RiderID
                WHERE t.RiderID = %s
                  AND t.RiderRate IS NOT NULL
                ORDER BY t.TripID DESC
                """,
                (account_id,),
            )

    return result


def fetch_portal_trip_history(role: str, account_id: int) -> list[dict[str, Any]]:
    if not _table_exists("trip"):
        return []
    role = (role or "").strip().lower()
    if role == "driver":
        where_col = "t.DriverID"
        counterpart_join = "JOIN account racc ON racc.AccountID = t.RiderID"
        counterpart_name = "CONCAT(racc.FirstName, ' ', racc.LastName)"
        counterpart_label = "rider_name"
    else:
        where_col = "t.RiderID"
        counterpart_join = "JOIN account dacc ON dacc.AccountID = t.DriverID"
        counterpart_name = "CONCAT(dacc.FirstName, ' ', dacc.LastName)"
        counterpart_label = "driver_name"

    _ensure_tip_amount_column()
    return _fetch_all(
        f"""
        SELECT
            t.TripID AS trip_id,
            t.Status AS status,
            t.StartLoc AS start_loc,
            t.EndLoc AS end_loc,
            t.FinalCost AS final_cost,
            t.DriverRate AS driver_rate,
            t.RiderRate AS rider_rate,
            COALESCE(t.TipAmount, 0) AS tip_amount,
            {counterpart_name} AS {counterpart_label}
        FROM trip t
        {counterpart_join}
        WHERE {where_col} = %s
        ORDER BY t.TripID DESC
        LIMIT 20
        """,
        (account_id,),
    )


def _dispatch_trip_select() -> str:
    return """
        SELECT
            t.TripID AS trip_id,
            t.Status AS status,
            t.StartLoc AS start_loc,
            t.EndLoc AS end_loc,
            t.FinalCost AS final_cost,
            t.DriverID AS driver_id,
            t.RiderID AS rider_id,
            CONCAT(dacc.FirstName, ' ', dacc.LastName) AS driver_name,
            CONCAT(racc.FirstName, ' ', racc.LastName) AS rider_name,
            d.Status AS driver_status,
            dl.Latitude AS driver_latitude,
            dl.Longitude AS driver_longitude,
            dl.UpdatedAt AS driver_location_updated_at
        FROM trip t
        JOIN account dacc ON dacc.AccountID = t.DriverID
        JOIN account racc ON racc.AccountID = t.RiderID
        LEFT JOIN driver d ON d.AccountID = t.DriverID
        LEFT JOIN driver_live_location dl ON dl.DriverID = t.DriverID
    """


def fetch_active_rider_trip(account_id: int) -> dict[str, Any] | None:
    if not _table_exists("trip"):
        return None
    _ensure_dispatch_query_tables()
    rows = _fetch_all(
        f"""
        {_dispatch_trip_select()}
        WHERE t.RiderID = %s
          AND t.Status IN ('requested', 'accepted', 'in_progress')
        ORDER BY FIELD(t.Status, 'in_progress', 'accepted', 'requested'), t.TripID DESC
        LIMIT 1
        """,
        (account_id,),
    )
    return rows[0] if rows else None


def fetch_active_driver_trip(account_id: int) -> dict[str, Any] | None:
    if not _table_exists("trip"):
        return None
    _ensure_dispatch_query_tables()
    rows = _fetch_all(
        f"""
        {_dispatch_trip_select()}
        WHERE t.DriverID = %s
          AND t.Status IN ('requested', 'accepted', 'in_progress')
        ORDER BY FIELD(t.Status, 'in_progress', 'accepted', 'requested'), t.TripID DESC
        LIMIT 1
        """,
        (account_id,),
    )
    return rows[0] if rows else None


def _pick_best_driver_for_request() -> int | None:
    if not _table_exists("driver") or not _table_exists("trip"):
        return None
    _ensure_driver_dispatch_state_table()
    rows = _fetch_all(
        """
        SELECT
            d.AccountID AS account_id,
            COUNT(DISTINCT completed.TripID) AS completed_count
        FROM driver d
        JOIN driver_dispatch_state ds
            ON ds.DriverID = d.AccountID
        LEFT JOIN trip active_trip
            ON active_trip.DriverID = d.AccountID
           AND active_trip.Status IN ('requested', 'accepted', 'in_progress')
        LEFT JOIN trip completed
            ON completed.DriverID = d.AccountID
           AND completed.Status = 'completed'
        WHERE COALESCE(d.Status, '') = 'approved'
          AND ds.IsAvailable = 1
          AND active_trip.TripID IS NULL
        GROUP BY d.AccountID
        ORDER BY completed_count DESC, d.AccountID ASC
        LIMIT 1
        """
    )
    if not rows:
        return None
    return int(rows[0]["account_id"])


def _driver_is_matchable(driver_id: int) -> bool:
    if not _table_exists("driver") or not _table_exists("trip"):
        return False
    _ensure_driver_dispatch_state_table()
    rows = _fetch_all(
        """
        SELECT d.AccountID AS account_id
        FROM driver d
        JOIN driver_dispatch_state ds
            ON ds.DriverID = d.AccountID
        LEFT JOIN trip active_trip
            ON active_trip.DriverID = d.AccountID
           AND active_trip.Status IN ('requested', 'accepted', 'in_progress')
        WHERE d.AccountID = %s
          AND COALESCE(d.Status, '') = 'approved'
          AND ds.IsAvailable = 1
          AND active_trip.TripID IS NULL
        LIMIT 1
        """,
        (driver_id,),
    )
    return bool(rows)


def _create_trip_with_driver(
    *,
    rider_id: int,
    driver_id: int,
    start_loc: str,
    end_loc: str,
) -> dict[str, Any]:
    _ensure_trip_location_columns()
    _ensure_dispatch_query_tables()

    normalized_start = start_loc.strip()
    normalized_end = end_loc.strip()
    trip_id = _insert_returning_id(
        """
        INSERT INTO trip (RiderID, DriverID, Status, StartLoc, EndLoc, FinalCost, DriverRate, RiderRate)
        VALUES (%s, %s, 'requested', %s, %s, %s, NULL, NULL)
        """,
        (rider_id, driver_id, normalized_start, normalized_end, 0.00),
    )
    created_trip = _fetch_all(
        f"""
        {_dispatch_trip_select()}
        WHERE t.TripID = %s
        LIMIT 1
        """,
        (trip_id,),
    )
    if not created_trip:
        raise ValueError("Ride request was created but could not be loaded.")
    return created_trip[0]


def fetch_driver_match_candidates(
    *,
    rider_id: int,
    start_loc: str = "",
    end_loc: str = "",
    ride_type: str = "standard",
    notes: str | None = None,
    limit: int = 12,
) -> list[dict[str, Any]]:
    if not _table_exists("driver") or not _table_exists("trip"):
        return []
    _ensure_driver_dispatch_state_table()
    _ensure_driver_live_location_table()
    _ensure_rider_match_swipe_table()
    has_review = _table_exists("driver_review")

    rating_expr = "ROUND(COALESCE(AVG(dr.Rating), 0), 1)" if has_review else "0.0"
    review_join = "LEFT JOIN driver_review dr ON dr.DriverID = d.AccountID" if has_review else ""
    review_group_by = ", dl.Latitude, dl.Longitude, dl.UpdatedAt" if has_review else ", dl.Latitude, dl.Longitude, dl.UpdatedAt"

    rows = _fetch_all(
        f"""
        SELECT
            d.AccountID AS account_id,
            a.FirstName AS first_name,
            a.LastName AS last_name,
            CONCAT(a.FirstName, ' ', a.LastName) AS name,
            d.Preferences AS preferences,
            {rating_expr} AS rating,
            COUNT(DISTINCT completed.TripID) AS rides,
            dl.Latitude AS driver_latitude,
            dl.Longitude AS driver_longitude,
            dl.UpdatedAt AS driver_location_updated_at
        FROM driver d
        JOIN account a
            ON a.AccountID = d.AccountID
        JOIN driver_dispatch_state ds
            ON ds.DriverID = d.AccountID
        LEFT JOIN trip active_trip
            ON active_trip.DriverID = d.AccountID
           AND active_trip.Status IN ('requested', 'accepted', 'in_progress')
        LEFT JOIN trip completed
            ON completed.DriverID = d.AccountID
           AND completed.Status = 'completed'
        LEFT JOIN rider_match_swipe rms
            ON rms.RiderID = %s
           AND rms.DriverID = d.AccountID
        LEFT JOIN driver_live_location dl
            ON dl.DriverID = d.AccountID
        {review_join}
        WHERE COALESCE(d.Status, '') = 'approved'
          AND ds.IsAvailable = 1
          AND active_trip.TripID IS NULL
          AND COALESCE(rms.Direction, '') <> 'left'
        GROUP BY
            d.AccountID,
            a.FirstName,
            a.LastName,
            d.Preferences
            {review_group_by}
        ORDER BY {rating_expr} DESC, rides DESC, d.AccountID ASC
        LIMIT %s
        """,
        (rider_id, max(1, min(int(limit), 50))),
    )

    rider = fetch_portal_profile("rider", rider_id) or {}
    rider_preferences = _split_preference_csv(str(rider.get("preferences") or ""))
    desired_ride_type = (ride_type or "standard").strip().lower() or "standard"
    normalized_start = start_loc.strip()
    normalized_end = end_loc.strip()
    normalized_notes = (notes or "").strip()

    candidates: list[dict[str, Any]] = []
    for row in rows:
        candidate = dict(row)
        driver_preferences = _split_preference_csv(str(candidate.get("preferences") or ""))
        matching_preferences = sorted(rider_preferences.intersection(driver_preferences))
        compatibility_score = len(matching_preferences)
        candidate["matching_preferences"] = matching_preferences
        candidate["compatibility_score"] = compatibility_score
        candidate["pickup_preview"] = normalized_start
        candidate["dropoff_preview"] = normalized_end
        candidate["ride_type"] = desired_ride_type
        candidate["notes_preview"] = normalized_notes
        candidates.append(candidate)

    candidates.sort(
        key=lambda row: (
            -int(row.get("compatibility_score") or 0),
            -float(row.get("rating") or 0),
            -int(row.get("rides") or 0),
            int(row.get("account_id") or 0),
        )
    )
    return candidates


def record_rider_match_choice(
    *,
    rider_id: int,
    driver_id: int,
    direction: str,
    start_loc: str = "",
    end_loc: str = "",
    ride_type: str = "standard",
    notes: str | None = None,
) -> bool:
    normalized_direction = str(direction or "").strip().lower()
    if normalized_direction not in {"left", "right"}:
        return False
    _ensure_rider_match_swipe_table()
    rows = _execute(
        """
        INSERT INTO rider_match_swipe (RiderID, DriverID, Direction, StartLoc, EndLoc, RideType, Notes)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
            Direction = VALUES(Direction),
            StartLoc = VALUES(StartLoc),
            EndLoc = VALUES(EndLoc),
            RideType = VALUES(RideType),
            Notes = VALUES(Notes)
        """,
        (
            rider_id,
            driver_id,
            normalized_direction,
            start_loc.strip(),
            end_loc.strip(),
            (ride_type or "standard").strip() or "standard",
            (notes or "").strip() or None,
        ),
    )
    return rows >= 0


def create_matched_trip_for_driver(
    *,
    rider_id: int,
    driver_id: int,
    start_loc: str,
    end_loc: str,
    ride_type: str = "standard",
    notes: str | None = None,
) -> dict[str, Any]:
    existing_trip = fetch_active_rider_trip(rider_id)
    if existing_trip:
        return existing_trip
    if not _driver_is_matchable(driver_id):
        raise ValueError("That driver is no longer available. Try another card.")
    record_rider_match_choice(
        rider_id=rider_id,
        driver_id=driver_id,
        direction="right",
        start_loc=start_loc,
        end_loc=end_loc,
        ride_type=ride_type,
        notes=notes,
    )
    return _create_trip_with_driver(
        rider_id=rider_id,
        driver_id=driver_id,
        start_loc=start_loc,
        end_loc=end_loc,
    )


def create_matched_trip(
    *,
    rider_id: int,
    start_loc: str,
    end_loc: str,
    ride_type: str = "standard",
    notes: str | None = None,
) -> dict[str, Any]:
    _ensure_trip_location_columns()
    _ensure_dispatch_query_tables()
    existing_trip = fetch_active_rider_trip(rider_id)
    if existing_trip:
        return existing_trip

    driver_id = _pick_best_driver_for_request()
    if driver_id is None:
        raise ValueError("No approved drivers are available right now.")

    record_rider_match_choice(
        rider_id=rider_id,
        driver_id=driver_id,
        direction="right",
        start_loc=start_loc,
        end_loc=end_loc,
        ride_type=ride_type,
        notes=notes,
    )
    return _create_trip_with_driver(
        rider_id=rider_id,
        driver_id=driver_id,
        start_loc=start_loc,
        end_loc=end_loc,
    )


def update_trip_status_for_driver(
    *,
    trip_id: int,
    driver_id: int,
    next_status: str,
    final_cost: float | None = None,
) -> dict[str, Any] | None:
    status_map = {
        "accepted": ("requested",),
        "in_progress": ("accepted",),
        "completed": ("in_progress",),
        "canceled": ("requested", "accepted"),
    }
    allowed_prior = status_map.get(next_status)
    if not allowed_prior:
        return None

    assignments = ["Status = %s"]
    params: list[Any] = [next_status]
    if next_status == "completed":
        _ensure_trip_completed_at_column()
        assignments.append("FinalCost = %s")
        params.append(final_cost if final_cost is not None else 0.00)
        assignments.append("CompletedAt = CURRENT_TIMESTAMP(6)")

    status_placeholders = ", ".join(["%s"] * len(allowed_prior))
    params.extend([trip_id, driver_id, *allowed_prior])
    rows = _execute(
        f"""
        UPDATE trip
        SET {', '.join(assignments)}
        WHERE TripID = %s
          AND DriverID = %s
          AND Status IN ({status_placeholders})
        """,
        tuple(params),
    )
    if rows <= 0:
        return None
    return fetch_active_driver_trip(driver_id) if next_status != "completed" else fetch_trip_by_id(trip_id)


def cancel_trip_for_rider(*, trip_id: int, rider_id: int) -> bool:
    rows = _execute(
        """
        UPDATE trip
        SET Status = 'canceled'
        WHERE TripID = %s
          AND RiderID = %s
          AND Status IN ('requested', 'accepted')
        """,
        (trip_id, rider_id),
    )
    return rows > 0


def fetch_trip_by_id(trip_id: int) -> dict[str, Any] | None:
    if not _table_exists("trip"):
        return None
    _ensure_dispatch_query_tables()
    rows = _fetch_all(
        f"""
        {_dispatch_trip_select()}
        WHERE t.TripID = %s
        LIMIT 1
        """,
        (trip_id,),
    )
    return rows[0] if rows else None


def fetch_driver_availability(account_id: int) -> bool:
    _ensure_driver_dispatch_state_table()
    rows = _fetch_all(
        """
        SELECT IsAvailable AS is_available
        FROM driver_dispatch_state
        WHERE DriverID = %s
        LIMIT 1
        """,
        (account_id,),
    )
    if not rows:
        _execute(
            """
            INSERT INTO driver_dispatch_state (DriverID, IsAvailable)
            VALUES (%s, 0)
            ON DUPLICATE KEY UPDATE DriverID = VALUES(DriverID)
            """,
            (account_id,),
        )
        return False
    return bool(rows[0].get("is_available"))


def set_driver_availability(account_id: int, is_available: bool) -> bool:
    _ensure_driver_dispatch_state_table()
    rows = _execute(
        """
        INSERT INTO driver_dispatch_state (DriverID, IsAvailable)
        VALUES (%s, %s)
        ON DUPLICATE KEY UPDATE IsAvailable = VALUES(IsAvailable)
        """,
        (account_id, 1 if is_available else 0),
    )
    return rows >= 0


def update_driver_live_location(account_id: int, latitude: float, longitude: float) -> bool:
    _ensure_driver_live_location_table()
    rows = _execute(
        """
        INSERT INTO driver_live_location (DriverID, Latitude, Longitude)
        VALUES (%s, %s, %s)
        ON DUPLICATE KEY UPDATE
            Latitude = VALUES(Latitude),
            Longitude = VALUES(Longitude)
        """,
        (account_id, latitude, longitude),
    )
    return rows >= 0


def update_portal_profile(role: str, account_id: int, profile: dict[str, Any]) -> bool:
    role = (role or "").strip().lower()
    _execute(
        """
        UPDATE account
        SET FirstName = %s, LastName = %s, Email = %s, PhoneNum = %s
        WHERE AccountID = %s
        """,
        (
            profile.get("first_name"),
            profile.get("last_name"),
            profile.get("email"),
            profile.get("phone"),
            account_id,
        ),
    )

    if role == "rider":
        _execute(
            """
            UPDATE rider
            SET Preferences = %s
            WHERE AccountID = %s
            """,
            (profile.get("preferences") or None, account_id),
        )
        return True

    if role != "driver":
        return False

    _execute(
        """
        UPDATE driver
        SET Preferences = %s
        WHERE AccountID = %s
        """,
        (profile.get("preferences") or None, account_id),
    )

    info_mode = _driver_info_mode()
    if info_mode == "driver_information":
        _execute(
            """
            UPDATE driver_information
            SET FirstName = %s, LastName = %s, Email = %s, PhoneNum = %s,
                DateOfBirth = %s, LicenseState = %s, LicenseNumber = %s,
                LicenseExpires = %s, InsuranceProvider = %s, InsurancePolicy = %s
            WHERE DriverID = %s
            """,
            (
                profile.get("first_name"),
                profile.get("last_name"),
                profile.get("email"),
                profile.get("phone"),
                profile.get("date_of_birth") or None,
                profile.get("license_state") or None,
                profile.get("license_number") or None,
                profile.get("license_expires") or None,
                profile.get("insurance_provider") or None,
                profile.get("insurance_policy") or None,
                account_id,
            ),
        )
    elif info_mode == "driver_verification":
        _execute(
            """
            UPDATE driver_verification
            SET DateOfBirth = %s, LicenseState = %s, LicenseNumber = %s,
                LicenseExpires = %s, InsuranceProvider = %s, InsurancePolicy = %s
            WHERE DriverID = %s
            """,
            (
                profile.get("date_of_birth") or None,
                profile.get("license_state") or None,
                profile.get("license_number") or None,
                profile.get("license_expires") or None,
                profile.get("insurance_provider") or None,
                profile.get("insurance_policy") or None,
                account_id,
            ),
        )
    return True


def update_driver_profile_photo(account_id: int, profile_photo: dict[str, Any]) -> bool:
    if not _table_exists("driver_profile_photo"):
        return False

    _execute(
        """
        INSERT INTO driver_profile_photo
        (
            DriverID, StoragePath, MimeType, FileSizeBytes,
            ModerationStatus, ModerationScore, ModerationLabels, ReviewedAt
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, NULL)
        ON DUPLICATE KEY UPDATE
            StoragePath = VALUES(StoragePath),
            MimeType = VALUES(MimeType),
            FileSizeBytes = VALUES(FileSizeBytes),
            ModerationStatus = VALUES(ModerationStatus),
            ModerationScore = VALUES(ModerationScore),
            ModerationLabels = VALUES(ModerationLabels),
            ReviewedAt = NULL,
            ReviewedBy = NULL
        """,
        (
            account_id,
            profile_photo.get("storage_path"),
            profile_photo.get("mime_type"),
            profile_photo.get("file_size_bytes"),
            profile_photo.get("moderation_status") or "pending",
            profile_photo.get("moderation_score"),
            profile_photo.get("moderation_labels"),
        ),
    )

    _execute(
        """
        UPDATE driver
        SET Status = %s
        WHERE AccountID = %s
        """,
        ("under_review", account_id),
    )
    return True


def fetch_driver_profile_photo_path(account_id: int) -> str | None:
    if not _table_exists("driver_profile_photo"):
        return None
    rows = _fetch_all(
        """
        SELECT StoragePath AS storage_path
        FROM driver_profile_photo
        WHERE DriverID = %s
        LIMIT 1
        """,
        (account_id,),
    )
    if not rows:
        return None
    return rows[0].get("storage_path")


def update_rider_password(account_id: int, current_password: str, new_password: str) -> tuple[bool, str]:
    rows = _fetch_all(
        "SELECT UserName FROM account WHERE AccountID = %s LIMIT 1",
        (account_id,),
    )
    if not rows:
        return False, "Account not found."
    username = str(rows[0].get("UserName") or "").strip()
    if not username:
        return False, "Account not found."
    verified = authenticate_portal_user("rider", username, current_password)
    if not verified:
        return False, "Current password is incorrect."
    if len(new_password) < 6:
        return False, "Password must be at least 6 characters."
    _execute(
        "UPDATE account SET Password = %s WHERE AccountID = %s",
        (new_password, account_id),
    )
    return True, "Password updated."


def update_driver_password(account_id: int, current_password: str, new_password: str) -> tuple[bool, str]:
    rows = _fetch_all(
        "SELECT UserName FROM account WHERE AccountID = %s LIMIT 1",
        (account_id,),
    )
    if not rows:
        return False, "Account not found."
    username = str(rows[0].get("UserName") or "").strip()
    if not username:
        return False, "Account not found."
    verified = authenticate_portal_user("driver", username, current_password)
    if not verified:
        return False, "Current password is incorrect."
    if len(new_password) < 6:
        return False, "Password must be at least 6 characters."
    _execute(
        "UPDATE account SET Password = %s WHERE AccountID = %s",
        (new_password, account_id),
    )
    return True, "Password updated."


def fetch_trips_pending_rider_rating(rider_id: int) -> list[dict[str, Any]]:
    if not _table_exists("trip"):
        return []
    _ensure_tip_amount_column()
    return _fetch_all(
        """
        SELECT
            t.TripID AS trip_id,
            t.Status AS status,
            t.StartLoc AS start_loc,
            t.EndLoc AS end_loc,
            t.FinalCost AS final_cost,
            COALESCE(t.TipAmount, 0) AS tip_amount,
            CONCAT(dacc.FirstName, ' ', dacc.LastName) AS driver_name
        FROM trip t
        JOIN account dacc ON dacc.AccountID = t.DriverID
        WHERE t.RiderID = %s
          AND t.Status = 'completed'
          AND t.RiderRate IS NULL
        ORDER BY t.TripID DESC
        LIMIT 25
        """,
        (rider_id,),
    )


def fetch_trips_pending_driver_rating(driver_id: int) -> list[dict[str, Any]]:
    if not _table_exists("trip"):
        return []
    return _fetch_all(
        """
        SELECT
            t.TripID AS trip_id,
            t.Status AS status,
            t.StartLoc AS start_loc,
            t.EndLoc AS end_loc,
            t.FinalCost AS final_cost,
            CONCAT(racc.FirstName, ' ', racc.LastName) AS rider_name
        FROM trip t
        JOIN account racc ON racc.AccountID = t.RiderID
        WHERE t.DriverID = %s
          AND t.Status = 'completed'
          AND t.DriverRate IS NULL
        ORDER BY t.TripID DESC
        LIMIT 25
        """,
        (driver_id,),
    )


def submit_driver_rating_for_rider(
    driver_id: int,
    trip_id: int,
    rating: int,
    comment: str | None = None,
) -> tuple[bool, str]:
    if not _table_exists("trip"):
        return False, "Trips are not available."
    rating = max(1, min(5, int(rating)))
    rows = _fetch_all(
        """
        SELECT t.TripID, t.RiderID, t.DriverID, t.Status, t.DriverRate
        FROM trip t
        WHERE t.TripID = %s AND t.DriverID = %s
        """,
        (trip_id, driver_id),
    )
    if not rows:
        return False, "Trip not found."
    row = rows[0]
    if (row.get("Status") or "").strip().lower() != "completed":
        return False, "You can only review completed trips."
    if row.get("DriverRate") is not None:
        return False, "You already submitted a rating for this trip."
    rider_id = int(row.get("RiderID") or 0)
    if not rider_id:
        return False, "Trip has no rider."

    _execute(
        """
        UPDATE trip
        SET DriverRate = %s
        WHERE TripID = %s AND DriverID = %s
        """,
        (rating, trip_id, driver_id),
    )

    if _table_exists("rider_review"):
        existing = _fetch_all(
            """
            SELECT ReviewID FROM rider_review
            WHERE TripID = %s AND DriverID = %s
            LIMIT 1
            """,
            (trip_id, driver_id),
        )
        comment_val = (comment or "").strip() or None
        if existing:
            _execute(
                """
                UPDATE rider_review
                SET Rating = %s, Comment = %s
                WHERE TripID = %s AND DriverID = %s
                """,
                (rating, comment_val, trip_id, driver_id),
            )
        else:
            _execute(
                """
                INSERT INTO rider_review (RiderID, DriverID, TripID, Rating, Comment)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (rider_id, driver_id, trip_id, rating, comment_val),
            )

    return True, "Thanks for your feedback."


def fetch_driver_income_stats(driver_id: int) -> dict[str, Any]:
    """Driver-facing income: fare share from ADMIN_* env settings + tips. Pay period window matches DRIVER_PAYOUT_SCHEDULE."""
    _ensure_trip_completed_at_column()
    _ensure_tip_amount_column()
    driver_share = _load_driver_fare_share()
    schedule = _load_payout_schedule()
    pct_display = int(round(driver_share * 100))
    period_start, period_end, range_label = _pay_period_window(schedule)

    if not _table_exists("trip"):
        empty = {
            "trip_count": 0,
            "fare_earnings": 0.0,
            "total_tips": 0.0,
            "estimated_payout": 0.0,
        }
        return {
            "all_time": dict(empty),
            "pay_period": dict(empty),
            "recent_tips": [],
            "payout": {
                "schedule_key": schedule,
                "schedule_label": _PAYOUT_SCHEDULE_LABELS.get(schedule, schedule),
                "period_range_label": range_label,
                "driver_fare_share_pct": pct_display,
            },
        }

    all_time = _aggregate_driver_trips_for_income(driver_id, driver_share)
    pay_period = _aggregate_driver_trips_for_income(
        driver_id,
        driver_share,
        period_start=period_start,
        period_end_exclusive=period_end,
    )

    recent_tips_rows = _fetch_all(
        """
        SELECT
            t.TripID AS trip_id,
            t.StartLoc AS start_loc,
            t.EndLoc AS end_loc,
            COALESCE(t.TipAmount, 0) AS tip_amount
        FROM trip t
        WHERE t.DriverID = %s
          AND t.Status = 'completed'
          AND COALESCE(t.TipAmount, 0) > 0
        ORDER BY t.TripID DESC
        LIMIT 20
        """,
        (driver_id,),
    )
    recent_tips = []
    for row in recent_tips_rows:
        recent_tips.append(
            {
                "trip_id": int(row.get("trip_id") or 0),
                "start_loc": row.get("start_loc"),
                "end_loc": row.get("end_loc"),
                "tip_amount": float(row.get("tip_amount") or 0),
            }
        )

    return {
        "all_time": all_time,
        "pay_period": pay_period,
        "recent_tips": recent_tips,
        "payout": {
            "schedule_key": schedule,
            "schedule_label": _PAYOUT_SCHEDULE_LABELS.get(schedule, schedule),
            "period_range_label": range_label,
            "driver_fare_share_pct": pct_display,
        },
    }


def submit_rider_rating_for_driver(
    rider_id: int,
    trip_id: int,
    rating: int,
    comment: str | None = None,
    tip_amount: float | None = None,
) -> tuple[bool, str]:
    if not _table_exists("trip"):
        return False, "Trips are not available."
    _ensure_tip_amount_column()
    rating = max(1, min(5, int(rating)))
    rows = _fetch_all(
        """
        SELECT t.TripID, t.RiderID, t.Status, t.DriverID, t.RiderRate
        FROM trip t
        WHERE t.TripID = %s AND t.RiderID = %s
        """,
        (trip_id, rider_id),
    )
    if not rows:
        return False, "Trip not found."
    row = rows[0]
    if (row.get("Status") or "").strip().lower() != "completed":
        return False, "You can only review completed trips."
    if row.get("RiderRate") is not None:
        return False, "You already submitted a rating for this trip."
    driver_id = int(row.get("DriverID") or 0)
    if not driver_id:
        return False, "Trip has no driver."

    _execute(
        """
        UPDATE trip
        SET RiderRate = %s
        WHERE TripID = %s AND RiderID = %s
        """,
        (rating, trip_id, rider_id),
    )

    if _table_exists("driver_review"):
        existing = _fetch_all(
            """
            SELECT ReviewID FROM driver_review
            WHERE TripID = %s AND RiderID = %s
            LIMIT 1
            """,
            (trip_id, rider_id),
        )
        comment_val = (comment or "").strip() or None
        if existing:
            _execute(
                """
                UPDATE driver_review
                SET Rating = %s, Comment = %s
                WHERE TripID = %s AND RiderID = %s
                """,
                (rating, comment_val, trip_id, rider_id),
            )
        else:
            _execute(
                """
                INSERT INTO driver_review (DriverID, RiderID, TripID, Rating, Comment)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (driver_id, rider_id, trip_id, rating, comment_val),
            )

    if tip_amount is not None:
        try:
            tip_val = float(tip_amount)
        except (TypeError, ValueError):
            return False, "Tip amount is invalid."
        tip_val = max(0.0, min(round(tip_val, 2), 999.99))
        _execute(
            """
            UPDATE trip
            SET TipAmount = %s
            WHERE TripID = %s AND RiderID = %s
            """,
            (tip_val, trip_id, rider_id),
        )

    return True, "Thanks for your feedback."


def submit_rider_tip_for_trip(
    rider_id: int,
    trip_id: int,
    tip_amount: float,
) -> tuple[bool, str]:
    """Set tip after the rider already submitted a rating (e.g. add a tip later)."""
    if not _table_exists("trip"):
        return False, "Trips are not available."
    _ensure_tip_amount_column()
    try:
        tip_val = float(tip_amount)
    except (TypeError, ValueError):
        return False, "Tip amount is invalid."
    tip_val = max(0.0, min(round(tip_val, 2), 999.99))
    rows = _fetch_all(
        """
        SELECT t.TripID, t.RiderID, t.Status, t.RiderRate, COALESCE(t.TipAmount, 0) AS tip_amt
        FROM trip t
        WHERE t.TripID = %s AND t.RiderID = %s
        """,
        (trip_id, rider_id),
    )
    if not rows:
        return False, "Trip not found."
    row = rows[0]
    if (row.get("Status") or "").strip().lower() != "completed":
        return False, "You can only tip on completed trips."
    if row.get("RiderRate") is None:
        return False, "Rate your driver before adding a tip."
    existing_tip = float(row.get("tip_amt") or 0)
    if existing_tip > 0:
        return False, "A tip was already added for this trip."
    _execute(
        """
        UPDATE trip
        SET TipAmount = %s
        WHERE TripID = %s AND RiderID = %s
        """,
        (tip_val, trip_id, rider_id),
    )
    return True, "Tip saved."
