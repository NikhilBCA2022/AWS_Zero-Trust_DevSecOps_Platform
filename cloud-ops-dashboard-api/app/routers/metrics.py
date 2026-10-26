"""Application-level metrics, calculated from this app's own database records."""
from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Incident, IncidentSeverity, IncidentStatus, Service, ServiceStatus
from app.schemas import MetricsSummary

router = APIRouter(prefix="/metrics", tags=["metrics"])


def _count(db: Session, model, *conditions) -> int:
    return db.scalar(select(func.count(model.id)).where(*conditions)) or 0


@router.get("/summary", response_model=MetricsSummary)
def metrics_summary(db: Session = Depends(get_db)):
    unresolved = Incident.status != IncidentStatus.RESOLVED
    return MetricsSummary(
        total_services=_count(db, Service),
        healthy_services=_count(db, Service, Service.status == ServiceStatus.HEALTHY),
        # "Unhealthy" means DEGRADED or DOWN.
        unhealthy_services=_count(db, Service, Service.status != ServiceStatus.HEALTHY),
        # "Open" means not yet resolved (OPEN or INVESTIGATING).
        open_incidents=_count(db, Incident, unresolved),
        critical_open_incidents=_count(
            db, Incident, unresolved, Incident.severity == IncidentSeverity.CRITICAL
        ),
        resolved_incidents=_count(
            db, Incident, Incident.status == IncidentStatus.RESOLVED
        ),
    )
