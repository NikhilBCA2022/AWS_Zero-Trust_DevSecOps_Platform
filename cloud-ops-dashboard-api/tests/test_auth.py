import pytest
from pydantic import ValidationError

from app.config import Settings, get_settings
from app.main import app
from tests.conftest import TEST_API_KEY

BODY = {"name": "svc", "environment": "dev"}


def test_write_without_key_is_rejected(client):
    response = client.post("/services", json=BODY)
    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid or missing API key"}


def test_write_with_wrong_key_is_rejected_and_key_not_echoed(client):
    wrong = "wrong-key-0123456789-abcdefghij"
    response = client.post("/services", json=BODY, headers={"X-API-Key": wrong})
    assert response.status_code == 401
    assert wrong not in response.text
    assert TEST_API_KEY not in response.text


def test_write_with_valid_key_works(client, auth):
    assert client.post("/services", json=BODY, headers=auth).status_code == 201


@pytest.mark.parametrize(
    "method,path",
    [("patch", "/services/1"), ("delete", "/services/1"), ("patch", "/incidents/1")],
)
def test_all_write_endpoints_require_key(client, method, path):
    response = client.request(method.upper(), path, json={"status": "DOWN"})
    assert response.status_code == 401


def test_read_endpoints_do_not_require_key(client):
    assert client.get("/services").status_code == 200
    assert client.get("/incidents").status_code == 200
    assert client.get("/metrics/summary").status_code == 200


def test_writes_are_refused_when_no_key_is_configured(client):
    app.dependency_overrides[get_settings] = lambda: Settings(_env_file=None)
    response = client.post("/services", json=BODY, headers={"X-API-Key": "anything"})
    assert response.status_code == 503


def test_multiple_keys_supported_for_rotation(client):
    old, new = "old-key-0123456789-abcdefghijk", "new-key-0123456789-abcdefghijk"
    app.dependency_overrides[get_settings] = lambda: Settings(
        _env_file=None, api_keys=f"{old},{new}"
    )
    for key in (old, new):
        response = client.post(
            "/services", json={"name": f"s-{key[:3]}", "environment": "dev"},
            headers={"X-API-Key": key},
        )
        assert response.status_code == 201


def test_short_api_key_is_rejected_at_startup_without_printing_it():
    with pytest.raises(ValidationError) as error:
        Settings(_env_file=None, api_keys="tooshort")
    assert "tooshort" not in str(error.value)
