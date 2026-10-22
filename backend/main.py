import sys
import os

# إضافة مجلد الخادم الحالي والمشروع لمسار بايثون للعمل بسلاسة على واندوز
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import database
import models
from routers import products, orders, vendors, support, users

# إنشاء الجداول في قاعدة بيانات SQLite
models.Base.metadata.create_all(bind=database.engine)

def seed_initial_data():
    """تغذية قاعدة البيانات تلقائياً بالبيانات الأولية عند التشغيل لأول مرة"""
    db = database.SessionLocal()
    try:
        if db.query(models.DBVendorStore).count() == 0:
            v1 = models.DBVendorStore(
                id="v1", store_name="متجر التقنية الحديثة", owner_name="محمد التاجر",
                phone="0771111111", description="متجر متخصص بالأجهزة الإلكترونية والذكية", status="مفعل"
            )
            v2 = models.DBVendorStore(
                id="v2", store_name="متجر الأزياء العصرية", owner_name="سارة الأنيقة",
                phone="0772222222", description="أحدث صيحات الموضة والأزياء", status="مفعل"
            )
            v3 = models.DBVendorStore(
                id="v3", store_name="متجر الجمال والعناية", owner_name="خالد الجمال",
                phone="0773333333", description="منتجات تجميل وعناية بالبشرة", status="قيد المراجعة"
            )
            db.add_all([v1, v2, v3])

        if db.query(models.DBProduct).count() == 0:
            p1 = models.DBProduct(
                id="p1", title="هاتف ذكي برو ماكس", description="شاشة أوليد 6.7 إنش، ذاكرة 256 جيجابايت",
                price=850.0, image_url="https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500",
                vendor_id="v1", vendor_name="متجر التقنية الحديثة", category="إلكترونيات", is_available=True, review_status="منشور"
            )
            p2 = models.DBProduct(
                id="p2", title="ساعة ذكية رياضية", description="مقاومة للماء، قياس نبضات القلب ونسبة الأكسجين",
                price=120.0, image_url="https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500",
                vendor_id="v1", vendor_name="متجر التقنية الحديثة", category="إلكترونيات", is_available=True, review_status="منشور"
            )
            p3 = models.DBProduct(
                id="p3", title="حذاء رياضي أنيق", description="مريح جداً للجري والمشي اليومي",
                price=45.0, image_url="https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500",
                vendor_id="v2", vendor_name="متجر الأزياء العصرية", category="أزياء", is_available=True, review_status="منشور"
            )
            p4 = models.DBProduct(
                id="p4", title="طقم العناية بالبشرة الطبيعي", description="منتجات طبيعية 100% للعناية اليومية",
                price=65.0, image_url="https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=500",
                vendor_id="v3", vendor_name="متجر الجمال والعناية", category="صحة وجمال", is_available=True, review_status="قيد المراجعة"
            )
            db.add_all([p1, p2, p3, p4])

        if db.query(models.DBUser).count() == 0:
            u1 = models.DBUser(id="u1", name="أحمد العميل", email="client@alqulaisi.com", role="CLIENT", phone="0770000001", address="صنعاء - اليمن")
            v1_user = models.DBUser(id="v1", name="محمد التاجر", email="vendor@alqulaisi.com", role="VENDOR", phone="0771111111", address="صنعاء - اليمن")
            admin_user = models.DBUser(id="admin1", name="مدير النظام العام", email="admin@alqulaisi.com", role="ADMIN", phone="0779999999", address="صنعاء - اليمن")
            db.add_all([u1, v1_user, admin_user])

        if db.query(models.DBSupportTicket).count() == 0:
            t1 = models.DBSupportTicket(
                id="t1", user_id="u1", user_name="أحمد العميل", user_role="CLIENT",
                subject="استفسار عن موعد التوصيل", details="متى سيتم توصيل الطلب ord-101؟", status="مفتوحة"
            )
            db.add(t1)

        db.commit()
    except Exception as e:
        print(f"تنبيـه: خطأ عند تغذية البيانات الأولية: {e}")
        db.rollback()
    finally:
        db.close()

# تنفيذ التهيئة الأولية
seed_initial_data()

app = FastAPI(
    title="منصة القليسي API - Alqlaisi Platform Central Backend",
    description="الخادم المركزي لمنصة التجارة الإلكترونية متعددة البائعين (العميل، البائع، الإدارة)",
    version="1.0.0"
)

# السماح للاتصالات المتقاطعة (CORS) للتكامل مع تطبيقات Flutter و Dart
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# تضمين الموجهات والخدمات لكل قسم في النظام
app.include_router(products.router)
app.include_router(orders.router)
app.include_router(vendors.router)
app.include_router(support.router)
app.include_router(users.router)

@app.get("/")
def root():
    return {
        "status": "online",
        "system": "منصة القليسي للتجارة الإلكترونية",
        "docs_url": "/docs",
        "platform": "Windows / Cross-platform"
    }

@app.get("/health")
@app.get("/api/health")
def health_check():
    return {
        "status": "online",
        "service": "Al-Qulaisi Backend API",
        "version": "1.0.0"
    }

@app.post("/api/ai/sales-insights")
def get_ai_sales_insights(query: str = ""):
    return {
        "insights": "تحليل Gemini AI لمنصة القليسي: أداء المبيعات مرتفع بنسبة 24% مقارنة بالشهر السابق. أعلى الفئات مبيعاً هي الإلكترونيات ثم الأزياء. يُوصى ببدء حملات ترويجية للتوصيل المجاني لتشجيع عمليات الشراء المكررة."
    }
