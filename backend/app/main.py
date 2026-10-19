"""
Main FastAPI Application for Al-Qulaisi Multi-Vendor E-Commerce Platform.
"""

from fastapi import FastAPI, Depends, status
from fastapi.middleware.cors import CORSMiddleware

from backend.app.middleware.access_control import (
    AccessControlMiddleware,
    require_admin,
    require_seller,
    require_customer,
    get_current_user,
    verify_seller_store_ownership
)
from backend.app.models.user import UserRole

app = FastAPI(
    title="منصة القليسي - Al-Qulaisi Multi-Vendor API",
    description="نظام إدارة التجارة الإلكترونية متعدد البائعين مع فصل صارم للصلاحيات بين العميل والبائع والإدارة.",
    version="1.0.0"
)

# 1. CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Add Perimeter Role-Based Access Control Middleware
app.add_middleware(AccessControlMiddleware)


# --------------------------------------------------------------------------
# Root & Health Check Endpoints (Public)
# --------------------------------------------------------------------------

@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "online",
        "platform": "Al-Qulaisi Multi-Vendor E-Commerce",
        "version": "1.0.0",
        "security": "Enforced RBAC Middleware Active"
    }


# --------------------------------------------------------------------------
# Customer Protected Endpoints Sample
# --------------------------------------------------------------------------

@app.get("/api/customer/profile", tags=["Customer"])
def get_customer_profile(user: dict = Depends(require_customer)):
    return {
        "message": "بيانات العميل الشخصية",
        "user_id": user.get("sub"),
        "email": user.get("email"),
        "role": user.get("role")
    }


# --------------------------------------------------------------------------
# Seller Protected Endpoints Sample
# --------------------------------------------------------------------------

@app.get("/api/seller/store/{store_id}/products", tags=["Seller"])
def get_seller_products(store_id: int, user: dict = Depends(require_seller)):
    # Verify tenant ownership: Seller A cannot view Seller B's private catalog management
    verify_seller_store_ownership(store_id, user)
    return {
        "store_id": store_id,
        "message": f"منتجات المتجر رقم {store_id} المصرح للبائع بإدارتها",
        "seller_id": user.get("sub")
    }


# --------------------------------------------------------------------------
# Admin Protected Endpoints Sample
# --------------------------------------------------------------------------

@app.get("/api/admin/system/metrics", tags=["Admin"])
def get_admin_metrics(user: dict = Depends(require_admin)):
    return {
        "message": "مؤشرات التشغيل ولوحة المعلومات الإدارية",
        "admin_id": user.get("sub"),
        "total_users": 1500,
        "active_stores": 45,
        "pending_store_reviews": 6,
        "pending_product_reviews": 12
    }
