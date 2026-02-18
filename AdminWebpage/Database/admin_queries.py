from __future__ import annotations

from typing import Any

from Database.db_con import get_connection


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

    joins: list[str] = []
    if info_join:
        joins.append(info_join)
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
    group_by_parts.extend(info_group_by)

    query = f"""
        SELECT
            d.AccountID AS account_id,
            d.Status AS status,
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

    joins: list[str] = []
    if info_join:
        joins.append(info_join)
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
    group_by_parts.extend(info_group_by)

    rows = _fetch_all(
        f"""
        SELECT
            d.AccountID AS account_id,
            d.Status AS status,
            d.Preferences AS preferences,
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
    rows = _execute(
        """
        UPDATE driver
        SET Status = %s
        WHERE AccountID = %s
        """,
        (status, driver_id),
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
        if (row.get("status") or "").lower() == "approved"
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
        "total_driver_count": len(active_driver_rows),
        "db_error": None,
    }

def fetch_riders() -> list[dict[str, Any]]:
    """Fetch all riders with their information."""
    query = """
    SELECT
        r.AccountID AS account_id,
        CONCAT(a.FirstName, ' ', a.LastName) AS name,
        a.Email AS email,
        a.PhoneNum AS phone,
        r.Preferences AS preferences,
        r.Rating AS rating,
        COUNT(DISTINCT t.TripID) AS rides
    FROM rider r
    JOIN account a ON r.AccountID = a.AccountID
    LEFT JOIN trip t ON t.RiderID = r.AccountID
    GROUP BY r.AccountID, a.FirstName, a.LastName, a.Email, a.PhoneNum, r.Preferences, r.Rating
    ORDER BY a.FirstName, a.LastName
    """
    return _fetch_all(query)


def fetch_rider_statistics() -> dict[str, Any]:
    """Fetch rider statistics."""
    total_riders = _fetch_all("SELECT COUNT(*) as count FROM rider")
    total_rides = _fetch_all("SELECT COUNT(*) as count FROM trip")
    return {
        "total_rider_count": total_riders[0]["count"] if total_riders else 0,
        "total_rides": total_rides[0]["count"] if total_rides else 0,
    }
