import copy
import sys
from datetime import date
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import app as app_module


class FakeAdminRepository:
    def __init__(
        self,
        module,
        drivers,
        riders,
        trips,
        rider_reviews,
        driver_to_rider_reviews,
    ):
        self._module = module
        self._drivers = {
            driver["account_id"]: copy.deepcopy(driver)
            for driver in drivers
        }
        self._riders = copy.deepcopy(riders)
        self._trips = copy.deepcopy(trips)
        self._rider_reviews = copy.deepcopy(rider_reviews)
        self._driver_to_rider_reviews = copy.deepcopy(driver_to_rider_reviews)
        self.budget_updates = []
        self.password_updates = []

    def _driver_summary(self, driver):
        return {
            "account_id": driver["account_id"],
            "name": driver["name"],
            "email": driver["email"],
            "phone": driver["phone"],
            "status": driver["status"],
            "date_submitted": driver["date_submitted"],
            "date_approved": driver["date_approved"],
            "rating": driver["rating"],
            "rides": driver["rides"],
            "age": driver["age"],
            "license_state": driver["license_state"],
            "license_number": driver["license_number"],
            "license_expires": driver["license_expires"],
            "insurance_provider": driver["insurance_provider"],
            "insurance_policy": driver["insurance_policy"],
            "photo_moderation_status": driver["photo_moderation_status"],
            "photo_moderation_labels": driver["photo_moderation_labels"],
        }

    def _all_driver_rows(self):
        return [
            self._driver_summary(driver)
            for driver in sorted(self._drivers.values(), key=lambda row: (row["name"], row["account_id"]))
        ]

    def _unapproved_rows(self):
        return [
            self._driver_summary(driver)
            for driver in sorted(self._drivers.values(), key=lambda row: (row["name"], row["account_id"]))
            if driver["status"] in {"pending", "under_review"}
        ]

    def fetch_dashboard_data(self):
        unapproved_rows = self._unapproved_rows()
        recent_trips = sorted(self._trips, key=lambda row: row["trip_id"], reverse=True)
        dashboard_data = {
            "new_drivers": [
                {
                    "name": row["name"],
                    "pending_docs": row["status"] != "approved",
                }
                for row in unapproved_rows[:5]
            ],
            "driver_feedback": [
                {
                    "text": (
                        f"{review['driver_name']} rated {review['rating']}/5 by "
                        f"{review['rider_name']}"
                    )
                }
                for review in self._rider_reviews[:5]
            ],
            "all_drivers": self._all_driver_rows(),
            "unapproved_drivers": unapproved_rows,
            "new_applications": [
                {
                    "account_id": row["account_id"],
                    "name": row["name"],
                    "approved": False,
                    "status": row["status"],
                    "photo_moderation_status": row["photo_moderation_status"],
                    "photo_moderation_labels": row["photo_moderation_labels"],
                }
                for row in unapproved_rows
            ],
            "reports": [
                {
                    "summary": (
                        f"{review['driver_name']} rated {review['rating']}/5 by "
                        f"{review['rider_name']}"
                    ),
                    "action": "View",
                }
                for review in self._rider_reviews
            ],
            "recent_reviews": [
                f"{review['rating']}/5 from {review['rider_name']} to {review['driver_name']}"
                for review in self._rider_reviews[:5]
            ],
            "recent_rides": [
                f"{trip['driver_name']} with {trip['rider_name']}"
                for trip in recent_trips[:5]
            ],
            "driver_reviews": copy.deepcopy(self._rider_reviews),
            "driver_to_rider_reviews": copy.deepcopy(self._driver_to_rider_reviews),
            "budget_breakdown": [
                {"label": "Operations", "value": 7200, "color": "#2563eb"},
                {"label": "Driver Incentives", "value": 3200, "color": "#22c55e"},
                {"label": "Safety & Compliance", "value": 1800, "color": "#f59e0b"},
                {"label": "Reserve", "value": 1400, "color": "#7c3aed"},
            ],
            "upcoming_events": [
                {"title": "Weekly verification audit", "type": "Operations", "date": "2026-04-01"},
                {"title": "Monthly budget review", "type": "Finance", "date": "2026-04-05"},
            ],
            "total_driver_count": len(self._drivers),
            "all_riders": copy.deepcopy(sorted(self._riders, key=lambda row: (row["name"], row["account_id"]))),
            "rider_reviews": copy.deepcopy(self._rider_reviews),
            "rider_trip_activity": copy.deepcopy(recent_trips),
            "total_rider_count": len(self._riders),
            "total_rides": len(self._trips),
            "db_error": None,
        }
        return copy.deepcopy(dashboard_data)

    def fetch_driver_detail(self, driver_id):
        driver = self._drivers.get(driver_id)
        return copy.deepcopy(driver) if driver else None

    def update_driver_status(self, driver_id, action):
        driver = self._drivers.get(driver_id)
        if not driver or action not in {"approve", "deny"}:
            return False

        if action == "approve":
            driver["status"] = "approved"
            driver["date_approved"] = date(2025, 3, 1)
        else:
            driver["status"] = "denied"
            driver["date_approved"] = None

        return True

    def set_budget_settings(self, admin_fare_share_pct, payout_schedule):
        normalized_schedule = self._module._normalize_payout_schedule(payout_schedule)
        normalized_pct = int(admin_fare_share_pct)
        self.budget_updates.append((normalized_pct, normalized_schedule))
        self._module.ADMIN_FARE_SHARE = normalized_pct / 100.0
        self._module.DRIVER_FARE_SHARE = 1.0 - self._module.ADMIN_FARE_SHARE
        self._module.DRIVER_PAYOUT_SCHEDULE = normalized_schedule
        return True, None

    def set_admin_password(self, new_password):
        self.password_updates.append(new_password)
        self._module.ADMIN_PASSWORD = new_password
        return True, None


