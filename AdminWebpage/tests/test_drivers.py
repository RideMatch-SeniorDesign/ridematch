def test_driver_workflow_page_renders_tabs_filters_and_table(logged_in_client):
    response = logged_in_client.get("/drivers")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Driver Management Hub" in body
    assert "Driver Workflow" in body
    assert "All Drivers" in body
    assert "Verifications" in body
    assert "Apply Filters" in body
    assert "Details" in body
    assert "/drivers/detail/1" in body


def test_driver_detail_page_renders_seeded_driver(logged_in_client):
    response = logged_in_client.get("/drivers/detail/2")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Ben Benton" in body
    assert "Basic Information" in body
    assert "License Verification" in body
    assert "Vehicle Information" in body
    assert "Verification Actions" in body
    assert "Approve Driver" in body


def test_driver_filters_return_only_matching_rows(logged_in_client):
    response = logged_in_client.get(
        "/drivers",
        query_string={
            "tab": "all",
            "driver_query": "alice.approved@example.com",
            "driver_status": "approved",
            "driving_since_before": "2024-12-31",
            "driver_rating_min": "4.8",
            "driver_rating_max": "5.0",
            "driver_rides_min": "100",
            "driver_rides_max": "130",
        },
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Alice Approved" in body
    assert "alice.approved@example.com" in body
    assert "Ben Benton" not in body
    assert "Carla Cruz" not in body
    assert "Devin Doyle" not in body


def test_driver_reset_view_returns_unfiltered_results(logged_in_client):
    filtered_response = logged_in_client.get(
        "/drivers",
        query_string={"tab": "all", "driver_status": "pending"},
    )
    filtered_body = filtered_response.get_data(as_text=True)

    assert "Ben Benton" in filtered_body
    assert "Alice Approved" not in filtered_body

    reset_response = logged_in_client.get("/drivers", query_string={"tab": "all"})
    reset_body = reset_response.get_data(as_text=True)

    assert reset_response.status_code == 200
    assert "Alice Approved" in reset_body
    assert "Ben Benton" in reset_body
    assert "Carla Cruz" in reset_body
    assert "Devin Doyle" in reset_body


def test_approve_verification_updates_status_and_queue(logged_in_client, fake_repo):
    response = logged_in_client.post(
        "/drivers/verify/2",
        data={"action": "approve"},
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Driver application approved." in body
    assert "Ben Benton" not in body
    assert "Devin Doyle" in body
    assert "1 applicants" in body
    assert fake_repo.fetch_driver_detail(2)["status"] == "approved"

    all_drivers_response = logged_in_client.get("/drivers", query_string={"tab": "all"})
    all_drivers_body = all_drivers_response.get_data(as_text=True)

    assert "Ben Benton" in all_drivers_body
    assert "2025-03-01" in all_drivers_body


def test_deny_verification_updates_status_and_queue(logged_in_client, fake_repo):
    response = logged_in_client.post(
        "/drivers/verify/4",
        data={"action": "deny"},
        follow_redirects=True,
    )
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Driver application denied." in body
    assert "Devin Doyle" not in body
    assert "Ben Benton" in body
    assert "1 applicants" in body
    assert fake_repo.fetch_driver_detail(4)["status"] == "denied"
