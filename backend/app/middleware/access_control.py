"""
Access Control Middleware & Security Dependencies for Al-Qulaisi Platform.
Enforces server-side separation between Customers, Sellers, and Admins.
"""

from typing import List, Optional, Callable
from datetime import datetime
import json
import logging

try:
    from fastapi import Request, HTTPException, Depends, status
    from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
    from starlette.middleware.base import BaseHTTPMiddleware
    from starlette.responses import JSONResponse, Response
except ImportError:
    class BaseHTTPMiddleware:
        def __init__(self, app):
            self.app = app

    class JSONResponse:
        def __init__(self, content, status_code=200):
            self.content = content
            self.status_code = status_code

    class HTTPException(Exception):
        def __init__(self, status_code: int, detail: str):
            super().__init__(detail)
            self.status_code = status_code
            self.detail = detail

    class HTTPBearer:
        def __init__(self, auto_error: bool = True):
            pass

    class HTTPAuthorizationCredentials:
        def __init__(self, credentials: str):
            self.credentials = credentials

    class Request:
        pass

    class Response:
        pass

    def Depends(dependency=None):
        return dependency

    class status:
        HTTP_400_BAD_REQUEST = 400
        HTTP_401_UNAUTHORIZED = 401
        HTTP_403_FORBIDDEN = 403
        HTTP_404_NOT_FOUND = 404

from backend.app.models.user import UserRole, UserStatus, UserResponse
from backend.app.core.security import decode_access_token

logger = logging.getLogger("alqulaisi.security")
logger.setLevel(logging.INFO)

security_scheme = HTTPBearer(auto_error=False)


# --------------------------------------------------------------------------
# Security Error Response Formatter
# --------------------------------------------------------------------------

