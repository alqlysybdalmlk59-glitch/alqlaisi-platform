"""Compatibility entry point for the single secured FastAPI application.

Supported launch forms:
  uvicorn backend.app.main:app --reload
  uvicorn backend.main:app --reload
  (from backend/): uvicorn main:app --reload

All forms resolve to the same production-validated app; this module does not
seed demo accounts, bypass startup validation, or define separate middleware.
"""
import sys
from pathlib import Path

_REPOSITORY_ROOT = str(Path(__file__).resolve().parents[1])
_BACKEND_ROOT = str(Path(__file__).resolve().parent)
for _directory in (_REPOSITORY_ROOT, _BACKEND_ROOT):
    if _directory not in sys.path:
        sys.path.insert(0, _directory)

from backend.app.main import app  # noqa: E402

__all__ = ["app"]
