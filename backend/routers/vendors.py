import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from models import DBUser, DBVendorStore
from schemas import DeliveryFeeRequest, VendorApplicationRequest, VendorOwnerLinkRequest, VendorStoreSchema
from routers.dependencies import get_db, require_admin, require_customer

router = APIRouter(prefix="/api/vendors", tags=["vendors"])

@router.get("/", response_model=list[VendorStoreSchema])
def get_all_vendors(_principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    return db.query(DBVendorStore).order_by(DBVendorStore.store_name.asc()).all()

@router.get("/mine", response_model=VendorStoreSchema | None)
def get_my_vendor_store(principal: dict = Depends(__import__("routers.dependencies", fromlist=["get_current_principal"]).get_current_principal),
    db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.owner_user_id == principal["id"]).first()
    if store is None and principal.get("store_id"):
        store = db.query(DBVendorStore).filter(DBVendorStore.id == principal["store_id"]).first()
    return store


@router.get("/public", response_model=list[VendorStoreSchema])
def get_public_vendors(db: Session = Depends(get_db)):
    return db.query(DBVendorStore).filter(DBVendorStore.status == "مفعل").order_by(
        DBVendorStore.store_name.asc()).all()

@router.post("/register", response_model=VendorStoreSchema, status_code=201)
def register_vendor(application: VendorApplicationRequest,
    principal: dict = Depends(require_customer), db: Session = Depends(get_db)):
    if db.query(DBVendorStore).filter(DBVendorStore.owner_user_id == principal["id"]).first():
        raise HTTPException(status_code=409, detail="لديك طلب متجر مسجل مسبقاً.")
    user = db.query(DBUser).filter(DBUser.id == principal["id"]).first()
    if user is None:
        raise HTTPException(status_code=401, detail="الحساب غير موجود.")
    store = DBVendorStore(id=f"store_{uuid.uuid4().hex}",
        store_name=application.store_name.strip(), owner_name=user.name,
        phone=application.phone.strip(), description=application.description.strip(),
        status="قيد المراجعة", admin_notes="", owner_user_id=str(user.id), delivery_fee=15.0)
    db.add(store)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=409, detail="تعذر تسجيل المتجر. تحقق من عدم وجود طلب سابق.")
    db.refresh(store)
    return store

@router.put("/{vendor_id}/approve")
def approve_vendor(vendor_id: str, _principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not store:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    if not store.owner_user_id:
        raise HTTPException(status_code=409, detail="هذا المتجر غير مربوط بحساب؛ اربط حساب المالك أولاً.")
    owner = db.query(DBUser).filter(DBUser.id == store.owner_user_id).first()
    if owner is None:
        raise HTTPException(status_code=409, detail="حساب مالك المتجر غير موجود.")
    if owner.status != "active":
        raise HTTPException(status_code=409, detail="لا يمكن اعتماد متجر حسابه غير نشط.")
    if owner.store_id and owner.store_id != store.id:
        raise HTTPException(status_code=409, detail="الحساب مرتبط بمتجر آخر بالفعل.")
    other = db.query(DBVendorStore).filter(
        DBVendorStore.owner_user_id == owner.id, DBVendorStore.id != store.id).first()
    if other:
        raise HTTPException(status_code=409, detail="الحساب مرتبط بمتجر آخر بالفعل.")
    store.status = "مفعل"
    owner.role, owner.store_id = "VENDOR", store.id
    db.commit()
    return {"status": "approved", "store_id": store.id, "owner_user_id": owner.id}

@router.put("/{vendor_id}/owner")
def link_vendor_owner(vendor_id: str, payload: VendorOwnerLinkRequest,
    _principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not store:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    owner = db.query(DBUser).filter(DBUser.id == payload.user_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="حساب المستخدم غير موجود")
    if owner.status != "active":
        raise HTTPException(status_code=409, detail="لا يمكن ربط حساب غير نشط.")
    other = db.query(DBVendorStore).filter(
        DBVendorStore.owner_user_id == owner.id, DBVendorStore.id != store.id).first()
    if other or (owner.store_id and owner.store_id != store.id):
        raise HTTPException(status_code=409, detail="الحساب مرتبط بمتجر آخر.")
    store.owner_user_id, owner.store_id = owner.id, store.id
    if store.status == "مفعل":
        owner.role = "VENDOR"
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

@router.put("/{vendor_id}/reject")
def reject_vendor(vendor_id: str, _principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not store:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    owner = db.query(DBUser).filter(DBUser.id == store.owner_user_id).first() if store.owner_user_id else None
    if owner and owner.store_id == store.id:
        owner.store_id, owner.role = None, "CLIENT"
    store.status = "مرفوض"
    db.commit()
    return {"status": "rejected"}