def create_security_error(
    status_code: int,
    error_code: str,
    message_ar: str,
    message_en: str,
    path: str = ""
) -> JSONResponse:
    """
    Standardized security error payload in both Arabic and English.
    Ensures frontends display actionable, localized security feedback.
    """
    payload = {
        "success": False,
        "error": {
            "code": error_code,
            "status_code": status_code,
            "message": message_ar,
            "message_en": message_en,
            "path": path,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    }
    return JSONResponse(status_code=status_code, content=payload)


# --------------------------------------------------------------------------
# Access Control Middleware (BaseHTTPMiddleware)
# --------------------------------------------------------------------------

class AccessControlMiddleware(BaseHTTPMiddleware):
    """
    High-performance perimeter middleware that inspects incoming HTTP requests.
    Enforces route-level role boundaries, isolates tenant data, and logs
    unauthorized cross-role privilege escalation attempts.
    """

    PUBLIC_PATH_PREFIXES = [
        "/api/auth/login",
        "/api/auth/register",
        "/api/auth/forgot-password",
        "/api/public/",
        "/docs",
        "/openapi.json",
        "/redoc",
        "/health"
    ]

    ADMIN_PATH_PREFIXES = ["/api/admin"]
    SELLER_PATH_PREFIXES = ["/api/seller"]
    CUSTOMER_PATH_PREFIXES = ["/api/customer"]

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        path = request.url.path
        client_ip = request.client.host if request.client else "unknown"

        # 1. Allow public endpoints immediately
        if any(path.startswith(prefix) for prefix in self.PUBLIC_PATH_PREFIXES):
            return await call_next(request)

        # 2. Extract Authorization Header
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return create_security_error(
                status_code=401,
                error_code="AUTHENTICATION_REQUIRED",
                message_ar="يجب تسجيل الدخول للوصول إلى هذا المورد المصرح به.",
                message_en="Authentication token is required to access this resource.",
                path=path
            )

        token = auth_header.replace("Bearer ", "").strip()
        try:
            payload = decode_access_token(token)
        except ValueError as e:
            logger.warning(f"[Security Audit] Invalid token attempt from IP {client_ip} to {path}: {str(e)}")
            return create_security_error(
                status_code=401,
                error_code="INVALID_OR_EXPIRED_TOKEN",
                message_ar="رمز الدخول غير صالح أو انتهت صلاحيته. يرجى تسجيل الدخول مجدداً.",
                message_en="The access token is invalid or has expired.",
                path=path
            )

        user_role = payload.get("role")
        user_status = payload.get("status")
        user_id = payload.get("sub")

        # 3. Check Account Status (Suspend/Deactivate)
        if user_status == UserStatus.SUSPENDED.value:
            logger.warning(f"[Security Audit] Suspended user {user_id} attempted access to {path}")
            return create_security_error(
                status_code=403,
                error_code="ACCOUNT_SUSPENDED",
                message_ar="هذا الحساب موقوف حالياً من قبل الإدارة. يرجى مراجعة الدعم.",
                message_en="Your account has been suspended by administration.",
                path=path
            )

        # 4. Enforce Strict Role Boundaries at Path Level

        # Rule A: Admin Area Protection
        if any(path.startswith(prefix) for prefix in self.ADMIN_PATH_PREFIXES):
            if user_role != UserRole.ADMIN.value:
                logger.warning(
                    f"[Security Violation] Unauthorized access attempt to ADMIN route {path} "
                    f"by User {user_id} with role '{user_role}' from IP {client_ip}"
                )
                return create_security_error(
                    status_code=403,
                    error_code="ADMIN_PRIVILEGE_REQUIRED",
                    message_ar="غير مصرح: هذا القسم مخصص لإدارة منصة القليسي فقط.",
                    message_en="Forbidden: Administrative privileges are required.",
                    path=path
                )

        # Rule B: Seller Area Protection
        if any(path.startswith(prefix) for prefix in self.SELLER_PATH_PREFIXES):
            if user_role not in [UserRole.SELLER.value, UserRole.ADMIN.value]:
                logger.warning(
                    f"[Security Violation] Customer {user_id} attempted to access SELLER route {path}"
                )
                return create_security_error(
                    status_code=403,
                    error_code="SELLER_PRIVILEGE_REQUIRED",
                    message_ar="غير مصرح: هذه العمليات متاحة فقط لحسابات البائعين المعتمدين.",
                    message_en="Forbidden: Seller privileges are required.",
                    path=path
                )

        # Rule C: Attach User Context to Request State for Downstream Handlers
        request.state.current_user_id = user_id
        request.state.current_user_role = user_role
        request.state.current_user_store_id = payload.get("store_id")

        response = await call_next(request)
        return response


# --------------------------------------------------------------------------
# FastAPI Security Dependencies (Fine-Grained Role & Tenant Guards)
# --------------------------------------------------------------------------

def get_current_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme)) -> dict:
    """
    Dependency that decodes the bearer token and returns the authenticated user payload.
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز الدخول مفقود. يجب تسجيل الدخول للمتابعة."
        )
    try:
        payload = decode_access_token(credentials.credentials)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز الدخول غير صالح أو انتهت صلاحيته."
        )
    return payload


def require_role(*allowed_roles: UserRole):
    """
    Factory dependency checking if authenticated user holds one of the allowed roles.
    Example: Depends(require_role(UserRole.ADMIN))
    """
    def role_checker(user: dict = Depends(get_current_user)) -> dict:
        role = user.get("role")
        if role not in [r.value for r in allowed_roles]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"صلاحيات غير كافية. هذه العملية تتطلب دور: {[r.value for r in allowed_roles]}"
            )
        return user
    return role_checker


# Convenient Pre-built Guards
require_admin = require_role(UserRole.ADMIN)
require_seller = require_role(UserRole.SELLER, UserRole.ADMIN)
require_customer = require_role(UserRole.CUSTOMER, UserRole.ADMIN)


# --------------------------------------------------------------------------
# Business & Multi-Tenant Security Rules
# --------------------------------------------------------------------------

def verify_seller_store_ownership(store_id: int, current_user: dict):
    """
    Enforces multi-vendor tenant isolation:
    A seller can NEVER view or modify another seller's store data, products, or orders.
    Admins are permitted for platform governance.
    """
    role = current_user.get("role")
    user_store_id = current_user.get("store_id")

    if role == UserRole.ADMIN.value:
        return True

    if role != UserRole.SELLER.value or user_store_id != store_id:
        logger.warning(
            f"[Tenant Violation] Seller User {current_user.get('sub')} attempted to manipulate Store {store_id}"
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يمكنك الوصول إلى بيانات متجر بائع آخر أو تعديلها."
        )
    return True


def verify_order_access(order_customer_id: int, order_store_id: int, current_user: dict):
    """
    Enforces order privacy:
    - Customer can ONLY see orders where customer_id matches their own ID.
    - Seller can ONLY see orders where store_id matches their assigned store.
    - Admin can oversee all orders.
    """
    role = current_user.get("role")
    user_id = int(current_user.get("sub", 0))
    user_store_id = current_user.get("store_id")

    if role == UserRole.ADMIN:
        return True

    if role == UserRole.CUSTOMER.value and user_id == order_customer_id:
        return True

    if role == UserRole.SELLER.value and user_store_id == order_store_id:
        return True

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="غير مصرح: ليس لديك صلاحية الاطلاع على هذا الطلب."
    )


def verify_review_eligibility(order_status: str, order_customer_id: int, current_user: dict):
    """
    Enforce Rule 3.8:
    A customer may ONLY review a product if:
    1. The customer actually ordered the product.
    2. The order status is officially DELIVERED (تم التسليم).
    Reviews are strictly blocked for pending, cancelled, or processing orders.
    """
    user_id = int(current_user.get("sub", 0))
    if user_id != order_customer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="لا يمكنك تقييم منتج لم تقم بشرائه بنفسك."
        )

    if order_status != "delivered":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يُسمح بتقييم المنتج إلا بعد استلام الطلب واكتمال التوصيل (تم التسليم)."
        )
    return True
