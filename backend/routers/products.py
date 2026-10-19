from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import DBProduct
from schemas import ProductSchema
from typing import List

router = APIRouter(prefix="/api/products", tags=["products"])

@router.get("/", response_model=List[ProductSchema])
def get_published_products(db: Session = Depends(get_db)):
    return db.query(DBProduct).filter(DBProduct.review_status == "منشور").all()

@router.get("/vendor/{vendor_id}", response_model=List[ProductSchema])
def get_vendor_products(vendor_id: str, db: Session = Depends(get_db)):
    return db.query(DBProduct).filter(DBProduct.vendor_id == vendor_id).all()

@router.post("/", response_model=ProductSchema)
def create_product(product: ProductSchema, db: Session = Depends(get_db)):
    db_product = DBProduct(**product.dict())
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product

@router.put("/{product_id}/availability")
def toggle_availability(product_id: str, db: Session = Depends(get_db)):
    product = db.query(DBProduct).filter(DBProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    product.is_available = not product.is_available
    db.commit()
    return {"status": "success", "is_available": product.is_available}

@router.put("/{product_id}/approve")
def approve_product(product_id: str, db: Session = Depends(get_db)):
    product = db.query(DBProduct).filter(DBProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    product.review_status = "منشور"
    db.commit()
    return {"status": "approved"}
