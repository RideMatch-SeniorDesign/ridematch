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
) -> int:
    account_id = _insert_returning_id(
        """
        INSERT INTO account (UserName, Email, PhoneNum, Password, FirstName, LastName)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (username, email, phone, password, first_name, last_name),
    )

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
                SUM(CASE WHEN Status IN ('requested','in_progress') THEN 1 ELSE 0 END) AS active_count,
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
                SUM(CASE WHEN Status IN ('requested','in_progress') THEN 1 ELSE 0 END) AS active_count,
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
                    CONCAT(dacc.FirstName, ' ', dacc.LastName) AS counterpart_name,
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
            {counterpart_name} AS {counterpart_label}
        FROM trip t
        {counterpart_join}
        WHERE {where_col} = %s
        ORDER BY t.TripID DESC
        LIMIT 20
        """,
        (account_id,),
    )


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
