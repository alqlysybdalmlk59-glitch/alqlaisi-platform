from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import DBOrder
from schemas import OrderSchema
from typing import List

router = APIRouter(prefix="/api/orders", tags=["orders"])

@router.post("/checkout", response_model=List[OrderSchema])
def checkout(orders: List[OrderSchema], db: Session = Depends(get_db)):
    created_orders = []
    for order_data in orders:
        db_order = DBOrder(**order_data.dict())
        db.add(db_order)
        created_orders.append(db_order)
    db.commit()
    return created_orders

@router.get("/client/{client_id}", response_model=List[OrderSchema])
def get_client_orders(client_id: str, db: Session = Depends(get_db)):
    return db.query(DBOrder).filter(DBOrder.client_id == client_id).all()

@router.get("/vendor/{vendor_id}", response_model=List[OrderSchema])
def get_vendor_orders(vendor_id: str, db: Session = Depends(get_db)):
    return db.query(DBOrder).filter(DBOrder.vendor_id == vendor_id).all()

@router.put("/{order_id}/status")
def update_order_status(order_id: str, status: str, db: Session = Depends(get_db)):
    order = db.query(DBOrder).filter(DBOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    order.status = status
    db.commit()
    return {"status": "updated", "new_status": status}
