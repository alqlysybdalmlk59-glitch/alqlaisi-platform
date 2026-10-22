"""Authentication endpoints used by the Flutter customer app.

Roles are assigned by the server. Public registration always creates a customer;
seller/admin access must be provisioned through an approved administrative flow.
"""
from __future__ import annotations

import os
import re
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

import database
import models
from routers.dependencies import get_current_principal
from app.core.security import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    create_access_token,
    hash_password,
    verify_password,
    decode_access_token,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


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


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=20, max_length=8192)


def _normalise_phone(phone: str) -> str:
    return re.sub(r"[\s()-]", "", phone)


def _public_user(user: models.DBUser) -> dict[str, Any]:
    return {
        "id": str(user.id),
        "full_name": user.name,
        "name": user.name,
        "phone": user.phone or "",
        "email": user.email if not user.email.endswith("@accounts.alqulaisi.invalid") else None,
        "role": (
            "customer" if user.role.upper() in {"CLIENT", "CUSTOMER"}
            else "seller" if user.role.upper() in {"VENDOR", "SELLER"}
            else user.role.lower()
        ),
        "status": getattr(user, "status", "active") or "active",
        "store_id": getattr(user, "store_id", None),
        "google_linked": bool(getattr(user, "google_subject", None)),
    }


def _session(user: models.DBUser) -> dict[str, Any]:
    role = (
        "customer" if user.role.upper() in {"CLIENT", "CUSTOMER"}
        else "seller" if user.role.upper() in {"VENDOR", "SELLER"}
        else user.role.lower()
    )
    token = create_access_token({
        "sub": str(user.id),
        "email": user.email,
        "role": role,
        "status": getattr(user, "status", "active") or "active",
        "store_id": getattr(user, "store_id", None),
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


def _verified_google_identity(id_token: str) -> tuple[str, str, str]:
    """Verify Google's signed ID token against the configured server/web OAuth audience."""
    client_id = os.getenv("GOOGLE_CLIENT_ID", "").strip()
    if not client_id:
        raise HTTPException(
            status_code=503,
            detail="تسجيل الدخول بواسطة Google غير مهيأ على الخادم.",
        )
    try:
        claims = google_id_token.verify_oauth2_token(
            id_token,
            google_requests.Request(),
            audience=client_id,
        )
    except Exception:
        # Signature, issuer, expiry, or audience failures must fail closed.
        raise HTTPException(status_code=401, detail="رمز Google غير صالح أو منتهي الصلاحية.")

    subject = str(claims.get("sub") or "").strip()
    email = str(claims.get("email") or "").strip().lower()
    name = str(claims.get("name") or "").strip()
    if not subject or not email or claims.get("email_verified") is not True:
        raise HTTPException(
            status_code=401,
            detail="يتطلب تسجيل الدخول بريدًا إلكترونيًا موثقًا من Google.",
        )
    return subject, email, name


@router.post("/google")
def google_login(payload: GoogleLoginRequest, db: Session = Depends(get_db)):
    """Sign in by a verified Google subject without silently merging local accounts."""
    subject, email, name = _verified_google_identity(payload.id_token)
    user = db.query(models.DBUser).filter(
        models.DBUser.google_subject == subject
    ).first()

    if user is None:
        email_user = db.query(models.DBUser).filter(
            models.DBUser.email == email
        ).first()
        if email_user is not None:
            if email_user.role.upper() not in {"CLIENT", "CUSTOMER"}:
                raise HTTPException(status_code=403, detail="هذا الحساب غير مخصص لتطبيق العملاء.")
            if (getattr(email_user, "status", "active") or "active") != "active":
                raise HTTPException(status_code=403, detail="الحساب غير نشط أو قيد المراجعة.")
            if getattr(email_user, "google_subject", None):
                raise HTTPException(
                    status_code=409,
                    detail="هذا البريد مرتبط بهوية Google أخرى. سجّل الدخول بالحساب الأصلي أو تواصل مع الدعم.",
                )
            # Email match alone is not sufficient account-linking proof for all
            # Google account types. Require the customer to authenticate locally,
            # then explicitly link Google from the authenticated profile page.
            raise HTTPException(
                status_code=409,
                detail="يوجد حساب بهذا البريد. سجّل الدخول إليه برقم الهاتف وكلمة المرور ثم اربط Google من الملف الشخصي.",
            )

        user = models.DBUser(
            id=f"google_{subject}",
            name=name or email.split("@", 1)[0],
            email=email,
            role="CLIENT",
            phone="",
            address="",
            password_hash=None,
            status="active",
            google_subject=subject,
        )
        db.add(user)
        try:
            db.commit()
            db.refresh(user)
        except IntegrityError:
            db.rollback()
            # Two concurrent first-time sign-ins can race on unique email/subject.
            user = db.query(models.DBUser).filter(
                models.DBUser.google_subject == subject
            ).first()
            if user is None:
                raise HTTPException(
                    status_code=409,
                    detail="تعذر إنشاء حساب Google بأمان؛ حاول مجددًا أو تواصل مع الدعم.",
                )

    if user.role.upper() not in {"CLIENT", "CUSTOMER"}:
        raise HTTPException(status_code=403, detail="هذا الحساب غير مخصص لتطبيق العملاء.")
    if (getattr(user, "status", "active") or "active") != "active":
        raise HTTPException(status_code=403, detail="الحساب غير نشط أو قيد المراجعة.")
    if getattr(user, "google_subject", None) != subject:
        raise HTTPException(status_code=409, detail="تعذر تأكيد ربط هوية Google بهذا الحساب.")
    return _session(user)


@router.post("/google/link")
def link_google_account(
    payload: GoogleLoginRequest,
    principal: dict = Depends(get_current_principal),
    db: Session = Depends(get_db),
):
    """Explicitly link Google only after the customer has authenticated to this account."""
    if principal["role"] not in {"CLIENT", "CUSTOMER"}:
        raise HTTPException(status_code=403, detail="ربط Google متاح لحسابات العملاء فقط.")

    user = db.query(models.DBUser).filter(
        models.DBUser.id == principal["id"]
    ).first()
    if user is None:
        raise HTTPException(status_code=401, detail="الحساب غير موجود.")
    if (getattr(user, "status", "active") or "active") != "active":
        raise HTTPException(status_code=403, detail="الحساب غير نشط أو قيد المراجعة.")

    subject, email, _name = _verified_google_identity(payload.id_token)

    google_owner = db.query(models.DBUser).filter(
        models.DBUser.google_subject == subject
    ).first()
    if google_owner is not None and str(google_owner.id) != str(user.id):
        raise HTTPException(
            status_code=409,
            detail="هوية Google مرتبطة بحساب آخر؛ لم يتم تغيير أي ربط.",
        )

    current_subject = getattr(user, "google_subject", None)
    if current_subject and current_subject != subject:
        raise HTTPException(
            status_code=409,
            detail="هذا الحساب مرتبط مسبقًا بهوية Google مختلفة. لا يمكن تغييرها من هنا.",
        )

    email_owner = db.query(models.DBUser).filter(
        models.DBUser.email == email,
        models.DBUser.id != user.id,
    ).first()
    if email_owner is not None:
        raise HTTPException(
            status_code=409,
            detail="البريد الموثق من Google مرتبط بحساب آخر. لم يتم ربط الحسابين.",
        )

    stored_email = (user.email or "").strip().lower()
    placeholder_suffix = "@accounts.alqulaisi.invalid"
    if stored_email and not stored_email.endswith(placeholder_suffix) and stored_email != email:
        raise HTTPException(
            status_code=409,
            detail="البريد الموثق من Google لا يطابق بريد هذا الحساب. استخدم البريد الصحيح أو تواصل مع الدعم.",
        )

    user.google_subject = subject
    if not stored_email or stored_email.endswith(placeholder_suffix):
        user.email = email

    try:
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="تعذر ربط Google بسبب تعارض في الهوية أو البريد؛ لم يتم تغيير الربط.",
        )

    return {
        "status": "linked",
        "google_linked": True,
        "user": _public_user(user),
    }


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
