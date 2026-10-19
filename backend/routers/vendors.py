from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import DBVendorStore
from schemas import VendorStoreSchema
from typing import List

router = APIRouter(prefix="/api/vendors", tags=["vendors"])

@router.get("/", response_model=List[VendorStoreSchema])
def get_all_vendors(db: Session = Depends(get_db)):
    return db.query(DBVendorStore).all()

@router.post("/register", response_model=VendorStoreSchema)
def register_vendor(vendor: VendorStoreSchema, db: Session = Depends(get_db)):
    db_vendor = DBVendorStore(**vendor.dict())
    db.add(db_vendor)
    db.commit()
    db.refresh(db_vendor)
    return db_vendor

@router.put("/{vendor_id}/approve")
def approve_vendor(vendor_id: str, db: Session = Depends(get_db)):
    vendor = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not vendor:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    vendor.status = "مفعل"
    db.commit()
    return {"status": "approved"}
