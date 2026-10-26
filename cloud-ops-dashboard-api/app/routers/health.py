"""Liveness (/health) and readiness (/ready) endpoints, used by Kubernetes probes."""
import logging

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

logger = logging.getLogger(__name__)
router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict:
    """Liveness: the process is running. Deliberately does not touch the database."""
    return {"status": "ok"}


@router.get("/ready")
def ready(db: Session = Depends(get_db)):
    """Readiness: the app can reach PostgreSQL. Responses never include details."""
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:
        # Log only the error type, never the message, to avoid leaking connection details.
        logger.error("Readiness check failed: %s", type(exc).__name__)
        return JSONResponse(status_code=503, content={"status": "not_ready"})
    return {"status": "ready"}
