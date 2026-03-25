def test_dashboard_page_renders_key_sections(logged_in_client):
    response = logged_in_client.get("/home")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Operations Dashboard" in body
    assert "Pending Applications" in body
    assert "Gross Bookings" in body
    assert "Recent Reviews" in body
    assert "Open Verification Queue" in body
