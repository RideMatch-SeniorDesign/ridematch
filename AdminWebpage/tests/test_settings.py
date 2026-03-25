def test_platform_settings_page_renders_forms(logged_in_client):
    response = logged_in_client.get("/settings")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Platform Settings" in body
    assert "Change Password" in body
    assert "Budget Settings" in body
    assert "Save Budget Settings" in body


def test_budget_settings_post_persists_through_repository(logged_in_client, fake_repo):
    response = logged_in_client.post(
        "/settings",
        data={
            "form_name": "budget",
            "admin_fare_share_pct": "30",
            "driver_payout_schedule": "biweekly",
        },
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Budget settings updated successfully." in body
    assert "30%" in body
    assert "Biweekly" in body
    assert fake_repo.budget_updates == [(30, "biweekly")]


def test_budget_settings_validation_rejects_out_of_range_values(logged_in_client, fake_repo):
    response = logged_in_client.post(
        "/settings",
        data={
            "form_name": "budget",
            "admin_fare_share_pct": "101",
            "driver_payout_schedule": "weekly",
        },
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Admin take percentage must be between 0 and 100." in body
    assert fake_repo.budget_updates == []


def test_change_password_rejects_confirmation_mismatch(logged_in_client, fake_repo):
    response = logged_in_client.post(
        "/settings",
        data={
            "form_name": "password",
            "current_password": "ridematch123",
            "new_password": "newsecurepass",
            "confirm_password": "differentpass",
        },
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "New password and confirmation do not match." in body
    assert fake_repo.password_updates == []


def test_change_password_rejects_wrong_current_password(logged_in_client, fake_repo):
    response = logged_in_client.post(
        "/settings",
        data={
            "form_name": "password",
            "current_password": "not-the-old-password",
            "new_password": "newsecurepass",
            "confirm_password": "newsecurepass",
        },
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Current password is incorrect." in body
    assert fake_repo.password_updates == []


def test_change_password_success_calls_repository(logged_in_client, fake_repo):
    response = logged_in_client.post(
        "/settings",
        data={
            "form_name": "password",
            "current_password": "ridematch123",
            "new_password": "newsecurepass",
            "confirm_password": "newsecurepass",
        },
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Password updated successfully." in body
    assert fake_repo.password_updates == ["newsecurepass"]
