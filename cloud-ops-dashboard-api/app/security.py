"""API-key protection for write endpoints (POST, PATCH, DELETE).

Clients send the key in the X-API-Key header. Keys come from the API_KEYS
environment variable. If no key is configured, writes are refused (fail closed).
The key is never logged or included in an error message.
"""
import secrets

from fastapi import Depends, HTTPException, Security
from fastapi.security import APIKeyHeader

from app.config import Settings, get_settings

# auto_error=False so we return our own short message instead of a detailed one.
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


def require_api_key(
    api_key: str | None = Security(api_key_header),
    settings: Settings = Depends(get_settings),
) -> None:
    valid_keys = settings.api_key_list
    if not valid_keys:
        raise HTTPException(
            status_code=503, detail="API key authentication is not configured"
        )

    supplied = (api_key or "").encode()
    # compare_digest takes the same time however many characters match,
    # which prevents guessing a key one character at a time.
    matches = [secrets.compare_digest(supplied, key.encode()) for key in valid_keys]
    if not api_key or not any(matches):
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing API key",
            headers={"WWW-Authenticate": "ApiKey"},
        )
