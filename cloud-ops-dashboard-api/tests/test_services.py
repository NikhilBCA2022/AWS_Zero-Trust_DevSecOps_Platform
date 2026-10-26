import pytest


def test_create_service(client, make_service):
    service = make_service(name="payments-api", description="Handles payments")
    assert service["id"] > 0
    assert service["status"] == "HEALTHY"  # default
    assert service["environment"] == "dev"
    assert service["created_at"] and service["updated_at"]


def test_duplicate_name_in_same_environment_returns_409(client, auth, make_service):
    make_service(name="payments-api", environment="dev")
    response = client.post(
        "/services", json={"name": "payments-api", "environment": "dev"}, headers=auth
    )
    assert response.status_code == 409


def test_same_name_in_different_environment_is_allowed(make_service):
    make_service(name="payments-api", environment="dev")
    make_service(name="payments-api", environment="prod")


@pytest.mark.parametrize(
    "body",
    [
        {"environment": "dev"},  # name missing
        {"name": "", "environment": "dev"},
        {"name": "bad name!", "environment": "dev"},
        {"name": "x" * 101, "environment": "dev"},
        {"name": "ok", "environment": "moon"},
        {"name": "ok", "environment": "dev", "status": "BROKEN"},
        {"name": "ok", "environment": "dev", "unknown_field": 1},
    ],
)
def test_invalid_input_returns_422(client, auth, body):
    assert client.post("/services", json=body, headers=auth).status_code == 422


def test_get_service(client, make_service):
    created = make_service()
    response = client.get(f"/services/{created['id']}")
    assert response.status_code == 200
    assert response.json()["name"] == "payments-api"


def test_get_missing_service_returns_404(client):
    assert client.get("/services/999").status_code == 404


def test_update_service_changes_only_sent_fields(client, auth, make_service):
    created = make_service(description="original")
    response = client.patch(
        f"/services/{created['id']}", json={"status": "DEGRADED"}, headers=auth
    )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "DEGRADED"
    assert body["description"] == "original"
    assert body["name"] == created["name"]


def test_update_can_clear_description(client, auth, make_service):
    created = make_service(description="original")
    response = client.patch(
        f"/services/{created['id']}", json={"description": None}, headers=auth
    )
    assert response.json()["description"] is None


@pytest.mark.parametrize("body", [{}, {"name": None}, {"status": None}])
def test_invalid_update_returns_422(client, auth, make_service, body):
    created = make_service()
    response = client.patch(f"/services/{created['id']}", json=body, headers=auth)
    assert response.status_code == 422


def test_update_to_duplicate_name_returns_409(client, auth, make_service):
    make_service(name="a")
    second = make_service(name="b")
    response = client.patch(f"/services/{second['id']}", json={"name": "a"}, headers=auth)
    assert response.status_code == 409


def test_update_missing_service_returns_404(client, auth):
    response = client.patch("/services/999", json={"status": "DOWN"}, headers=auth)
    assert response.status_code == 404


def test_delete_service(client, auth, make_service):
    created = make_service()
    assert client.delete(f"/services/{created['id']}", headers=auth).status_code == 204
    assert client.get(f"/services/{created['id']}").status_code == 404


def test_delete_missing_service_returns_404(client, auth):
    assert client.delete("/services/999", headers=auth).status_code == 404


def test_cannot_delete_service_with_incidents(client, auth, make_service, make_incident):
    service = make_service()
    make_incident(service["id"])
    response = client.delete(f"/services/{service['id']}", headers=auth)
    assert response.status_code == 409
    assert client.get(f"/services/{service['id']}").status_code == 200


def test_list_pagination_and_total(client, make_service):
    for i in range(5):
        make_service(name=f"svc-{i}")
    body = client.get("/services?limit=2&offset=2").json()
    assert body["total"] == 5
    assert body["limit"] == 2 and body["offset"] == 2
    assert [s["name"] for s in body["items"]] == ["svc-2", "svc-3"]


@pytest.mark.parametrize("query", ["limit=0", "limit=101", "offset=-1", "limit=abc"])
def test_invalid_pagination_returns_422(client, query):
    assert client.get(f"/services?{query}").status_code == 422


def test_list_filters(client, make_service):
    make_service(name="a", environment="dev")
    make_service(name="b", environment="prod", status="DOWN")
    assert client.get("/services?environment=prod").json()["total"] == 1
    assert client.get("/services?status=DOWN").json()["items"][0]["name"] == "b"
    assert client.get("/services?environment=dev&status=DOWN").json()["total"] == 0
