"""Fresh database-backed principal lookup and reusable role checks."""
from __future__ import annotations
from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session
import database
import models
from app.core.security import decode_access_token

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_principal(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="يجب تسجيل الدخول أولاً.")
    try:
        claims = decode_access_token(authorization.split(" ", 1)[1].strip())
    except (ValueError, RuntimeError):
        raise HTTPException(status_code=401, detail="رمز الدخول غير صالح أو منتهي الصلاحية.")
    user_id = claims.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="رمز الدخول لا يحتوي على معرّف المستخدم.")
    user = db.query(models.DBUser).filter(models.DBUser.id == str(user_id)).first()
    if user is None:
        raise HTTPException(status_code=401, detail="الحساب المرتبط بالرمز غير موجود.")
    account_status = getattr(user, "status", "active") or "active"
    if account_status != "active":
        raise HTTPException(status_code=403, detail="الحساب غير نشط أو موقوف.")
    role = (user.role or "").strip().upper()
    store_id = getattr(user, "store_id", None)
    if not store_id and role in {"VENDOR", "SELLER"}:
        store = db.query(models.DBVendorStore).filter(
            models.DBVendorStore.owner_user_id == str(user.id)
        ).first()
        store_id = store.id if store else None
    return {"id": str(user.id), "role": role, "email": user.email,
            "name": user.name, "status": account_status, "store_id": store_id}

def require_roles(*roles: str):
    allowed = {role.upper() for role in roles}
    def dependency(principal: dict = Depends(get_current_principal)) -> dict:
        if principal["role"] not in allowed:
            raise HTTPException(status_code=403, detail="ليس لديك الصلاحية لتنفيذ هذه العملية.")
        return principal
    return dependency

require_admin = require_roles("ADMIN")
require_customer = require_roles("CLIENT", "CUSTOMER")
require_seller_or_admin = require_roles("VENDOR", "SELLER", "ADMIN")
