import pytest
import pyotp
import json

import app as app_module
from cryptography.fernet import Fernet
from werkzeug.security import generate_password_hash


def test_login_page_renders_with_expected_fields(client):
    response = client.get("/login")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "RideMatch Admin" in body
    assert "Sign in" in body
    assert 'name="username"' in body
    assert 'name="password"' in body
    assert "Log In" in body


def test_login_with_bad_credentials_shows_error(client):
    response = client.post(
        "/login",
        data={"username": "admin", "password": "wrong-password"},
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Invalid username or password." in body


def test_login_with_good_credentials_sets_session_and_redirects(client, login):
    response = login(follow_redirects=False)

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/home")

    with client.session_transaction() as session:
        assert session["logged_in"] is True
        assert session["username"] == "admin"


def test_login_requires_totp_when_configured(client, monkeypatch):
    secret = pyotp.random_base32()
    monkeypatch.setattr(app_module, "ADMIN_TOTP_SECRET", secret)

    response = client.post(
        "/login",
        data={"username": "admin", "password": "ridematch123"},
        follow_redirects=False,
    )

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/verify-2fa")
    with client.session_transaction() as session:
        assert "logged_in" not in session
        assert session["pending_2fa_username"] == "admin"

    response = client.post(
        "/verify-2fa",
        data={"code": pyotp.TOTP(secret).now()},
        follow_redirects=False,
    )

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/home")
    with client.session_transaction() as session:
        assert session["logged_in"] is True


def test_each_configured_admin_uses_their_own_totp_secret(client, monkeypatch):
    secrets = {name: pyotp.random_base32() for name in ("owner", "andre", "ella")}
    accounts = {
        name: {
            "password_hash": generate_password_hash(f"{name}-password"),
            "totp_secret": secret,
        }
        for name, secret in secrets.items()
    }
    monkeypatch.setattr(app_module, "ADMIN_ACCOUNTS_JSON", json.dumps(accounts))

    response = client.post(
        "/login",
        data={"username": "andre", "password": "andre-password"},
        follow_redirects=False,
    )

    assert response.headers["Location"].endswith("/verify-2fa")
    response = client.post(
        "/verify-2fa",
        data={"code": pyotp.TOTP(secrets["andre"]).now()},
        follow_redirects=False,
    )

    assert response.headers["Location"].endswith("/home")
    with client.session_transaction() as session:
        assert session["username"] == "andre"


def test_multi_admin_password_changes_are_managed_by_configuration(logged_in_client, monkeypatch):
    monkeypatch.setattr(app_module, "ADMIN_ACCOUNTS_JSON", '{"owner": {"password_hash": "hash", "totp_secret": "secret"}}')

    response = logged_in_client.post(
        "/settings",
        data={
            "form_name": "password",
            "current_password": "old-password",
            "new_password": "new-password",
            "confirm_password": "new-password",
        },
        follow_redirects=True,
    )

    assert "Admin passwords are managed through the configured admin accounts." in response.get_data(as_text=True)


def test_admin_can_enroll_totp_through_the_website(client, monkeypatch):
    saved_secret = {}
    accounts = {"ella": {"password_hash": generate_password_hash("ella-password")}}
    monkeypatch.setattr(app_module, "ADMIN_ACCOUNTS_JSON", json.dumps(accounts))
    monkeypatch.setattr(app_module, "ADMIN_MFA_ENCRYPTION_KEY", Fernet.generate_key().decode())
    monkeypatch.setattr(app_module, "ADMIN_2FA_ENROLLMENT_OPEN", True)
    monkeypatch.setattr(app_module, "_stored_totp_secret", lambda username, account: None)
    monkeypatch.setattr(
        app_module,
        "_save_totp_secret",
        lambda username, secret: saved_secret.update({"username": username, "secret": secret}) is None,
    )

    response = client.post(
        "/login",
        data={"username": "ella", "password": "ella-password"},
        follow_redirects=False,
    )

    assert response.headers["Location"].endswith("/setup-2fa")
    with client.session_transaction() as session:
        secret = session["pending_2fa_secret"] if "pending_2fa_secret" in session else None

    response = client.get("/setup-2fa")
    assert response.status_code == 200
    with client.session_transaction() as session:
        secret = session["pending_2fa_secret"]

    response = client.post(
        "/setup-2fa",
        data={"code": pyotp.TOTP(secret).now()},
        follow_redirects=False,
    )

    assert response.headers["Location"].endswith("/home")
    assert saved_secret == {"username": "ella", "secret": secret}


@pytest.mark.parametrize(
    "path",
    [
        "/home",
        "/drivers",
        "/drivers/detail/1",
        "/riders",
        "/analytics",
        "/settings",
    ],
)
def test_protected_pages_redirect_to_login_when_logged_out(client, path):
    response = client.get(path, follow_redirects=False)

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/login")
