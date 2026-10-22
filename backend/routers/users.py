"""Deprecated legacy user endpoints.

Authentication has moved to /api/auth. These compatibility paths deliberately
fail closed instead of retaining the previous passwordless auto-provisioning
and client-asserted Google identity behavior.
"""
from fastapi import APIRouter, Header, HTTPException, status, Depends
from sqlalchemy.orm import Session
from typing import List

import database
import models
from app.core.security import decode_access_token
from routers.dependencies import get_db as secure_get_db, require_admin

router = APIRouter(prefix="/api/users", tags=["Users (legacy; use /api/auth)"])


def _deprecated_auth_endpoint():
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="تم إيقاف هذا المسار القديم لأسباب أمنية. استخدم /api/auth/register و/api/auth/login.",
    )


@router.post("/register")
def register_user():
    return _deprecated_auth_endpoint()


@router.post("/login")
def login_user():
    return _deprecated_auth_endpoint()


@router.post("/google-login")
def google_login():
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="تسجيل الدخول بواسطة Google غير متاح حتى يتم التحقق من Google ID token على الخادم.",
    )


@router.get("/", response_model=List[dict])
def get_users(
    _principal: dict = Depends(require_admin),
    db: Session = Depends(secure_get_db),
):
    return [
        {
            "id": str(user.id),
            "name": user.name,
            "email": user.email if not user.email.endswith("@accounts.alqulaisi.invalid") else None,
            "role": user.role,
            "phone": user.phone,
            "address": user.address,
            "status": getattr(user, "status", "active"),
            "store_id": getattr(user, "store_id", None),
        }
        for user in db.query(models.DBUser).all()
    ]
