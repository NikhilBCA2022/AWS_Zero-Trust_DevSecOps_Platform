import pytest


def test_create_incident_starts_open(client, make_service, make_incident):
    service = make_service()
    incident = make_incident(service["id"], description="Slow responses")
    assert incident["status"] == "OPEN"
    assert incident["severity"] == "HIGH"
    assert incident["service_id"] == service["id"]
    assert incident["resolved_at"] is None


def test_create_incident_for_missing_service_returns_404(client, auth):
    response = client.post(
        "/incidents",
        json={"title": "x", "severity": "LOW", "service_id": 999},
        headers=auth,
    )
    assert response.status_code == 404


@pytest.mark.parametrize(
    "body",
    [
        {"severity": "LOW", "service_id": 1},  # title missing
        {"title": "x", "severity": "LOW"},  # service_id missing
        {"title": "x", "severity": "URGENT", "service_id": 1},
        {"title": "x", "severity": "LOW", "service_id": 0},
        {"title": "x", "severity": "LOW", "service_id": 1, "status": "RESOLVED"},
    ],
)
def test_invalid_incident_returns_422(client, auth, make_service, body):
    make_service()
    assert client.post("/incidents", json=body, headers=auth).status_code == 422


def test_get_incident(client, make_service, make_incident):
    incident = make_incident(make_service()["id"])
    assert client.get(f"/incidents/{incident['id']}").json()["title"] == "High latency"
    assert client.get("/incidents/999").status_code == 404


def test_resolving_sets_resolved_at_and_reopening_clears_it(
    client, auth, make_service, make_incident
):
    incident = make_incident(make_service()["id"])
    url = f"/incidents/{incident['id']}"

    resolved = client.patch(url, json={"status": "RESOLVED"}, headers=auth).json()
    assert resolved["status"] == "RESOLVED"
    assert resolved["resolved_at"] is not None

    reopened = client.patch(url, json={"status": "INVESTIGATING"}, headers=auth).json()
    assert reopened["resolved_at"] is None


def test_update_other_fields_and_reassign_service(
    client, auth, make_service, make_incident
):
    first = make_service(name="a")
    second = make_service(name="b")
    incident = make_incident(first["id"])
    response = client.patch(
        f"/incidents/{incident['id']}",
        json={"severity": "CRITICAL", "service_id": second["id"]},
        headers=auth,
    )
    body = response.json()
    assert body["severity"] == "CRITICAL"
    assert body["service_id"] == second["id"]


def test_update_to_missing_service_returns_404(client, auth, make_service, make_incident):
    incident = make_incident(make_service()["id"])
    response = client.patch(
        f"/incidents/{incident['id']}", json={"service_id": 999}, headers=auth
    )
    assert response.status_code == 404


@pytest.mark.parametrize("body", [{}, {"title": None}, {"status": "DONE"}])
def test_invalid_incident_update_returns_422(client, auth, make_service, make_incident, body):
    incident = make_incident(make_service()["id"])
    assert client.patch(f"/incidents/{incident['id']}", json=body, headers=auth).status_code == 422


def test_update_missing_incident_returns_404(client, auth):
    assert client.patch("/incidents/999", json={"status": "RESOLVED"}, headers=auth).status_code == 404


def test_filters_and_pagination(client, auth, make_service, make_incident):
    a = make_service(name="a")
    b = make_service(name="b")
    make_incident(a["id"], title="1", severity="LOW")
    second = make_incident(a["id"], title="2", severity="CRITICAL")
    make_incident(b["id"], title="3", severity="CRITICAL")
    client.patch(f"/incidents/{second['id']}", json={"status": "RESOLVED"}, headers=auth)

    assert client.get("/incidents").json()["total"] == 3
    assert client.get("/incidents?severity=CRITICAL").json()["total"] == 2
    assert client.get("/incidents?status=RESOLVED").json()["total"] == 1
    assert client.get(f"/incidents?service_id={b['id']}").json()["total"] == 1
    combined = client.get(f"/incidents?severity=CRITICAL&service_id={a['id']}").json()
    assert [i["title"] for i in combined["items"]] == ["2"]

    page = client.get("/incidents?limit=1&offset=0").json()
    assert page["items"][0]["title"] == "3"  # newest first
    assert page["total"] == 3


@pytest.mark.parametrize("query", ["severity=URGENT", "status=DONE", "limit=0"])
def test_invalid_filters_return_422(client, query):
    assert client.get(f"/incidents?{query}").status_code == 422
