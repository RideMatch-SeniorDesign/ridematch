from __future__ import annotations

from typing import Any

from AdminDatabase.db_con import get_connection


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


def _driver_to_rider_reviews() -> list[dict[str, Any]]:
    if _table_exists("rider_review"):
        return _fetch_all(
            """
            SELECT
                rr.ReviewID AS review_id,
                rr.TripID AS trip_id,
                rr.DriverID AS driver_id,
                rr.RiderID AS rider_id,
                CONCAT(dacc.FirstName, ' ', dacc.LastName) AS driver_name,
                CONCAT(racc.FirstName, ' ', racc.LastName) AS rider_name,
                rr.Rating AS rating,
                rr.Comment AS comment,
                rr.ReviewDate AS review_date
            FROM rider_review rr
            JOIN account dacc ON dacc.AccountID = rr.DriverID
            JOIN account racc ON racc.AccountID = rr.RiderID
            ORDER BY rr.ReviewDate DESC, rr.ReviewID DESC
            """
        )

    # Compatibility fallback for older schemas before rider_review existed.
    if not _table_exists("trip"):
        return []

    return _fetch_all(
        """
        SELECT
            t.TripID AS review_id,
            t.TripID AS trip_id,
            t.DriverID AS driver_id,
            t.RiderID AS rider_id,
            CONCAT(dacc.FirstName, ' ', dacc.LastName) AS driver_name,
            CONCAT(racc.FirstName, ' ', racc.LastName) AS rider_name,
            t.DriverRate AS rating,
            CONCAT('Trip #', t.TripID, ': ', t.StartLoc, ' to ', t.EndLoc) AS comment,
            NULL AS review_date
        FROM trip t
        JOIN account dacc ON dacc.AccountID = t.DriverID
        JOIN account racc ON racc.AccountID = t.RiderID
        WHERE t.DriverRate IS NOT NULL
        ORDER BY t.TripID DESC
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
    has_document = _table_exists("driver_document")
    has_document_details = has_document and _column_exists("driver_document", "ExtractedName")
    has_car = _table_exists("car")
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
            di.LicenseExpires AS license_expiration,
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
            dv.LicenseExpires AS license_expiration,
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
            NULL AS license_expiration,
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
    document_select = """
            license_doc.StoragePath AS license_document_path,
            license_doc.MimeType AS license_document_mime_type,
            license_doc.FileSizeBytes AS license_document_file_size_bytes,
            license_doc.RecognitionStatus AS license_document_recognition_status,
            license_doc.RecognitionLabels AS license_document_recognition_labels,
            license_doc.UploadedAt AS license_document_uploaded_at,
            insurance_doc.StoragePath AS insurance_document_path,
            insurance_doc.MimeType AS insurance_document_mime_type,
            insurance_doc.FileSizeBytes AS insurance_document_file_size_bytes,
            insurance_doc.RecognitionStatus AS insurance_document_recognition_status,
            insurance_doc.RecognitionLabels AS insurance_document_recognition_labels,
            insurance_doc.UploadedAt AS insurance_document_uploaded_at,
            CASE
                WHEN insurance_doc.RecognitionStatus = 'approved' THEN 'Verified'
                WHEN insurance_doc.StoragePath IS NOT NULL THEN COALESCE(insurance_doc.RecognitionStatus, 'Pending')
                ELSE 'Pending'
            END AS insurance_verified,
    """ if has_document else """
            NULL AS license_document_path,
            NULL AS license_document_mime_type,
            NULL AS license_document_file_size_bytes,
            NULL AS license_document_recognition_status,
            NULL AS license_document_recognition_labels,
            NULL AS license_document_uploaded_at,
            NULL AS insurance_document_path,
            NULL AS insurance_document_mime_type,
            NULL AS insurance_document_file_size_bytes,
            NULL AS insurance_document_recognition_status,
            NULL AS insurance_document_recognition_labels,
            NULL AS insurance_document_uploaded_at,
            'Pending' AS insurance_verified,
    """
    document_detail_select = """
            license_doc.ExtractedName AS license_document_extracted_name,
            license_doc.IssuedDate AS license_document_issued_date,
            license_doc.ExpirationDate AS license_document_expiration_date,
            insurance_doc.EffectiveDate AS insurance_document_effective_date,
            insurance_doc.ExpirationDate AS insurance_document_expiration_date,
            insurance_doc.Vin AS insurance_document_vin,
            insurance_doc.VehicleColor AS insurance_document_vehicle_color,
    """ if has_document_details else """
            NULL AS license_document_extracted_name,
            NULL AS license_document_issued_date,
            NULL AS license_document_expiration_date,
            NULL AS insurance_document_effective_date,
            NULL AS insurance_document_expiration_date,
            NULL AS insurance_document_vin,
            NULL AS insurance_document_vehicle_color,
    """
    car_select = """
            c.Make AS vehicle_make,
            c.Model AS vehicle_model,
            c.Color AS vehicle_color,
            c.PlateNum AS license_plate,
    """ if has_car else """
            NULL AS vehicle_make,
            NULL AS vehicle_model,
            NULL AS vehicle_color,
            NULL AS license_plate,
    """

    joins: list[str] = []
    if info_join:
        joins.append(info_join)
    if has_profile_photo:
        joins.append("LEFT JOIN driver_profile_photo dpp ON dpp.DriverID = d.AccountID")
    if has_document:
        joins.append("LEFT JOIN driver_document license_doc ON license_doc.DriverID = d.AccountID AND license_doc.DocumentType = 'license'")
        joins.append("LEFT JOIN driver_document insurance_doc ON insurance_doc.DriverID = d.AccountID AND insurance_doc.DocumentType = 'insurance'")
    if has_car:
        joins.append("LEFT JOIN car c ON c.DriverID = d.AccountID")
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
    if has_document:
        group_by_parts.extend([
            "license_doc.StoragePath",
            "license_doc.MimeType",
            "license_doc.FileSizeBytes",
            "license_doc.RecognitionStatus",
            "license_doc.RecognitionLabels",
            "license_doc.UploadedAt",
            "insurance_doc.StoragePath",
            "insurance_doc.MimeType",
            "insurance_doc.FileSizeBytes",
            "insurance_doc.RecognitionStatus",
            "insurance_doc.RecognitionLabels",
            "insurance_doc.UploadedAt",
        ])
    if has_document_details:
        group_by_parts.extend([
            "license_doc.ExtractedName",
            "license_doc.IssuedDate",
            "license_doc.ExpirationDate",
            "insurance_doc.EffectiveDate",
            "insurance_doc.ExpirationDate",
            "insurance_doc.Vin",
            "insurance_doc.VehicleColor",
        ])
    if has_car:
        group_by_parts.extend(["c.Make", "c.Model", "c.Color", "c.PlateNum"])
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
            {document_select}
            {document_detail_select}
            {car_select}
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
    driver_to_rider_review_rows = _driver_to_rider_reviews()

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
                "photo_moderation_status": row.get("photo_moderation_status"),
                "photo_moderation_labels": row.get("photo_moderation_labels"),
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
        "driver_to_rider_reviews": driver_to_rider_review_rows,
        "unapproved_drivers": pending_verification,
        "total_driver_count": len(active_driver_rows),
        "db_error": None,
    }

def fetch_riders() -> list[dict[str, Any]]:
    """Fetch all riders with their information."""
    has_riding_since = _column_exists("rider", "RidingSince")
    riding_since_select = "r.RidingSince AS riding_since," if has_riding_since else "NULL AS riding_since,"
    riding_since_group = ", r.RidingSince" if has_riding_since else ""

    query = f"""
    SELECT
        r.AccountID AS account_id,
        CONCAT(a.FirstName, ' ', a.LastName) AS name,
        a.Email AS email,
        a.PhoneNum AS phone,
        r.Preferences AS preferences,
        r.Rating AS rating,
        {riding_since_select}
        COUNT(DISTINCT t.TripID) AS rides
    FROM rider r
    JOIN account a ON r.AccountID = a.AccountID
    LEFT JOIN trip t ON t.RiderID = r.AccountID
    GROUP BY r.AccountID, a.FirstName, a.LastName, a.Email, a.PhoneNum, r.Preferences, r.Rating{riding_since_group}
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


def fetch_rider_reviews() -> list[dict[str, Any]]:
    """Fetch rider-submitted reviews with rider and driver names."""
    if not _table_exists("driver_review"):
        return []

    return _fetch_all(
        """
        SELECT
            dr.ReviewID AS review_id,
            dr.Rating AS rating,
            dr.Comment AS comment,
            dr.ReviewDate AS review_date,
            dr.RiderID AS rider_id,
            dr.DriverID AS driver_id,
            CONCAT(racc.FirstName, ' ', racc.LastName) AS rider_name,
            CONCAT(dacc.FirstName, ' ', dacc.LastName) AS driver_name
        FROM driver_review dr
        JOIN account racc ON racc.AccountID = dr.RiderID
        JOIN account dacc ON dacc.AccountID = dr.DriverID
        ORDER BY dr.ReviewDate DESC, dr.ReviewID DESC
        """
    )


def fetch_driver_to_rider_reviews() -> list[dict[str, Any]]:
    """Fetch driver-submitted reviews/ratings for riders."""
    return _driver_to_rider_reviews()


def fetch_rider_trip_activity(limit: int = 120) -> list[dict[str, Any]]:
    """Fetch ongoing and recent trips for admin rider activity monitoring."""
    if not _table_exists("trip"):
        return []

    has_platform_fee = _column_exists("trip", "PlatformFee")
    has_tax_amount = _column_exists("trip", "TaxAmount")
    has_tip_amount = _column_exists("trip", "TipAmount")

    platform_fee_expr = "t.PlatformFee" if has_platform_fee else "ROUND(COALESCE(t.FinalCost, 0) * 0.10, 2)"
    tax_amount_expr = "t.TaxAmount" if has_tax_amount else "ROUND(COALESCE(t.FinalCost, 0) * 0.07, 2)"
    tip_amount_expr = "t.TipAmount" if has_tip_amount else "0.00"

    safe_limit = max(1, min(int(limit), 500))
    return _fetch_all(
        f"""
        SELECT
            t.TripID AS trip_id,
            t.Status AS status,
            CASE
                WHEN t.Status IN ('requested', 'accepted', 'in_progress') THEN 'ongoing'
                ELSE 'recent'
            END AS activity_type,
            t.StartLoc AS start_loc,
            t.EndLoc AS end_loc,
            t.FinalCost AS final_cost,
            {platform_fee_expr} AS platform_fee,
            {tax_amount_expr} AS tax_amount,
            {tip_amount_expr} AS tip_amount,
            t.DriverRate AS driver_rate,
            t.RiderRate AS rider_rate,
            t.RiderID AS rider_id,
            t.DriverID AS driver_id,
            CONCAT(racc.FirstName, ' ', racc.LastName) AS rider_name,
            CONCAT(dacc.FirstName, ' ', dacc.LastName) AS driver_name
        FROM trip t
        JOIN account racc ON racc.AccountID = t.RiderID
        JOIN account dacc ON dacc.AccountID = t.DriverID
        ORDER BY
            CASE WHEN t.Status IN ('requested', 'accepted', 'in_progress') THEN 0 ELSE 1 END,
            t.TripID DESC
        LIMIT %s
        """,
        (safe_limit,),
    )
