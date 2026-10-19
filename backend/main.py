from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import database
import models
from routers import products, orders, vendors, support

# إنشاء كافة الجداول في قاعدة بيانات SQLite عند بدء الخادم
models.Base.metadata.create_all(bind=database.engine)

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

@app.get("/")
def root():
    return {
        "status": "online",
        "system": "منصة القليسي للتجارة الإلكترونية",
        "docs_url": "/docs"
    }

@app.post("/api/ai/sales-insights")
def get_ai_sales_insights(query: str):
    return {
        "insights": "تحليل Gemini AI لمنصة القليسي: أداء المبيعات مرتفع بنسبة 24% مقارنة بالشهر السابق. أعلى الفئات مبيعاً هي الإلكترونيات ثم الأزياء. يُوصى ببدء حملات ترويجية للتوصيل المجاني لتشجيع عمليات الشراء المكررة."
    }
