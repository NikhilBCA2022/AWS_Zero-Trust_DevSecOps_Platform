from sqlalchemy.exc import OperationalError

from app.database import get_db
from app.main import app


def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_when_database_works(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


class BrokenSession:
    """Pretends the database is down. The message contains a fake secret on purpose."""

    def execute(self, *args, **kwargs):
        raise OperationalError("SELECT 1", {}, Exception("password=hunter2 host=db.internal"))


def test_ready_returns_503_without_leaking_details(client):
    app.dependency_overrides[get_db] = lambda: BrokenSession()
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.json() == {"status": "not_ready"}
    assert "hunter2" not in response.text
    assert "db.internal" not in response.text


def test_database_outage_on_normal_endpoint_returns_generic_503(client):
    class Down:
        def scalar(self, *a, **k):
            raise OperationalError("x", {}, Exception("password=hunter2"))

    app.dependency_overrides[get_db] = lambda: Down()
    response = client.get("/metrics/summary")
    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}
    assert "hunter2" not in response.text
