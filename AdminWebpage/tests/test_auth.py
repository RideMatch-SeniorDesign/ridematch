import pytest
import pyotp
import json

import app as app_module
from cryptography.fernet import Fernet
from werkzeug.security import check_password_hash, generate_password_hash


def test_login_page_renders_with_expected_fields(client):
    response = client.get("/login")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "RideMatch Admin" in body
    assert "Sign in" in body
    assert 'name="username"' in body
    assert 'name="password"' in body
    assert "Log In" in body
    assert "Forgot your password?" in body


def test_forgot_password_sends_reset_link_without_revealing_account(client, monkeypatch):
    accounts = {
        "ella": {
            "password_hash": generate_password_hash("ella-password"),
            "email": "ella@example.com",
        }
    }
    saved_request = {}
    sent_email = {}
    monkeypatch.setattr(app_module, "ADMIN_ACCOUNTS_JSON", json.dumps(accounts))
    monkeypatch.setattr(app_module, "ADMIN_PASSWORD_RESET_ENABLED", True)
    monkeypatch.setattr(
        app_module,
        "_create_admin_password_reset",
        lambda username, token_hash, expires_at: saved_request.update(
            {"username": username, "token_hash": token_hash, "expires_at": expires_at}
        )
        is None,
    )
    monkeypatch.setattr(
        app_module,
        "_send_admin_password_reset_email",
        lambda username, email, token: sent_email.update(
            {"username": username, "email": email, "token": token}
        )
        is None,
    )

    response = client.post("/forgot-password", data={"email": "ella@example.com"})

    assert response.status_code == 200
    assert "If that email belongs to an admin account" in response.get_data(as_text=True)
    assert saved_request["username"] == "ella"
    assert sent_email["email"] == "ella@example.com"
    assert saved_request["token_hash"] == app_module._hash_password_reset_token(sent_email["token"])


def test_reset_password_updates_hash_with_valid_one_time_token(client, monkeypatch):
    token = "valid-reset-token"
    received = {}
    monkeypatch.setattr(app_module, "_is_admin_password_reset_token_valid", lambda token_hash: True)
    monkeypatch.setattr(
        app_module,
        "_reset_admin_password_with_token",
        lambda token_hash, password_hash: received.update(
            {"token_hash": token_hash, "password_hash": password_hash}
        )
        is None,
    )

    response = client.post(
        f"/reset-password/{token}",
        data={"new_password": "new-secure-password", "confirm_password": "new-secure-password"},
        follow_redirects=False,
    )

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/login?reset=success")
    assert received["token_hash"] == app_module._hash_password_reset_token(token)
    assert check_password_hash(received["password_hash"], "new-secure-password")


def test_expired_reset_password_token_is_rejected(client, monkeypatch):
    monkeypatch.setattr(app_module, "_is_admin_password_reset_token_valid", lambda token_hash: False)

    response = client.get("/reset-password/expired-token")

    assert response.status_code == 400
    assert "invalid or has expired" in response.get_data(as_text=True)


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
