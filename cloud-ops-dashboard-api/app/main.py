"""Application entry point: creates the FastAPI app and connects the pieces."""
import logging
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.exc import OperationalError, SQLAlchemyError

from app.config import get_settings
from app.routers import health, incidents, metrics, services

settings = get_settings()

logging.basicConfig(
    level=settings.log_level.upper(),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Cloud Operations Dashboard API",
    description=(
        "Tracks services and incidents. All data is simulated application data; "
        "nothing here detects real AWS incidents."
    ),
    version="1.0.0",
    # Interactive docs can be switched off with ENABLE_DOCS=false.
    docs_url="/docs" if settings.enable_docs else None,
    redoc_url=None,
    openapi_url="/openapi.json" if settings.enable_docs else None,
)

app.include_router(health.router)
app.include_router(services.router)
app.include_router(incidents.router)
app.include_router(metrics.router)

# The dashboard UI: plain HTML/CSS/JS files, no build step, same origin as the API.
app.mount(
    "/ui",
    StaticFiles(directory=Path(__file__).parent / "static", html=True),
    name="ui",
)


@app.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse(url="/ui/")


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    if request.url.path.startswith("/ui"):
        # The UI only loads its own files: no inline scripts, no outside hosts,
        # and it cannot be embedded in another site's frame.
        # (Not applied to /docs, because Swagger UI needs scripts from a CDN.)
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
        )
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
    return response


@app.exception_handler(OperationalError)
async def database_unavailable_handler(request: Request, exc: OperationalError):
    # Log the error type only: the message can contain connection details.
    logger.error("Database connection problem: %s", type(exc).__name__)
    return JSONResponse(status_code=503, content={"detail": "Database unavailable"})


@app.exception_handler(SQLAlchemyError)
async def database_error_handler(request: Request, exc: SQLAlchemyError):
    logger.error("Database error: %s", type(exc).__name__)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})