@pytest.fixture
def drivers_seed():
    return [
        {
            "account_id": 1,
            "name": "Alice Approved",
            "email": "alice.approved@example.com",
            "phone": "319-555-1001",
            "status": "approved",
            "date_submitted": date(2024, 1, 10),
            "date_approved": date(2024, 1, 15),
            "rating": 4.9,
            "rides": 120,
            "age": 34,
            "preferences": "Quiet rides preferred",
            "license_state": "IA",
            "license_number": "IA-1001",
            "license_expires": date(2027, 1, 15),
            "license_expiration": "2027-01-15",
            "insurance_provider": "State Farm",
            "insurance_policy": "POL1001",
            "driver_notes": "Top performer with strong rider feedback.",
            "background_check": "Cleared",
            "vehicle_make": "Toyota",
            "vehicle_model": "Camry",
            "license_plate": "ADM-101",
            "insurance_verified": "Verified",
            "avg_rating": 4.9,
            "total_rides": 120,
            "total_reviews": 14,
            "profile_photo_path": "",
            "photo_moderation_status": "approved",
            "photo_moderation_score": 0.01,
            "photo_moderation_labels": "",
            "photo_reviewed_at": "2026-02-20",
        },
        {
            "account_id": 2,
            "name": "Ben Benton",
            "email": "ben.pending@example.com",
            "phone": "319-555-1002",
            "status": "pending",
            "date_submitted": date(2025, 2, 10),
            "date_approved": None,
            "rating": 4.2,
            "rides": 12,
            "age": 29,
            "preferences": "No highway routes",
            "license_state": "IA",
            "license_number": "IA-1002",
            "license_expires": date(2026, 8, 1),
            "license_expiration": "2026-08-01",
            "insurance_provider": "Geico",
            "insurance_policy": "POL1002",
            "driver_notes": "Waiting on final document review.",
            "background_check": "Pending",
            "vehicle_make": "Honda",
            "vehicle_model": "Civic",
            "license_plate": "ADM-102",
            "insurance_verified": "Pending",
            "avg_rating": 4.2,
            "total_rides": 12,
            "total_reviews": 3,
            "profile_photo_path": "",
            "photo_moderation_status": "pending",
            "photo_moderation_score": None,
            "photo_moderation_labels": "",
            "photo_reviewed_at": None,
        },
        {
            "account_id": 3,
            "name": "Carla Cruz",
            "email": "carla.denied@example.com",
            "phone": "319-555-1003",
            "status": "denied",
            "date_submitted": date(2024, 11, 12),
            "date_approved": None,
            "rating": 3.4,
            "rides": 8,
            "age": 41,
            "preferences": "Airport trips only",
            "license_state": "IL",
            "license_number": "IL-1003",
            "license_expires": date(2026, 5, 20),
            "license_expiration": "2026-05-20",
            "insurance_provider": "Progressive",
            "insurance_policy": "POL1003",
            "driver_notes": "Application previously denied for expired insurance.",
            "background_check": "Cleared",
            "vehicle_make": "Ford",
            "vehicle_model": "Escape",
            "license_plate": "ADM-103",
            "insurance_verified": "Expired",
            "avg_rating": 3.4,
            "total_rides": 8,
            "total_reviews": 2,
            "profile_photo_path": "",
            "photo_moderation_status": "approved",
            "photo_moderation_score": 0.03,
            "photo_moderation_labels": "",
            "photo_reviewed_at": "2025-11-02",
        },
        {
            "account_id": 4,
            "name": "Devin Doyle",
            "email": "devin.review@example.com",
            "phone": "319-555-1004",
            "status": "under_review",
            "date_submitted": date(2025, 1, 20),
            "date_approved": None,
            "rating": 4.6,
            "rides": 30,
            "age": 31,
            "preferences": "Pet friendly",
            "license_state": "IA",
            "license_number": "IA-1004",
            "license_expires": date(2027, 3, 12),
            "license_expiration": "2027-03-12",
            "insurance_provider": "Allstate",
            "insurance_policy": "POL1004",
            "driver_notes": "Photo needs manual moderation review.",
            "background_check": "Cleared",
            "vehicle_make": "Subaru",
            "vehicle_model": "Outback",
            "license_plate": "ADM-104",
            "insurance_verified": "Verified",
            "avg_rating": 4.6,
            "total_rides": 30,
            "total_reviews": 6,
            "profile_photo_path": "",
            "photo_moderation_status": "flagged",
            "photo_moderation_score": 0.82,
            "photo_moderation_labels": "document glare",
            "photo_reviewed_at": "2026-03-01",
        },
    ]


