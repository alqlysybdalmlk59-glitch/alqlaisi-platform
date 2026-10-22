"""Compatibility entry point for the unified Al Qulaisi API.

The legacy routers are still the currently implemented business API. Keep one
FastAPI application until their data models and authentication are migrated.
Run from the repository root with:
    uvicorn backend.app.main:app --reload
or, from backend/:
    uvicorn main:app --reload
"""
from __future__ import annotations

import sys
from pathlib import Path

_BACKEND_DIR = str(Path(__file__).resolve().parents[1])
if _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)

# Import the single canonical app which currently mounts the existing business
# routers. This avoids maintaining a second, health-only FastAPI application.
from main import app  # noqa: E402

__all__ = ["app"]
