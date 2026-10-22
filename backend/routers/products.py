import math
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from models import DBProduct, DBUser, DBVendorStore
from schemas import ProductApprovalRequest, ProductAvailabilityRequest, ProductCreateRequest, ProductSchema
from routers.dependencies import get_db, require_admin, require_seller_or_admin

router = APIRouter(prefix="/api/products", tags=["products"])

def _require_store_access(store_id: str, principal: dict) -> None:
    if principal["role"] == "ADMIN":
        return
    if principal["role"] not in {"VENDOR", "SELLER"} or principal.get("store_id") != store_id:
        raise HTTPException(status_code=403, detail="لا يمكنك إدارة منتجات متجر آخر.")

@router.get("/", response_model=list[ProductSchema])
def get_published_products(db: Session = Depends(get_db)):
    # Products from rejected stores or suspended owners must not stay discoverable.
    return (
        db.query(DBProduct)
        .join(DBVendorStore, DBProduct.vendor_id == DBVendorStore.id)
        .join(DBUser, DBVendorStore.owner_user_id == DBUser.id)
        .filter(
            DBProduct.review_status == "منشور",
            DBProduct.is_available.is_(True),
            DBProduct.price > 0,
            DBVendorStore.status == "مفعل",
            DBUser.status == "active",
            DBUser.role.in_(["VENDOR", "SELLER"]),
            DBUser.store_id == DBVendorStore.id,
        )
        .all()
    )

@router.get("/admin/review", response_model=list[ProductSchema])
def get_products_for_admin_review(status: str = "قيد المراجعة",
    _principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    query = db.query(DBProduct)
    if status != "all":
        query = query.filter(DBProduct.review_status == status)
    return query.order_by(DBProduct.title.asc()).all()


@router.get("/vendor/{vendor_id}", response_model=list[ProductSchema])
def get_vendor_products(vendor_id: str, principal: dict = Depends(require_seller_or_admin),
    db: Session = Depends(get_db)):
    _require_store_access(vendor_id, principal)
    return db.query(DBProduct).filter(DBProduct.vendor_id == vendor_id).all()

@router.post("/", response_model=ProductSchema, status_code=201)
def create_product(payload: ProductCreateRequest, principal: dict = Depends(require_seller_or_admin),
    db: Session = Depends(get_db)):
    if principal["role"] == "ADMIN":
        store_id = payload.vendor_id
        if not store_id:
            raise HTTPException(status_code=422, detail="حدد المتجر الذي سيُضاف إليه المنتج.")
    else:
        store_id = principal.get("store_id")
        if not store_id:
            raise HTTPException(status_code=403, detail="لا يوجد متجر معتمد مرتبط بهذا الحساب.")
    store = db.query(DBVendorStore).filter(DBVendorStore.id == store_id).first()
    if store is None or store.status != "مفعل":
        raise HTTPException(status_code=409, detail="لا يمكن إضافة منتجات إلى متجر غير معتمد.")
    _require_store_access(store.id, principal)
    product = DBProduct(id=f"product_{uuid.uuid4().hex}", title=payload.title.strip(),
        description=payload.description.strip(), price=0.0, image_url=payload.image_url.strip(),
        vendor_id=store.id, vendor_name=store.store_name, category=payload.category.strip(),
        is_available=False, review_status="قيد المراجعة", admin_notes="")
    db.add(product)
    db.commit()
    db.refresh(product)
    return product

@router.put("/{product_id}/availability")
def set_product_availability(product_id: str, payload: ProductAvailabilityRequest | None = None,
    principal: dict = Depends(require_seller_or_admin), db: Session = Depends(get_db)):
    product = db.query(DBProduct).filter(DBProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    _require_store_access(product.vendor_id, principal)
    if product.review_status != "منشور" or not math.isfinite(float(product.price)) or product.price <= 0:
        raise HTTPException(status_code=409, detail="لا يمكن تفعيل منتج قبل اعتماد الإدارة وتحديد سعره.")
    product.is_available = payload.is_available if payload is not None else not product.is_available
    db.commit()
    return {"status": "success", "is_available": product.is_available}

@router.put("/{product_id}/approve")
def approve_product(product_id: str, payload: ProductApprovalRequest,
    _principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    product = db.query(DBProduct).filter(DBProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    product.admin_notes = payload.admin_notes.strip()
    product.review_status = "منشور" if payload.approved else "مرفوض"
    product.price = payload.sale_price if payload.approved else 0.0
    product.is_available = False
    db.commit()
    return {"status": "approved" if payload.approved else "rejected", "price": product.price}

@router.put("/{product_id}/reject")
def reject_product(product_id: str, notes: str = "", _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db)):
    product = db.query(DBProduct).filter(DBProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    product.review_status, product.is_available = "مرفوض", False
    product.admin_notes = notes[:2000]
    db.commit()
    return {"status": "rejected"}