@pytest.fixture
def riders_seed():
    return [
        {
            "account_id": 101,
            "name": "Rita Rider",
            "email": "rita.rider@example.com",
            "phone": "319-555-2001",
            "preferences": "Quiet ride",
            "rating": 4.7,
            "rides": 18,
            "riding_since": date(2024, 2, 1),
        },
        {
            "account_id": 102,
            "name": "Sam Student",
            "email": "sam.student@example.com",
            "phone": "319-555-2002",
            "preferences": "Music okay",
            "rating": 4.3,
            "rides": 9,
            "riding_since": date(2025, 1, 15),
        },
        {
            "account_id": 103,
            "name": "Taylor Traveler",
            "email": "taylor.traveler@example.com",
            "phone": "319-555-2003",
            "preferences": "Needs trunk space",
            "rating": 4.9,
            "rides": 24,
            "riding_since": date(2023, 9, 5),
        },
    ]


@pytest.fixture
def trips_seed():
    return [
        {
            "trip_id": 604,
            "driver_id": 3,
            "rider_name": "Rita Rider",
            "driver_name": "Carla Cruz",
            "status": "canceled",
            "activity_type": "recent",
            "start_loc": "Cedar Rapids",
            "end_loc": "Iowa City",
            "final_cost": 0.0,
            "platform_fee": 0.0,
            "tax_amount": 0.0,
            "tip_amount": 0.0,
        },
        {
            "trip_id": 603,
            "driver_id": 1,
            "rider_name": "Taylor Traveler",
            "driver_name": "Alice Approved",
            "status": "in_progress",
            "activity_type": "ongoing",
            "start_loc": "Iowa City",
            "end_loc": "North Liberty",
            "final_cost": 0.0,
            "platform_fee": 0.0,
            "tax_amount": 0.0,
            "tip_amount": 0.0,
        },
        {
            "trip_id": 602,
            "driver_id": 1,
            "rider_name": "Sam Student",
            "driver_name": "Alice Approved",
            "status": "completed",
            "activity_type": "recent",
            "start_loc": "Coralville",
            "end_loc": "University Heights",
            "final_cost": 18.50,
            "platform_fee": 1.85,
            "tax_amount": 1.30,
            "tip_amount": 2.50,
        },
        {
            "trip_id": 601,
            "driver_id": 1,
            "rider_name": "Rita Rider",
            "driver_name": "Alice Approved",
            "status": "completed",
            "activity_type": "recent",
            "start_loc": "Iowa City",
            "end_loc": "Coralville",
            "final_cost": 25.00,
            "platform_fee": 2.50,
            "tax_amount": 1.75,
            "tip_amount": 3.00,
        },
    ]


