"""Incident management endpoints."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Incident, IncidentSeverity, IncidentStatus, Service, utcnow
from app.pagination import Pagination, pagination_params
from app.schemas import IncidentCreate, IncidentRead, IncidentUpdate, Page
from app.security import require_api_key

router = APIRouter(prefix="/incidents", tags=["incidents"])


def get_incident_or_404(db: Session, incident_id: int) -> Incident:
    incident = db.get(Incident, incident_id)
    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")
    return incident


def ensure_service_exists(db: Session, service_id: int) -> None:
    if db.get(Service, service_id) is None:
        raise HTTPException(status_code=404, detail="Service not found")


@router.post(
    "",
    response_model=IncidentRead,
    status_code=201,
    dependencies=[Depends(require_api_key)],
)
def create_incident(payload: IncidentCreate, db: Session = Depends(get_db)):
    ensure_service_exists(db, payload.service_id)
    incident = Incident(**payload.model_dump(), status=IncidentStatus.OPEN)
    db.add(incident)
    db.commit()
    db.refresh(incident)
    return incident


@router.get("", response_model=Page[IncidentRead])
def list_incidents(
    severity: IncidentSeverity | None = None,
    status: IncidentStatus | None = None,
    service_id: int | None = None,
    page: Pagination = Depends(pagination_params),
    db: Session = Depends(get_db),
):
    query = select(Incident)
    if severity is not None:
        query = query.where(Incident.severity == severity)
    if status is not None:
        query = query.where(Incident.status == status)
    if service_id is not None:
        query = query.where(Incident.service_id == service_id)

    total = db.scalar(select(func.count()).select_from(query.subquery()))
    items = db.scalars(
        query.order_by(Incident.id.desc()).limit(page.limit).offset(page.offset)
    ).all()
    return Page(items=items, total=total, limit=page.limit, offset=page.offset)


@router.get("/{incident_id}", response_model=IncidentRead)
def get_incident(incident_id: int, db: Session = Depends(get_db)):
    return get_incident_or_404(db, incident_id)


@router.patch(
    "/{incident_id}",
    response_model=IncidentRead,
    dependencies=[Depends(require_api_key)],
)
def update_incident(
    incident_id: int, payload: IncidentUpdate, db: Session = Depends(get_db)
):
    incident = get_incident_or_404(db, incident_id)
    changes = payload.model_dump(exclude_unset=True)

    if "service_id" in changes:
        ensure_service_exists(db, changes["service_id"])

    for field, value in changes.items():
        setattr(incident, field, value)

    # Keep resolved_at consistent with status.
    if "status" in changes:
        if incident.status == IncidentStatus.RESOLVED:
            if incident.resolved_at is None:
                incident.resolved_at = utcnow()
        else:
            incident.resolved_at = None

    db.commit()
    db.refresh(incident)
    return incident
