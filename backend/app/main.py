"""Unified FastAPI application entry point.

Run from repository root: uvicorn backend.app.main:app --reload
Run from backend directory: uvicorn app.main:app --reload
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

_BACKEND_DIR = str(Path(__file__).resolve().parents[1])
_REPOSITORY_DIR = str(Path(__file__).resolve().parents[2])
for _path in (_REPOSITORY_DIR, _BACKEND_DIR):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import database
import models
from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from app.core.runtime_config import (IS_PRODUCTION, CORS_ORIGINS, ALLOWED_HOSTS, validate_production_configuration, validate_production_database_schema)
from routers import auth, orders, products, support, users, vendors
from routers.dependencies import get_db, require_customer
from schemas import CheckoutRequest, OrderSchema
from typing import List

validate_production_configuration()
if IS_PRODUCTION:
    validate_production_database_schema(database.engine)
else:
    models.Base.metadata.create_all(bind=database.engine)
    database.ensure_schema_compatibility()

app = FastAPI(
    title="منصة القليسي API - Alqlaisi Platform Central Backend",
    description="الخادم المركزي لمنصة التجارة الإلكترونية متعددة البائعين",
    version="1.2.0",
    docs_url=None if IS_PRODUCTION else "/docs",
    redoc_url=None if IS_PRODUCTION else "/redoc",
    openapi_url=None if IS_PRODUCTION else "/openapi.json",
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=ALLOWED_HOSTS if IS_PRODUCTION else ["*"],
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if IS_PRODUCTION and request.url.scheme == "https":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


# Preserve the currently implemented business routers while consolidating the
# application object. The legacy auth routes fail closed; use /auth/* instead.
app.include_router(products.router)
app.include_router(orders.router)
app.include_router(vendors.router)
app.include_router(support.router)
app.include_router(users.router)
app.include_router(auth.router)
# Compatibility prefix for Flutter ApiClient, whose configured base URL ends with /api.
app.include_router(auth.router, prefix="/api")


@app.get("/")
def root():
    return {
        "status": "online",
        "system": "منصة القليسي للتجارة الإلكترونية",
        **({"docs_url": "/docs"} if not IS_PRODUCTION else {}),
        "version": "1.2.0",
    }


@app.get("/health")
@app.get("/api/health")
def health_check():
    return {
        "status": "online",
        "service": "Al-Qulaisi Backend API",
        "version": "1.2.0",
    }


@app.get("/api/v1/health", tags=["System"])
def versioned_health_check():
    return {"status": "ok", "application": "Al Qulaisi", "version": "1.2.0"}


@app.post("/api/ai/sales-insights")
def get_ai_sales_insights(_principal: dict = Depends(__import__("routers.dependencies", fromlist=["require_admin"]).require_admin)):
    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=501,
        content={"detail": "تحليل المبيعات بالذكاء الاصطناعي غير مفعّل؛ لم يتم توصيله ببيانات المبيعات الفعلية."},
    )


@app.post("/api/checkout", response_model=List[OrderSchema], status_code=201, tags=["orders"])
def checkout_from_flutter(
    payload: CheckoutRequest,
    principal: dict = Depends(require_customer),
    db=Depends(get_db),
):
    """Checkout contract used by the customer Flutter app."""
    return orders.create_orders(payload, principal, db)
