# Cloud Operations Dashboard API

A small FastAPI service that tracks **services** and **incidents** and reports
summary metrics. It is built to be easy to read and explain.

> All data is simulated application data stored in this app's own database.
> It does **not** detect real AWS incidents, and `/metrics/summary` is **not**
> AWS infrastructure telemetry.

**Stack:** Python 3.12, FastAPI, SQLAlchemy 2, Pydantic 2, PostgreSQL, Alembic, pytest.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/` | none | Redirects to the dashboard at `/ui/` |
| GET | `/health` | none | Liveness. Never touches the database. |
| GET | `/ready` | none | Readiness. Runs `SELECT 1`; returns 503 `{"status":"not_ready"}` on failure. |
| POST | `/services` | key | Create a service (201; 409 if name exists in that environment) |
| GET | `/services` | none | List. Filters: `environment`, `status`. Paging: `limit`, `offset` |
| GET | `/services/{id}` | none | Retrieve one (404 if missing) |
| PATCH | `/services/{id}` | key | Partial update (only sent fields change) |
| DELETE | `/services/{id}` | key | Delete (204; 409 if it still has incidents) |
| POST | `/incidents` | key | Create (always starts `OPEN`; 404 if service missing) |
| GET | `/incidents` | none | List. Filters: `severity`, `status`, `service_id`. Paging as above |
| GET | `/incidents/{id}` | none | Retrieve one |
| PATCH | `/incidents/{id}` | key | Update title, description, severity, status, service |
| GET | `/metrics/summary` | none | Counts calculated from the app's records |

**Allowed values** (exact spelling, case-sensitive):
environment `dev | staging | prod`; service status `HEALTHY | DEGRADED | DOWN`;
severity `LOW | MEDIUM | HIGH | CRITICAL`; incident status `OPEN | INVESTIGATING | RESOLVED`.

**List responses** always look like `{"items": [...], "total": 42, "limit": 20, "offset": 0}`.
`limit` is 1 to 100 (default 20); `offset` is 0 or more.

**Metric definitions:** *unhealthy* = service status `DEGRADED` or `DOWN`;
*open* incident = not `RESOLVED` (so `OPEN` or `INVESTIGATING`).

Interactive API docs are at `/docs` (disable with `ENABLE_DOCS=false`).

## Dashboard UI

Open **`/ui/`** (the root `/` redirects there). It is plain HTML, CSS and JavaScript in
`app/static/`, served by the same FastAPI app: no framework, no build step, no extra
dependencies, no CORS configuration.

- Summary cards, service and incident tables with filters and paging.
- Forms to add services and report incidents; dropdowns to change status; delete button.
- Writes need the API key: paste it into the field at the top. It is kept **in memory only**
  (not in browser storage, cookies, or the URL), so reloading the page clears it.
- The UI calls the same public API as `curl` or `/docs`; it has no special access.

UI security choices:
- Data from the API is inserted only as text (`textContent`), never as HTML, so a
  description such as `<script>...</script>` is shown literally and does not run.
  A test fails if `innerHTML` or similar is ever added.
- `/ui` responses carry a strict Content-Security-Policy (`default-src 'self'`, no inline
  scripts, no outside hosts), `X-Frame-Options: DENY`, and `Referrer-Policy: no-referrer`.
  The policy is not applied to `/docs`, because Swagger UI loads scripts from a CDN.

## Run it locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

# A throwaway local PostgreSQL (needs Docker; use any Postgres you like)
docker run -d --name cloudops-db -p 5432:5432 \
  -e POSTGRES_USER=cloudops -e POSTGRES_PASSWORD=change-me-local-only \
  -e POSTGRES_DB=cloudops postgres:16

cp .env.example .env
# edit .env: set API_KEYS, e.g. python -c "import secrets; print(secrets.token_urlsafe(32))"

alembic upgrade head                 # create the tables (a deliberate, separate step)
uvicorn app.main:app --reload        # http://127.0.0.1:8000/docs
```

Try it:

```bash
curl -X POST localhost:8000/services \
  -H "X-API-Key: $YOUR_KEY" -H "Content-Type: application/json" \
  -d '{"name":"payments-api","environment":"dev"}'
curl "localhost:8000/services?environment=dev"
```

## Tests

```bash
pytest                         # 74 tests, no database server needed (in-memory SQLite)
pytest --cov=app --cov-report=term-missing
ruff check .                   # lint
bandit -r app                  # security lint
```

The tests use SQLite so they run anywhere. SQLite and PostgreSQL differ in places,
so also run the migration and a few requests against real PostgreSQL (see above).

