def test_rider_management_page_renders_tabs_filters_and_table(logged_in_client):
    response = logged_in_client.get("/riders")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert "Rider Management Hub" in body
    assert "Rider Workflow" in body
    assert "All Riders" in body
    assert "Recent Activity" in body
    assert "Apply Filters" in body
    assert "Rita Rider" in body
