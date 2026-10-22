from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import DBVendorStore
from schemas import VendorStoreSchema
from routers.dependencies import require_admin, require_customer

router = APIRouter(prefix="/api/vendors", tags=["vendors"])


@router.get("/", response_model=List[VendorStoreSchema])
def get_all_vendors(
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(DBVendorStore).all()


@router.post("/register", response_model=VendorStoreSchema, status_code=201)
def register_vendor(
    vendor: VendorStoreSchema,
    _principal: dict = Depends(require_customer),
    db: Session = Depends(get_db),
):
    data = vendor.dict()
    data["status"] = "قيد المراجعة"
    db_vendor = DBVendorStore(**data)
    db.add(db_vendor)
    db.commit()
    db.refresh(db_vendor)
    return db_vendor


@router.put("/{vendor_id}/approve")
def approve_vendor(
    vendor_id: str,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    vendor = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if not vendor:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")
    vendor.status = "مفعل"
    db.commit()
    return {"status": "approved"}
