"""Service inventory endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Incident, Service, ServiceEnvironment, ServiceStatus
from app.pagination import Pagination, pagination_params
from app.schemas import Page, ServiceCreate, ServiceRead, ServiceUpdate
from app.security import require_api_key

router = APIRouter(prefix="/services", tags=["services"])

DUPLICATE_MESSAGE = "A service with this name already exists in this environment"


def get_service_or_404(db: Session, service_id: int) -> Service:
    service = db.get(Service, service_id)
    if service is None:
        raise HTTPException(status_code=404, detail="Service not found")
    return service


@router.post(
    "",
    response_model=ServiceRead,
    status_code=201,
    dependencies=[Depends(require_api_key)],
)
def create_service(payload: ServiceCreate, db: Session = Depends(get_db)):
    service = Service(**payload.model_dump())
    db.add(service)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail=DUPLICATE_MESSAGE) from None
    db.refresh(service)
    return service


@router.get("", response_model=Page[ServiceRead])
def list_services(
    environment: ServiceEnvironment | None = None,
    status: ServiceStatus | None = None,
    page: Pagination = Depends(pagination_params),
    db: Session = Depends(get_db),
):
    query = select(Service)
    if environment is not None:
        query = query.where(Service.environment == environment)
    if status is not None:
        query = query.where(Service.status == status)

    total = db.scalar(select(func.count()).select_from(query.subquery()))
    items = db.scalars(
        query.order_by(Service.id).limit(page.limit).offset(page.offset)
    ).all()
    return Page(items=items, total=total, limit=page.limit, offset=page.offset)


@router.get("/{service_id}", response_model=ServiceRead)
def get_service(service_id: int, db: Session = Depends(get_db)):
    return get_service_or_404(db, service_id)


@router.patch(
    "/{service_id}",
    response_model=ServiceRead,
    dependencies=[Depends(require_api_key)],
)
def update_service(
    service_id: int, payload: ServiceUpdate, db: Session = Depends(get_db)
):
    service = get_service_or_404(db, service_id)
    # exclude_unset: only change the fields the client actually sent.
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(service, field, value)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail=DUPLICATE_MESSAGE) from None
    db.refresh(service)
    return service


@router.delete(
    "/{service_id}", status_code=204, dependencies=[Depends(require_api_key)]
)
def delete_service(service_id: int, db: Session = Depends(get_db)):
    service = get_service_or_404(db, service_id)
    has_incidents = db.scalar(
        select(func.count(Incident.id)).where(Incident.service_id == service_id)
    )
    if has_incidents:
        raise HTTPException(
            status_code=409, detail="Cannot delete a service that has incidents"
        )
    db.delete(service)
    db.commit()
    return Response(status_code=204)
