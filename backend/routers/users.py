"""Deprecated authentication aliases and secure user administration."""
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

import models
from routers.dependencies import get_db, require_admin
from schemas import UserStatusRequest

router = APIRouter(prefix="/api/users", tags=["Users"])


def _deprecated_auth_endpoint():
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="تم إيقاف المسار القديم لأسباب أمنية. استخدم /api/auth/register و/api/auth/login.",
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
        detail="تسجيل الدخول بواسطة Google يتطلب التحقق من Google ID token على الخادم.",
    )


@router.get("/", response_model=List[dict])
def get_users(
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
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
        for user in db.query(models.DBUser).order_by(models.DBUser.name.asc()).all()
    ]


@router.put("/{user_id}/status")
def update_user_status(
    user_id: str,
    payload: UserStatusRequest,
    principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.query(models.DBUser).filter(models.DBUser.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="حساب المستخدم غير موجود.")

    next_status = payload.status
    if (user.role or "").upper() == "ADMIN" and next_status == "suspended":
        if str(user.id) == principal["id"]:
            raise HTTPException(status_code=409, detail="لا يمكنك إيقاف حساب الإدارة الذي تستخدمه حالياً.")
        active_admins = db.query(models.DBUser).filter(
            func.upper(models.DBUser.role) == "ADMIN",
            models.DBUser.status == "active",
        ).count()
        if active_admins <= 1:
            raise HTTPException(status_code=409, detail="لا يمكن إيقاف آخر حساب إداري نشط.")

    user.status = next_status
    db.commit()
    return {"status": "updated", "user_id": str(user.id), "account_status": user.status}
