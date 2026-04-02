def test_analytics_page_renders_tabs_and_sections(logged_in_client):
    response = logged_in_client.get("/analytics")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Analytics Dashboard" in body
    assert "Analytics Workflow" in body
    assert "Dashboard" in body
    assert "Budget/Income" in body
    assert "Reviews" in body
    assert "Trips" in body
    assert "Income Split" in body
    assert "Ongoing Trips" in body
