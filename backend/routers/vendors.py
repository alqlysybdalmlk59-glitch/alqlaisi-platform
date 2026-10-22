import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from models import DBUser, DBVendorStore, DBVendorOwnershipHistory
from schemas import DeliveryFeeRequest, VendorApplicationRequest, VendorOwnerLinkRequest, VendorStoreSchema, AdminVendorStoreSchema, VendorOwnershipHistorySchema
from routers.dependencies import get_db, get_current_principal, require_admin, require_customer

router = APIRouter(prefix="/api/vendors", tags=["vendors"])

@router.get("/", response_model=list[AdminVendorStoreSchema])
def get_all_vendors(_principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    return db.query(DBVendorStore).order_by(DBVendorStore.store_name.asc()).all()

@router.get("/mine", response_model=VendorStoreSchema | None)
def get_my_vendor_store(principal: dict = Depends(get_current_principal),
    db: Session = Depends(get_db)):
    # Only the owner foreign key is authoritative; users.store_id alone cannot grant access.
    return db.query(DBVendorStore).filter(DBVendorStore.owner_user_id == principal["id"]).first()


@router.get("/{vendor_id}/ownership-history", response_model=list[VendorOwnershipHistorySchema])
def get_vendor_ownership_history(vendor_id: str, _principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    if db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first() is None:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    return db.query(DBVendorOwnershipHistory).filter(
        DBVendorOwnershipHistory.store_id == vendor_id
    ).order_by(DBVendorOwnershipHistory.created_at.asc(), DBVendorOwnershipHistory.id.asc()).all()


@router.get("/public", response_model=list[VendorStoreSchema])
def get_public_vendors(db: Session = Depends(get_db)):
    # A visible store must have the same active owner relationship required by checkout.
    return (
        db.query(DBVendorStore)
        .join(DBUser, DBVendorStore.owner_user_id == DBUser.id)
        .filter(
            DBVendorStore.status == "مفعل",
            DBUser.status == "active",
            DBUser.role.in_(["VENDOR", "SELLER"]),
            DBUser.store_id == DBVendorStore.id,
        )
        .order_by(DBVendorStore.store_name.asc())
        .all()
    )

@router.post("/register", response_model=VendorStoreSchema, status_code=201)
def register_vendor(application: VendorApplicationRequest, principal: dict = Depends(require_customer), db: Session = Depends(get_db)):
    user = db.query(DBUser).filter(DBUser.id == principal["id"]).first()
    if user is None:
        raise HTTPException(status_code=401, detail="الحساب غير موجود.")
    store = db.query(DBVendorStore).filter(DBVendorStore.owner_user_id == principal["id"]).first()
    if store is not None:
        if store.status != "مرفوض":
            raise HTTPException(status_code=409, detail="لديك طلب متجر مسجل مسبقاً.")
        store.store_name = application.store_name.strip()
        store.owner_name = user.name
        store.phone = application.phone.strip()
        store.description = application.description.strip()
        store.status = "قيد المراجعة"
        store.admin_notes = ""
        db.add(DBVendorOwnershipHistory(
            id=f"owner_history_{uuid.uuid4().hex}", store_id=store.id,
            previous_owner_user_id=store.owner_user_id, new_owner_user_id=store.owner_user_id,
            actor_user_id=principal["id"], action="application_resubmitted",
            verification_note="إعادة تقديم الطلب من الحساب المصادق عليه والمرتبط مسبقاً بالمتجر.",
            created_at=datetime.now(timezone.utc).isoformat(),
        ))
        db.commit()
        db.refresh(store)
        return store

    store = DBVendorStore(
        id=f"store_{uuid.uuid4().hex}", store_name=application.store_name.strip(),
        owner_name=user.name, phone=application.phone.strip(),
        description=application.description.strip(), status="قيد المراجعة",
        admin_notes="", owner_user_id=str(user.id), delivery_fee=15.0,
    )
    db.add(store)
    try:
        db.flush()
        db.add(DBVendorOwnershipHistory(
            id=f"owner_history_{uuid.uuid4().hex}", store_id=store.id,
            previous_owner_user_id=None, new_owner_user_id=str(user.id),
            actor_user_id=principal["id"], action="application_submitted",
            verification_note="تم إنشاء الطلب من الحساب المصادق عليه؛ استُمد المالك من هوية الخادم وليس من حقول الواجهة.",
            created_at=datetime.now(timezone.utc).isoformat(),
        ))
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=409, detail="تعذر تسجيل المتجر. تحقق من عدم وجود طلب سابق.")
    db.refresh(store)
    return store


@router.put("/{vendor_id}/approve")
def approve_vendor(vendor_id: str, principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not store:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    if not store.owner_user_id:
        raise HTTPException(status_code=409, detail="هذا المتجر غير مربوط بحساب؛ اربط حساب المالك أولاً.")
    owner = db.query(DBUser).filter(DBUser.id == store.owner_user_id).first()
    if owner is None or owner.status != "active":
        raise HTTPException(status_code=409, detail="حساب مالك المتجر غير موجود أو غير نشط.")
    if owner.role.upper() not in {"CLIENT", "CUSTOMER", "VENDOR", "SELLER"}:
        raise HTTPException(status_code=409, detail="لا يمكن إسناد حساب إداري كمالك متجر.")
    if owner.store_id and owner.store_id != store.id:
        raise HTTPException(status_code=409, detail="الحساب مرتبط بمتجر آخر بالفعل.")
    other = db.query(DBVendorStore).filter(
        DBVendorStore.owner_user_id == owner.id, DBVendorStore.id != store.id
    ).first()
    if other:
        raise HTTPException(status_code=409, detail="الحساب مرتبط بمتجر آخر بالفعل.")
    old_status = store.status
    store.status = "مفعل"
    owner.role, owner.store_id = "VENDOR", store.id
    db.add(DBVendorOwnershipHistory(
        id=f"owner_history_{uuid.uuid4().hex}", store_id=store.id,
        previous_owner_user_id=store.owner_user_id, new_owner_user_id=store.owner_user_id,
        actor_user_id=principal["id"], action="store_approved",
        verification_note=f"اعتماد إداري بعد التحقق من رابط الملكية؛ الحالة السابقة: {old_status}.",
        created_at=datetime.now(timezone.utc).isoformat(),
    ))
    db.commit()
    return {"status": "approved", "store_id": store.id, "owner_user_id": owner.id}


@router.put("/{vendor_id}/owner")
def link_vendor_owner(vendor_id: str, payload: VendorOwnerLinkRequest,
    principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not store:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    owner = db.query(DBUser).filter(DBUser.id == payload.user_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="حساب المستخدم غير موجود")
    if store.owner_user_id and store.owner_user_id != owner.id:
        raise HTTPException(status_code=409, detail="المتجر مربوط بحساب آخر بالفعل؛ يلزم إجراء نقل ملكية منفصل ومراجع.")
    if owner.role.upper() not in {"CLIENT", "CUSTOMER", "VENDOR", "SELLER"}:
        raise HTTPException(status_code=409, detail="لا يمكن ربط حساب إداري كمالك متجر.")
    if owner.status != "active":
        raise HTTPException(status_code=409, detail="لا يمكن ربط حساب غير نشط.")
    other = db.query(DBVendorStore).filter(
        DBVendorStore.owner_user_id == owner.id, DBVendorStore.id != store.id
    ).first()
    if other or (owner.store_id and owner.store_id != store.id):
        raise HTTPException(status_code=409, detail="الحساب مرتبط بمتجر آخر.")
    previous_owner = store.owner_user_id
    store.owner_user_id, owner.store_id = owner.id, store.id
    if store.status == "مفعل":
        owner.role = "VENDOR"
    db.add(DBVendorOwnershipHistory(
        id=f"owner_history_{uuid.uuid4().hex}", store_id=store.id,
        previous_owner_user_id=previous_owner, new_owner_user_id=owner.id,
        actor_user_id=principal["id"], action="legacy_owner_linked",
        verification_note=payload.verification_note.strip(),
        created_at=datetime.now(timezone.utc).isoformat(),
    ))
    db.commit()
    return {"status": "linked", "store_id": store.id, "owner_user_id": owner.id}


@router.put("/{vendor_id}/delivery-fee")
def update_delivery_fee(vendor_id: str, payload: DeliveryFeeRequest,
    _principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not store:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    store.delivery_fee = payload.delivery_fee
    db.commit()
    return {"status": "updated", "delivery_fee": store.delivery_fee}

@router.put("/{vendor_id}/suspend")
def suspend_vendor(vendor_id: str, principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if store is None:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    if store.status != "مفعل":
        raise HTTPException(status_code=409, detail="لا يمكن إيقاف متجر غير مفعل.")
    store.status = "موقوف"
    db.add(DBVendorOwnershipHistory(
        id=f"owner_history_{uuid.uuid4().hex}", store_id=store.id,
        previous_owner_user_id=store.owner_user_id, new_owner_user_id=store.owner_user_id,
        actor_user_id=principal["id"], action="store_suspended",
        verification_note="إيقاف مؤقت إداري مع الاحتفاظ برابط ملكية البائع لإمكانية المراجعة أو إعادة التفعيل.",
        created_at=datetime.now(timezone.utc).isoformat(),
    ))
    db.commit()
    return {"status": "suspended", "store_id": store.id}


@router.put("/{vendor_id}/restore")
def restore_vendor(vendor_id: str, principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if store is None:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    if store.status != "موقوف":
        raise HTTPException(status_code=409, detail="المتجر ليس موقوفاً مؤقتاً.")
    owner = db.query(DBUser).filter(DBUser.id == store.owner_user_id).first() if store.owner_user_id else None
    if owner is None or owner.status != "active" or owner.store_id != store.id or owner.role.upper() not in {"VENDOR", "SELLER"}:
        raise HTTPException(status_code=409, detail="لا يمكن إعادة التفعيل قبل إصلاح رابط الملكية وتفعيل حساب البائع.")
    store.status = "مفعل"
    db.add(DBVendorOwnershipHistory(
        id=f"owner_history_{uuid.uuid4().hex}", store_id=store.id,
        previous_owner_user_id=store.owner_user_id, new_owner_user_id=store.owner_user_id,
        actor_user_id=principal["id"], action="store_restored",
        verification_note="إعادة تفعيل إدارية بعد التحقق من حالة الحساب ورابط ملكية المتجر.",
        created_at=datetime.now(timezone.utc).isoformat(),
    ))
    db.commit()
    return {"status": "restored", "store_id": store.id}


@router.put("/{vendor_id}/reject")
def reject_vendor(vendor_id: str, reason: str = "",
    principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not store:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    if store.status == "مفعل":
        raise HTTPException(status_code=409, detail="المتجر مفعل؛ استخدم الإيقاف المؤقت أولاً.")
    owner = db.query(DBUser).filter(DBUser.id == store.owner_user_id).first() if store.owner_user_id else None
    if owner and owner.store_id == store.id:
        owner.store_id, owner.role = None, "CLIENT"
    previous_status = store.status
    store.status = "مرفوض"
    db.add(DBVendorOwnershipHistory(
        id=f"owner_history_{uuid.uuid4().hex}", store_id=store.id,
        previous_owner_user_id=store.owner_user_id, new_owner_user_id=store.owner_user_id,
        actor_user_id=principal["id"], action="store_rejected",
        verification_note=(reason.strip() or f"رفض إداري للمتجر الذي كانت حالته {previous_status}.")[:1000],
        created_at=datetime.now(timezone.utc).isoformat(),
    ))
    db.commit()
    return {"status": "rejected"}
