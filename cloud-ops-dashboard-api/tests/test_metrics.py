def test_metrics_with_no_data(client):
    body = client.get("/metrics/summary").json()
    assert body["total_services"] == 0
    assert body["open_incidents"] == 0
    assert body["source"] == "application_records"
    assert "not AWS" in body["note"]


def test_metrics_summary_counts(client, auth, make_service, make_incident):
    healthy = make_service(name="a")
    degraded = make_service(name="b", status="DEGRADED")
    make_service(name="c", status="DOWN")

    make_incident(healthy["id"], severity="CRITICAL")  # open + critical
    investigating = make_incident(degraded["id"], severity="CRITICAL")
    client.patch(
        f"/incidents/{investigating['id']}", json={"status": "INVESTIGATING"}, headers=auth
    )  # still open + critical
    resolved = make_incident(healthy["id"], severity="CRITICAL")
    client.patch(
        f"/incidents/{resolved['id']}", json={"status": "RESOLVED"}, headers=auth
    )
    make_incident(healthy["id"], severity="LOW")  # open, not critical

    body = client.get("/metrics/summary").json()
    assert body["total_services"] == 3
    assert body["healthy_services"] == 1
    assert body["unhealthy_services"] == 2
    assert body["open_incidents"] == 3
    assert body["critical_open_incidents"] == 2
    assert body["resolved_incidents"] == 1
