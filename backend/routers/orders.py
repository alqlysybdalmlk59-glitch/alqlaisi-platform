from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import DBOrder
from schemas import OrderSchema
from routers.dependencies import get_current_principal, require_admin, require_customer

router = APIRouter(prefix="/api/orders", tags=["orders"])


@router.post("/checkout", response_model=List[OrderSchema])
def checkout(
    orders: List[OrderSchema],
    principal: dict = Depends(require_customer),
    db: Session = Depends(get_db),
):
    if not orders:
        raise HTTPException(status_code=422, detail="السلة فارغة.")
    created_orders = []
    for order_data in orders:
        data = order_data.dict()
        # Identity and workflow state must come from the authenticated server context.
        data["client_id"] = principal["id"]
        data["client_name"] = principal["name"]
        data["status"] = "بانتظار القبول"
        data["payment_method"] = "الدفع عند الاستلام"
        db_order = DBOrder(**data)
        db.add(db_order)
        created_orders.append(db_order)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=400, detail="تعذر إنشاء الطلب؛ تحقق من البيانات.")
    for order in created_orders:
        db.refresh(order)
    return created_orders


@router.get("/client/{client_id}", response_model=List[OrderSchema])
def get_client_orders(
    client_id: str,
    principal: dict = Depends(get_current_principal),
    db: Session = Depends(get_db),
):
    if principal["role"] not in {"ADMIN"} and principal["id"] != client_id:
        raise HTTPException(status_code=403, detail="لا يمكنك الاطلاع على طلبات حساب آخر.")
    return db.query(DBOrder).filter(DBOrder.client_id == client_id).all()


@router.get("/vendor/{vendor_id}", response_model=List[OrderSchema])
def get_vendor_orders(
    vendor_id: str,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    # Seller-to-store ownership cannot yet be checked because the legacy schema
    # has no trusted user_id -> vendor_store_id relationship. Admin-only is fail-closed.
    return db.query(DBOrder).filter(DBOrder.vendor_id == vendor_id).all()


@router.put("/{order_id}/status")
def update_order_status(
    order_id: str,
    status: str,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    order = db.query(DBOrder).filter(DBOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    allowed = {"بانتظار القبول", "قيد التجهيز", "جاهز للتوصيل", "قيد التوصيل", "تم التسليم", "ملغي"}
    if status not in allowed:
        raise HTTPException(status_code=422, detail="حالة الطلب غير معتمدة.")
    order.status = status
    db.commit()
    return {"status": "updated", "new_status": status}
