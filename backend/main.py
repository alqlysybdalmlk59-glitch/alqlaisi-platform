import sys
import os

# Ensure legacy business routers and models remain importable from either
# repository-root or backend-directory launch commands.
_BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
_REPOSITORY_DIR = os.path.dirname(_BACKEND_DIR)
if _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)
if _REPOSITORY_DIR not in sys.path:
    sys.path.insert(0, _REPOSITORY_DIR)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import database
import models
from routers import products, orders, vendors, support, users, auth

# Existing SQLite schema and legacy routes are intentionally retained for this
# first consolidation step. Database migration will be handled separately.
models.Base.metadata.create_all(bind=database.engine)
database.ensure_schema_compatibility()


def seed_initial_data():
    """Seed legacy development data only when the corresponding tables are empty."""
    db = database.SessionLocal()
    try:
        if db.query(models.DBVendorStore).count() == 0:
            db.add_all([
                models.DBVendorStore(
                    id="v1", store_name="متجر التقنية الحديثة", owner_name="محمد التاجر",
                    phone="0771111111", description="متجر متخصص بالأجهزة الإلكترونية والذكية", status="مفعل"
                ),
                models.DBVendorStore(
                    id="v2", store_name="متجر الأزياء العصرية", owner_name="سارة الأنيقة",
                    phone="0772222222", description="أحدث صيحات الموضة والأزياء", status="مفعل"
                ),
                models.DBVendorStore(
                    id="v3", store_name="متجر الجمال والعناية", owner_name="خالد الجمال",
                    phone="0773333333", description="منتجات تجميل وعناية بالبشرة", status="قيد المراجعة"
                ),
            ])

        if db.query(models.DBProduct).count() == 0:
            db.add_all([
                models.DBProduct(
                    id="p1", title="هاتف ذكي برو ماكس", description="شاشة أوليد 6.7 إنش، ذاكرة 256 جيجابايت",
                    price=850.0, image_url="https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500",
                    vendor_id="v1", vendor_name="متجر التقنية الحديثة", category="إلكترونيات", is_available=True, review_status="منشور"
                ),
                models.DBProduct(
                    id="p2", title="ساعة ذكية رياضية", description="مقاومة للماء، قياس نبضات القلب ونسبة الأكسجين",
                    price=120.0, image_url="https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500",
                    vendor_id="v1", vendor_name="متجر التقنية الحديثة", category="إلكترونيات", is_available=True, review_status="منشور"
                ),
                models.DBProduct(
                    id="p3", title="حذاء رياضي أنيق", description="مريح جداً للجري والمشي اليومي",
                    price=45.0, image_url="https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500",
                    vendor_id="v2", vendor_name="متجر الأزياء العصرية", category="أزياء", is_available=True, review_status="منشور"
                ),
                models.DBProduct(
                    id="p4", title="طقم العناية بالبشرة الطبيعي", description="منتجات طبيعية 100% للعناية اليومية",
                    price=65.0, image_url="https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=500",
                    vendor_id="v3", vendor_name="متجر الجمال والعناية", category="صحة وجمال", is_available=True, review_status="قيد المراجعة"
                ),
            ])

        if db.query(models.DBUser).count() == 0:
            db.add_all([
                models.DBUser(id="u1", name="أحمد العميل", email="client@alqulaisi.com", role="CLIENT", phone="0770000001", address="صنعاء - اليمن"),
                models.DBUser(id="v1", name="محمد التاجر", email="vendor@alqulaisi.com", role="VENDOR", phone="0771111111", address="صنعاء - اليمن"),
                models.DBUser(id="admin1", name="مدير النظام العام", email="admin@alqulaisi.com", role="ADMIN", phone="0779999999", address="صنعاء - اليمن"),
            ])

        if db.query(models.DBSupportTicket).count() == 0:
            db.add(models.DBSupportTicket(
                id="t1", user_id="u1", user_name="أحمد العميل", user_role="CLIENT",
                subject="استفسار عن موعد التوصيل", details="متى سيتم توصيل الطلب ord-101؟", status="مفتوحة"
            ))

        db.commit()
    except Exception as exc:
        print(f"تنبيه: تعذرت تهيئة البيانات الأولية: {exc}")
        db.rollback()
    finally:
        db.close()


seed_initial_data()

app = FastAPI(
    title="منصة القليسي API - Alqlaisi Platform Central Backend",
    description="الخادم المركزي لمنصة التجارة الإلكترونية متعددة البائعين",
    version="1.1.0",
)

# Preserve existing local app integrations. Restrict production origins in a
# dedicated configuration change after the client URLs are confirmed.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Preserve all existing legacy business endpoints.
app.include_router(products.router)
app.include_router(orders.router)
app.include_router(vendors.router)
app.include_router(support.router)
app.include_router(users.router)  # Legacy endpoints retained during migration.\napp.include_router(auth.router)


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
        "version": "1.1.0",
    }


@app.get("/api/v1/health", tags=["System"])
def versioned_health_check():
    return {"status": "ok", "application": "Al Qulaisi", "version": "1.1.0"}


@app.post("/api/ai/sales-insights")
def get_ai_sales_insights(query: str = ""):
    # Existing placeholder response retained for compatibility; it is not
    # generated from live sales data and must not be presented as real analytics.
    return {
        "insights": "خدمة تحليل المبيعات التجريبية غير مرتبطة حالياً ببيانات المبيعات الفعلية."
    }
