"""Unified FastAPI application entry point.

Run from repository root: uvicorn backend.app.main:app --reload
Run from backend directory: uvicorn app.main:app --reload
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from decimal import Decimal, InvalidOperation
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
from routers import auth, customer_addresses, orders, products, support, users, vendors
from routers.dependencies import get_db, require_admin, require_customer
from schemas import CheckoutRequest, OrderSchema

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
app.include_router(customer_addresses.router)
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


@app.post("/api/ai/sales-insights", tags=["analytics"])
def get_ai_sales_insights(_principal: dict = Depends(require_admin), db=Depends(get_db)):
    """Return transparent, database-backed sales summaries without claiming an LLM is connected."""
    all_orders = db.query(models.DBOrder).order_by(models.DBOrder.date.desc()).all()
    delivered = [order for order in all_orders if order.status == "تم التسليم"]
    pending_statuses = {"بانتظار القبول", "قيد التجهيز", "جاهز للتوصيل", "قيد التوصيل"}
    status_counts: dict[str, int] = defaultdict(int)
    for order in all_orders:
        status_counts[order.status or "غير معروف"] += 1

    def amount(value) -> Decimal:
        try:
            result = Decimal(str(value))
            return result if result.is_finite() and result >= 0 else Decimal("0.00")
        except (InvalidOperation, TypeError, ValueError):
            return Decimal("0.00")

    product_sales = Decimal("0.00")
    delivery_fees = Decimal("0.00")
    collected_total = Decimal("0.00")
    product_units: dict[str, int] = defaultdict(int)
    product_revenue: dict[str, Decimal] = defaultdict(lambda: Decimal("0.00"))
    product_titles: dict[str, str] = {}
    store_revenue: dict[str, Decimal] = defaultdict(lambda: Decimal("0.00"))
    store_names: dict[str, str] = {}

    for order in delivered:
        merchandise_value = amount(order.items_price)
        fee_value = amount(order.delivery_fee)
        total_value = amount(order.total_price)
        product_sales += merchandise_value
        delivery_fees += fee_value
        collected_total += total_value
        store_revenue[order.vendor_id] += merchandise_value
        store_names[order.vendor_id] = order.vendor_name
        try:
            items = json.loads(order.items_json or "[]")
        except (TypeError, json.JSONDecodeError):
            items = []
        if not isinstance(items, list):
            continue
        for item in items:
            if not isinstance(item, dict):
                continue
            product_id = str(item.get("product_id") or "").strip()
            if not product_id:
                continue
            try:
                quantity = int(item.get("quantity", 0))
            except (TypeError, ValueError):
                continue
            if quantity < 1 or quantity > 10000:
                continue
            line_revenue = amount(item.get("line_total", amount(item.get("unit_price", 0)) * quantity))
            product_units[product_id] += quantity
            product_revenue[product_id] += line_revenue
            product_titles[product_id] = str(item.get("title") or product_id)[:180]

    top_products = [
        {"product_id": product_id, "title": product_titles.get(product_id, product_id),
         "quantity_sold": quantity, "product_sales": float(product_revenue[product_id].quantize(Decimal("0.01")))}
        for product_id, quantity in sorted(product_units.items(), key=lambda pair: (-pair[1], -product_revenue[pair[0]]))[:5]
    ]
    top_stores = [
        {"store_id": store_id, "store_name": store_names.get(store_id, store_id),
         "product_sales": float(value.quantize(Decimal("0.01")))}
        for store_id, value in sorted(store_revenue.items(), key=lambda pair: -pair[1])[:5]
    ]
    cancelled_count = status_counts.get("ملغي", 0)
    pending_count = sum(status_counts.get(status, 0) for status in pending_statuses)
    average_order = (collected_total / len(delivered)) if delivered else Decimal("0.00")

    insights = []
    if not all_orders:
        insights.append("لا توجد طلبات مسجلة بعد؛ ستظهر مؤشرات الأداء عند بدء استقبال الطلبات.")
    elif not delivered:
        insights.append("لا توجد طلبات مسلّمة حتى الآن؛ لا يمكن احتساب المبيعات المحصلة بصورة موثوقة.")
    else:
        insights.append(f"تم تسليم {len(delivered)} طلباً بقيمة محصلة إجمالية {collected_total.quantize(Decimal('0.01'))} ريال.")
        if top_products:
            insights.append(f"المنتج الأعلى مبيعاً حسب الكمية المسجلة هو «{top_products[0]['title']}» بعدد {top_products[0]['quantity_sold']} وحدة.")
    if pending_count:
        insights.append(f"يوجد {pending_count} طلباً غير منتهٍ؛ راجع التجهيز وإسناد التوصيل من لوحة الإدارة.")
    if all_orders and cancelled_count / len(all_orders) >= 0.15:
        insights.append("نسبة الطلبات الملغاة مرتفعة نسبياً؛ راجع سجل الحالات وأسباب الإلغاء قبل اتخاذ قرار تشغيلي.")
    if not insights:
        insights.append("لا تظهر إشارة تشغيلية كافية من البيانات الحالية؛ استمر في تسجيل حالات الطلبات بدقة.")

    return {
        "source": "database_rule_based",
        "ai_model_connected": False,
        "currency": "YER",
        "summary": {
            "total_orders": len(all_orders),
            "delivered_orders": len(delivered),
            "pending_orders": pending_count,
            "cancelled_orders": cancelled_count,
            "product_sales_total": float(product_sales.quantize(Decimal("0.01"))),
            "delivery_fee_total": float(delivery_fees.quantize(Decimal("0.01"))),
            "collected_total": float(collected_total.quantize(Decimal("0.01"))),
            "average_delivered_order_value": float(average_order.quantize(Decimal("0.01"))),
        },
        "order_status_counts": dict(status_counts),
        "top_products": top_products,
        "top_stores": top_stores,
        "insights": insights,
        "notice": "هذه مؤشرات وقواعد تحليلية محسوبة من قاعدة البيانات، وليست توصيات مولّدة بنموذج ذكاء اصطناعي.",
    }


@app.post("/api/checkout", response_model=list[OrderSchema], status_code=201, tags=["orders"])
def checkout_from_flutter(
    payload: CheckoutRequest,
    principal: dict = Depends(require_customer),
    db=Depends(get_db),
):
    """Checkout contract used by the customer Flutter app."""
    return orders.create_orders(payload, principal, db)
