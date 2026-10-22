"""Authentication endpoints used by the Flutter customer app.

Roles are assigned by the server. Public registration always creates a customer;
seller/admin access must be provisioned through an approved administrative flow.
"""
from __future__ import annotations

import re
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

import database
import models
from app.core.security import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    create_access_token,
    hash_password,
    verify_password,
    decode_access_token,
)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=100)
    phone: str = Field(min_length=8, max_length=20)
    password: str = Field(min_length=8, max_length=100)
    email: str | None = None


class LoginRequest(BaseModel):
    phone: str = Field(min_length=8, max_length=20)
    password: str = Field(min_length=1, max_length=100)


def _normalise_phone(phone: str) -> str:
    return re.sub(r"[\s()-]", "", phone)


def _public_user(user: models.DBUser) -> dict[str, Any]:
    return {
        "id": str(user.id),
        "full_name": user.name,
        "name": user.name,
        "phone": user.phone or "",
        "email": user.email if not user.email.endswith("@accounts.alqulaisi.invalid") else None,
        "role": "customer" if user.role.upper() in {"CLIENT", "CUSTOMER"} else user.role.lower(),
        "status": getattr(user, "status", "active") or "active",
    }


def _session(user: models.DBUser) -> dict[str, Any]:
    role = "customer" if user.role.upper() in {"CLIENT", "CUSTOMER"} else user.role.lower()
    token = create_access_token({
        "sub": str(user.id),
        "email": user.email,
        "role": role,
        "status": getattr(user, "status", "active") or "active",
    }, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    return {"access_token": token, "token_type": "bearer", "user": _public_user(user)}


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    phone = _normalise_phone(payload.phone)
    if not phone:
        raise HTTPException(status_code=422, detail="رقم الهاتف غير صالح.")

    existing_phone = db.query(models.DBUser).filter(models.DBUser.phone == phone).first()
    if existing_phone:
        raise HTTPException(status_code=409, detail="رقم الهاتف مسجل مسبقاً.")

    email = payload.email.strip().lower() if payload.email and payload.email.strip() else None
    if email and db.query(models.DBUser).filter(models.DBUser.email == email).first():
        raise HTTPException(status_code=409, detail="البريد الإلكتروني مسجل مسبقاً.")

    # The legacy schema requires a non-null email. If the customer omits it,
    # use a non-deliverable internal identifier, never a fabricated real address.
    stored_email = email or f"phone-{phone}@accounts.alqulaisi.invalid"
    user = models.DBUser(
        id=f"u_{phone}",
        name=payload.full_name.strip(),
        email=stored_email,
        role="CLIENT",
        phone=phone,
        address="",
        password_hash=hash_password(payload.password),
        status="active",
    )
    db.add(user)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=409, detail="تعذر إنشاء الحساب؛ تحقق من بيانات التسجيل.")
    db.refresh(user)
    return _session(user)


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    phone = _normalise_phone(payload.phone)
    user = db.query(models.DBUser).filter(models.DBUser.phone == phone).first()

    # Old demo/seed accounts have no password hash and must not be allowed to
    # log in with an arbitrary password.
    if (
        user is None
        or not getattr(user, "password_hash", None)
        or not verify_password(payload.password, user.password_hash)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رقم الهاتف أو كلمة المرور غير صحيحة.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    account_status = getattr(user, "status", "active") or "active"
    if account_status != "active":
        raise HTTPException(status_code=403, detail="الحساب غير نشط أو قيد المراجعة.")
    return _session(user)


@router.get("/me")
def current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="رمز الدخول مفقود أو غير صحيح.")

    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = decode_access_token(token)
    except (ValueError, RuntimeError):
        raise HTTPException(status_code=401, detail="رمز الدخول غير صالح أو منتهي الصلاحية.")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="رمز الدخول لا يحتوي على معرّف المستخدم.")

    user = db.query(models.DBUser).filter(models.DBUser.id == str(user_id)).first()
    if user is None:
        raise HTTPException(status_code=401, detail="الحساب المرتبط بالرمز غير موجود.")

    account_status = getattr(user, "status", "active") or "active"
    if account_status != "active":
        raise HTTPException(status_code=403, detail="الحساب غير نشط أو قيد المراجعة.")
    return _public_user(user)


@router.post("/logout")
def logout():
    # JWTs are stateless in this iteration; the client must discard its token.
    return {"status": "ok", "message": "تم تسجيل الخروج على هذا الجهاز."}


@router.post("/forgot-password", status_code=501)
def forgot_password():
    raise HTTPException(
        status_code=501,
        detail="استعادة كلمة المرور غير مفعلة بعد؛ لن نعرض نجاحاً وهمياً قبل إعداد قناة تحقق آمنة.",
    )