## Configuration (environment variables)

| Variable | Meaning |
|---|---|
| `DB_HOST`, `DB_PORT` (5432), `DB_NAME`, `DB_USER`, `DB_PASSWORD` | PostgreSQL connection parts |
| `DATABASE_URL` | Alternative: one full SQLAlchemy URL (wins if set) |
| `API_KEYS` | Comma-separated keys for write endpoints, each 24+ characters |
| `LOG_LEVEL` | Default `INFO` |
| `ENABLE_DOCS` | Default `true`; set `false` to hide `/docs` and `/openapi.json` |
| `APP_ENV` | Free-text label, default `dev` |

Nothing is hardcoded and the app reads no cloud credentials. Where the values come from
(Kubernetes Secret, Secrets Manager, a `.env` file) is up to your deployment.

## How it is organised

```
app/
  main.py        creates the app, registers routers and error handlers
  config.py      settings from environment variables
  database.py    engine + one session per request
  models.py      database tables (Service, Incident) and allowed values
  schemas.py     request/response shapes and input validation
  security.py    API-key check for write endpoints
  pagination.py  limit/offset parameters
  routers/       health.py, services.py, incidents.py, metrics.py
  static/        dashboard UI: index.html, style.css, app.js
alembic/         versioned database migrations
tests/           pytest suite
```

Request flow: **router** receives the request, **schemas** validate it, the router uses a
**model** through the **session**, and the result is returned as a **schema**.

## Security design (and why)

- **API key on writes only.** Reads, health and metrics are open on purpose; restrict them
  at the network layer (ingress, NetworkPolicy, WAF) as your platform requires.
- **Fails closed.** If no key is configured, writes return 503 instead of being open.
- **Constant-time comparison** (`secrets.compare_digest`) so keys cannot be guessed
  character by character.
- **Key rotation:** `API_KEYS=new,old`, deploy, move clients to `new`, then drop `old`.
- **No secret in logs or errors.** The 401 message is generic, the key is never logged,
  validation errors hide input values for settings, and database errors are logged by
  type only (their messages can contain connection details).
- **Safe health endpoints.** `/ready` returns only `ready` or `not_ready`.
- **No raw SQL exposed.** All queries go through SQLAlchemy with bound parameters,
  and no response ever contains SQL.
- **No schema creation at runtime.** Tables are created only by `alembic upgrade head`.
  The app never creates, resets, or deletes a database on startup.
- **Strict input validation.** Unknown fields are rejected, names are pattern-checked,
  lengths are capped, enums are exact.
- **Container:** non-root user (UID 10001), no secrets baked in, `.dockerignore` keeps
  `.env` and tests out of the image.

## Notes for deployment (your side)

- **Port:** 8000. **Probes:** liveness `GET /health`, readiness `GET /ready`.
- **Migrations:** run `alembic upgrade head` as a separate step or Job with the same
  environment variables, not at app startup. The image already contains Alembic.
- **Image:** runs as UID/GID 10001 and writes nothing to disk, so a read-only root
  filesystem should work (verify in your cluster).
- **Replicas:** the app is stateless, so it scales horizontally.
- The database user the app uses needs rights on its own tables. A separate,
  non-admin application user is better than the RDS master user.

## Talking points for interviews

- *Why a modular monolith?* One deployable, clear folders, no network hops. Split later
  only if a real need appears.
- *Why separate `/health` and `/ready`?* Liveness restarts a stuck container; readiness
  only removes it from traffic. A database outage should stop traffic, not restart pods.
- *Why PATCH and `exclude_unset`?* The client changes only the fields it sends.
- *Why 409 for duplicates and for deleting a service with incidents?* The request is valid
  but conflicts with current data. 422 is for invalid input; 404 for missing records.
- *Why Alembic instead of `create_all`?* Schema changes are versioned and reviewable,
  and the app cannot change the production schema by accident.
- *Why does the DB engine start lazily?* The pod can start and report liveness even when
  the database is unreachable, and readiness then reports the truth.

## Known limitations

- Reads are unauthenticated and there is no per-user identity or audit trail.
- No rate limiting (do this at the ingress/WAF layer).
- The dashboard loads up to 100 services into its dropdowns, and shows 10 rows per page.
- The dashboard's JavaScript was tested in a simulated browser (jsdom) against the live API,
  not in Chrome or Firefox. Look it over in a real browser once.
- Status values are stored as text and enforced by the application, not by database
  `CHECK` constraints.
- The Dockerfile was written but not built in the environment that produced this project.
