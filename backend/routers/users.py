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

router = APIRouter(prefix="/api/users", tags=["Users (legacy; use /api/auth)"])


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


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
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="يتطلب عرض المستخدمين صلاحية مدير النظام.")
    try:
        payload = decode_access_token(authorization.split(" ", 1)[1])
    except (ValueError, RuntimeError):
        raise HTTPException(status_code=401, detail="رمز الدخول غير صالح أو منتهي الصلاحية.")
    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="هذه الوظيفة مخصصة لمدير النظام.")
    return [
        {
            "id": str(user.id),
            "name": user.name,
            "email": user.email if not user.email.endswith("@accounts.alqulaisi.invalid") else None,
            "role": user.role,
            "phone": user.phone,
            "address": user.address,
            "status": getattr(user, "status", "active"),
        }
        for user in db.query(models.DBUser).all()
    ]
