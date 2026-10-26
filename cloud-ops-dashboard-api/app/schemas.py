"""Request and response shapes (Pydantic). This is where input validation lives."""
from datetime import datetime
from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models import (
    IncidentSeverity,
    IncidentStatus,
    ServiceEnvironment,
    ServiceStatus,
)

# Letters, digits, dot, underscore, hyphen; must start with a letter or digit.
NAME_PATTERN = r"^[A-Za-z0-9][A-Za-z0-9._-]*$"

T = TypeVar("T")


class RequestModel(BaseModel):
    # Trim spaces, and reject unknown fields instead of silently ignoring them.
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")


def _check_partial_update(model: BaseModel, non_nullable: tuple[str, ...]):
    """Shared rules for PATCH bodies."""
    if not model.model_fields_set:
        raise ValueError("At least one field must be provided")
    for field in non_nullable:
        if field in model.model_fields_set and getattr(model, field) is None:
            raise ValueError(f"{field} cannot be null")
    return model


# ---------- services ----------
class ServiceCreate(RequestModel):
    name: str = Field(min_length=1, max_length=100, pattern=NAME_PATTERN)
    environment: ServiceEnvironment
    status: ServiceStatus = ServiceStatus.HEALTHY
    description: str | None = Field(default=None, max_length=500)


class ServiceUpdate(RequestModel):
    name: str | None = Field(
        default=None, min_length=1, max_length=100, pattern=NAME_PATTERN
    )
    environment: ServiceEnvironment | None = None
    status: ServiceStatus | None = None
    description: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def check_update(self):
        return _check_partial_update(self, ("name", "environment", "status"))


class ServiceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    environment: ServiceEnvironment
    status: ServiceStatus
    description: str | None
    created_at: datetime
    updated_at: datetime


# ---------- incidents ----------
class IncidentCreate(RequestModel):
    # New incidents always start as OPEN, so status is not accepted here.
    title: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    severity: IncidentSeverity
    service_id: int = Field(gt=0)


class IncidentUpdate(RequestModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    severity: IncidentSeverity | None = None
    status: IncidentStatus | None = None
    service_id: int | None = Field(default=None, gt=0)

    @model_validator(mode="after")
    def check_update(self):
        return _check_partial_update(
            self, ("title", "severity", "status", "service_id")
        )


class IncidentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    severity: IncidentSeverity
    status: IncidentStatus
    service_id: int
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None


# ---------- shared ----------
class Page(BaseModel, Generic[T]):
    """Every list endpoint returns this same predictable shape."""

    items: list[T]
    total: int
    limit: int
    offset: int


class MetricsSummary(BaseModel):
    total_services: int
    healthy_services: int
    unhealthy_services: int
    open_incidents: int
    critical_open_incidents: int
    resolved_incidents: int
    source: str = "application_records"
    note: str = (
        "Calculated from this application's own database records. "
        "These are not AWS infrastructure metrics."
    )
