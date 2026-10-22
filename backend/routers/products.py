from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import DBProduct
from schemas import ProductSchema
from routers.dependencies import require_admin, require_customer

router = APIRouter(prefix="/api/products", tags=["products"])


@router.get("/", response_model=List[ProductSchema])
def get_published_products(db: Session = Depends(get_db)):
    return db.query(DBProduct).filter(
        DBProduct.review_status == "منشور",
        DBProduct.is_available.is_(True),
    ).all()


@router.get("/vendor/{vendor_id}", response_model=List[ProductSchema])
def get_vendor_products(
    vendor_id: str,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    # Until a trusted seller-to-store relationship exists, arbitrary store IDs
    # are visible only to administrators.
    return db.query(DBProduct).filter(DBProduct.vendor_id == vendor_id).all()


@router.post("/", response_model=ProductSchema, status_code=201)
def create_product(
    product: ProductSchema,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    # Fail closed until seller ownership is represented in the database.
    data = product.dict()
    data["review_status"] = "قيد المراجعة"
    data["is_available"] = False
    db_product = DBProduct(**data)
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product


@router.put("/{product_id}/availability")
def toggle_availability(
    product_id: str,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    product = db.query(DBProduct).filter(DBProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    if product.review_status != "منشور":
        raise HTTPException(status_code=409, detail="لا يمكن تفعيل منتج قبل اعتماد الإدارة.")
    product.is_available = not product.is_available
    db.commit()
    return {"status": "success", "is_available": product.is_available}


@router.put("/{product_id}/approve")
def approve_product(
    product_id: str,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    product = db.query(DBProduct).filter(DBProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    product.review_status = "منشور"
    db.commit()
    return {"status": "approved"}
