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
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import auth, orders, products, support, users, vendors

models.Base.metadata.create_all(bind=database.engine)
database.ensure_schema_compatibility()

app = FastAPI(
    title="منصة القليسي API - Alqlaisi Platform Central Backend",
    description="الخادم المركزي لمنصة التجارة الإلكترونية متعددة البائعين",
    version="1.1.1",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Preserve the currently implemented business routers while consolidating the
# application object. The legacy auth routes fail closed; use /auth/* instead.
app.include_router(products.router)
app.include_router(orders.router)
app.include_router(vendors.router)
app.include_router(support.router)
app.include_router(users.router)
app.include_router(auth.router)


@app.get("/")
def root():
    return {
        "status": "online",
        "system": "منصة القليسي للتجارة الإلكترونية",
        "docs_url": "/docs",
        "platform": "Windows / Cross-platform",
    }


@app.get("/health")
@app.get("/api/health")
def health_check():
    return {
        "status": "online",
        "service": "Al-Qulaisi Backend API",
        "version": "1.1.1",
    }


@app.get("/api/v1/health", tags=["System"])
def versioned_health_check():
    return {"status": "ok", "application": "Al Qulaisi", "version": "1.1.1"}


@app.post("/api/ai/sales-insights")
def get_ai_sales_insights(query: str = ""):
    return {
        "insights": "خدمة تحليل المبيعات التجريبية غير مرتبطة حالياً ببيانات المبيعات الفعلية."
    }
