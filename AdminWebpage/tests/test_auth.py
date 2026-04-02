import pytest


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
