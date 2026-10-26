"""Database tables (SQLAlchemy models) and the allowed values for choice fields."""
import enum
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ServiceEnvironment(str, enum.Enum):
    DEV = "dev"
    STAGING = "staging"
    PROD = "prod"


class ServiceStatus(str, enum.Enum):
    HEALTHY = "HEALTHY"
    DEGRADED = "DEGRADED"
    DOWN = "DOWN"


class IncidentSeverity(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class IncidentStatus(str, enum.Enum):
    OPEN = "OPEN"
    INVESTIGATING = "INVESTIGATING"
    RESOLVED = "RESOLVED"


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def enum_column(enum_class: type[enum.Enum]) -> Enum:
    # Stored as plain text (VARCHAR) so migrations stay simple on any database.
    return Enum(
        enum_class,
        native_enum=False,
        length=20,
        values_callable=lambda members: [m.value for m in members],
    )


class Service(Base):
    __tablename__ = "services"
    # Same name is allowed in different environments, but not twice in one.
    __table_args__ = (
        UniqueConstraint("name", "environment", name="uq_services_name_environment"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    environment: Mapped[ServiceEnvironment] = mapped_column(
        enum_column(ServiceEnvironment)
    )
    status: Mapped[ServiceStatus] = mapped_column(
        enum_column(ServiceStatus), default=ServiceStatus.HEALTHY
    )
    description: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    incidents: Mapped[list["Incident"]] = relationship(back_populates="service")


class Incident(Base):
    __tablename__ = "incidents"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(String(2000))
    severity: Mapped[IncidentSeverity] = mapped_column(
        enum_column(IncidentSeverity), index=True
    )
    status: Mapped[IncidentStatus] = mapped_column(
        enum_column(IncidentStatus), default=IncidentStatus.OPEN, index=True
    )
    # RESTRICT: a service that still has incidents cannot be deleted.
    service_id: Mapped[int] = mapped_column(
        ForeignKey("services.id", ondelete="RESTRICT"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    service: Mapped[Service] = relationship(back_populates="incidents")
