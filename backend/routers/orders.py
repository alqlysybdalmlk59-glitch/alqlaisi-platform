import json, uuid, math
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from models import DBOrder, DBProduct, DBUser, DBVendorStore
from schemas import CheckoutRequest, OrderSchema
from routers.dependencies import get_db, get_current_principal, require_admin, require_customer, require_seller_or_admin

router = APIRouter(prefix="/api/orders", tags=["orders"])
DELIVERED, CANCELLED = "تم التسليم", "ملغي"
VALID_ORDER_STATUSES = {"بانتظار القبول", "قيد التجهيز", "جاهز للتوصيل", "قيد التوصيل", DELIVERED, CANCELLED}
SELLER_TRANSITIONS = {"بانتظار القبول": {"قيد التجهيز", CANCELLED},
    "قيد التجهيز": {"جاهز للتوصيل", CANCELLED}, "جاهز للتوصيل": set(),
    "قيد التوصيل": set(), DELIVERED: set(), CANCELLED: set()}

def create_orders(payload: CheckoutRequest, principal: dict, db: Session) -> list[DBOrder]:
    if payload.payment_method not in {"cash_on_delivery", "الدفع عند الاستلام"}:
        raise HTTPException(status_code=422, detail="طريقة الدفع المتاحة حالياً هي الدفع عند الاستلام فقط.")
    quantities: dict[str, int] = defaultdict(int)
    for item in payload.items:
        quantities[item.product_id] += item.quantity
        if quantities[item.product_id] > 100:
            raise HTTPException(status_code=422, detail="الكمية الإجمالية للمنتج الواحد تتجاوز الحد المسموح.")
    ids = list(quantities)
    products = db.query(DBProduct).filter(DBProduct.id.in_(ids)).all()
    by_id = {p.id: p for p in products}
    if len(by_id) != len(ids):
        raise HTTPException(status_code=409, detail="أحد المنتجات لم يعد موجوداً؛ حدّث السلة.")
    groups: dict[str, list[dict]] = defaultdict(list)
    subtotals: dict[str, Decimal] = defaultdict(lambda: Decimal("0.00"))
    stores: dict[str, DBVendorStore] = {}
    for product_id, quantity in quantities.items():
        product = by_id[product_id]
        if (
            product.review_status != "منشور"
            or not product.is_available
            or not math.isfinite(float(product.price))
            or product.price <= 0
        ):
            raise HTTPException(status_code=409, detail=f"المنتج «{product.title}» غير متاح للطلب حالياً.")
        store = db.query(DBVendorStore).filter(DBVendorStore.id == product.vendor_id).first()
        if store is None or store.status != "مفعل":
            raise HTTPException(status_code=409, detail=f"متجر المنتج «{product.title}» غير معتمد حالياً.")
        owner = db.query(DBUser).filter(DBUser.id == store.owner_user_id).first() if store.owner_user_id else None
        if (
            owner is None
            or owner.status != "active"
            or owner.role.upper() not in {"VENDOR", "SELLER"}
            or owner.store_id != store.id
        ):
            raise HTTPException(status_code=409, detail=f"مالك متجر المنتج «{product.title}» غير نشط أو غير مرتبط بصورة صحيحة.")
        try:
            raw_price = Decimal(str(product.price))
            if not raw_price.is_finite() or raw_price <= 0:
                raise InvalidOperation
            unit_price = raw_price.quantize(Decimal("0.01"))
        except InvalidOperation:
            raise HTTPException(status_code=409, detail="سعر أحد المنتجات غير صالح.")
        line_total = (unit_price * quantity).quantize(Decimal("0.01"))
        groups[store.id].append({"product_id": product.id, "title": product.title,
            "quantity": quantity, "unit_price": float(unit_price), "line_total": float(line_total)})
        subtotals[store.id] += line_total
        stores[store.id] = store
    address = f"المستلم: {payload.recipient_name.strip()}\nالهاتف: {payload.phone.strip()}\nالعنوان: {payload.delivery_address.strip()}"
    if payload.notes.strip():
        address += f"\nملاحظات: {payload.notes.strip()}"
    result = []
    for store_id, items in groups.items():
        store = stores[store_id]
        fee = Decimal(str(store.delivery_fee or 0)).quantize(Decimal("0.01"))
        subtotal = subtotals[store_id].quantize(Decimal("0.01"))
        if not fee.is_finite() or fee < 0:
            raise HTTPException(status_code=409, detail="رسوم توصيل غير صالحة.")
        order = DBOrder(id=f"order_{uuid.uuid4().hex}", client_id=principal["id"],
            client_name=principal["name"], vendor_id=store.id, vendor_name=store.store_name,
            items_json=json.dumps(items, ensure_ascii=False, separators=(",", ":")),
            items_price=float(subtotal), delivery_fee=float(fee), total_price=float(subtotal + fee),
            payment_method="الدفع عند الاستلام", address=address, status="بانتظار القبول",
            date=datetime.now(timezone.utc).isoformat())
        db.add(order)
        result.append(order)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=400, detail="تعذر إنشاء الطلب؛ لم يتم اعتماد أي طلب.")
    for order in result:
        db.refresh(order)
    return result

@router.post("/checkout", response_model=list[OrderSchema], status_code=201)
def checkout(payload: CheckoutRequest, principal: dict = Depends(require_customer), db: Session = Depends(get_db)):
    return create_orders(payload, principal, db)

@router.get("/", response_model=list[OrderSchema])
def get_all_orders(_principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    return db.query(DBOrder).order_by(DBOrder.date.desc()).all()


@router.get("/client/{client_id}", response_model=list[OrderSchema])
def get_client_orders(client_id: str, principal: dict = Depends(get_current_principal), db: Session = Depends(get_db)):
    if principal["role"] != "ADMIN" and principal["id"] != client_id:
        raise HTTPException(status_code=403, detail="لا يمكنك الاطلاع على طلبات حساب آخر.")
    return db.query(DBOrder).filter(DBOrder.client_id == client_id).order_by(DBOrder.date.desc()).all()

@router.get("/vendor/{vendor_id}", response_model=list[OrderSchema])
def get_vendor_orders(vendor_id: str, principal: dict = Depends(require_seller_or_admin), db: Session = Depends(get_db)):
    if principal["role"] != "ADMIN" and principal.get("store_id") != vendor_id:
        raise HTTPException(status_code=403, detail="لا يمكنك الاطلاع على طلبات متجر آخر.")
    return db.query(DBOrder).filter(DBOrder.vendor_id == vendor_id).order_by(DBOrder.date.desc()).all()

@router.put("/{order_id}/status")
def update_order_status(order_id: str, status: str, principal: dict = Depends(require_seller_or_admin), db: Session = Depends(get_db)):
    order = db.query(DBOrder).filter(DBOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    if principal["role"] != "ADMIN" and principal.get("store_id") != order.vendor_id:
        raise HTTPException(status_code=403, detail="لا يمكنك تعديل طلب متجر آخر.")
    if status not in VALID_ORDER_STATUSES:
        raise HTTPException(status_code=422, detail="حالة الطلب غير معتمدة.")
    if order.status in {DELIVERED, CANCELLED}:
        raise HTTPException(status_code=409, detail="الطلب منتهٍ ولا يمكن تغيير حالته.")
    if principal["role"] != "ADMIN" and status not in SELLER_TRANSITIONS.get(order.status, set()):
        raise HTTPException(status_code=409, detail="انتقال حالة الطلب غير مسموح للبائع.")
    order.status = status
    db.commit()
    return {"status": "updated", "new_status": status}