@pytest.fixture
def rider_reviews_seed():
    return [
        {
            "review_id": 901,
            "rating": 5,
            "rider_id": 101,
            "driver_id": 1,
            "rider_name": "Rita Rider",
            "driver_name": "Alice Approved",
            "comment": "Clean car and a very smooth trip.",
            "review_date": date(2026, 3, 22),
        },
        {
            "review_id": 902,
            "rating": 3,
            "rider_id": 102,
            "driver_id": 3,
            "rider_name": "Sam Student",
            "driver_name": "Carla Cruz",
            "comment": "Pickup took longer than expected.",
            "review_date": date(2026, 3, 18),
        },
    ]


@pytest.fixture
def driver_to_rider_reviews_seed():
    return [
        {
            "review_id": 801,
            "rating": 5,
            "driver_id": 1,
            "rider_id": 101,
            "driver_name": "Alice Approved",
            "rider_name": "Rita Rider",
            "comment": "Ready at pickup and easy to coordinate with.",
            "review_date": date(2026, 3, 21),
        },
        {
            "review_id": 802,
            "rating": 4,
            "driver_id": 3,
            "rider_id": 102,
            "driver_name": "Carla Cruz",
            "rider_name": "Sam Student",
            "comment": "Polite rider and on time.",
            "review_date": date(2026, 3, 17),
        },
    ]


@pytest.fixture
def fake_repo(
    drivers_seed,
    riders_seed,
    trips_seed,
    rider_reviews_seed,
    driver_to_rider_reviews_seed,
):
    return FakeAdminRepository(
        app_module,
        drivers_seed,
        riders_seed,
        trips_seed,
        rider_reviews_seed,
        driver_to_rider_reviews_seed,
    )


@pytest.fixture
def app(monkeypatch, fake_repo):
    monkeypatch.setattr(app_module, "ADMIN_USERNAME", "admin")
    monkeypatch.setattr(app_module, "ADMIN_PASSWORD", "ridematch123")
    monkeypatch.setattr(app_module, "ADMIN_FARE_SHARE", 0.25)
    monkeypatch.setattr(app_module, "DRIVER_FARE_SHARE", 0.75)
    monkeypatch.setattr(app_module, "DRIVER_PAYOUT_SCHEDULE", "weekly")
    monkeypatch.setattr(app_module, "ENV_PATH", PROJECT_ROOT / "tests" / ".env.test")

    app_module.app.config.update(
        TESTING=True,
        SECRET_KEY="test-secret-key",
    )
    app_module.app.config["ADMIN_REPOSITORY"] = fake_repo

    yield app_module.app

    app_module.app.config.pop("ADMIN_REPOSITORY", None)


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def logged_in_client(client):
    with client.session_transaction() as session:
        session["logged_in"] = True
        session["username"] = app_module.ADMIN_USERNAME
    return client


@pytest.fixture
def login(client):
    def _login(username="admin", password="ridematch123", follow_redirects=False):
        return client.post(
            "/login",
            data={
                "username": username,
                "password": password,
            },
            follow_redirects=follow_redirects,
        )

    return _login
