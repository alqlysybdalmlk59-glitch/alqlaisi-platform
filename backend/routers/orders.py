import json, uuid, math
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from models import DBOrder, DBOrderStatusHistory, DBProduct, DBProductReview, DBUser, DBVendorStore
from schemas import CheckoutRequest, DeliveryAssignmentRequest, OrderSchema, OrderStatusHistorySchema, ProductReviewCreateRequest, ProductReviewSchema
from routers.dependencies import get_db, get_current_principal, require_admin, require_customer, require_seller_or_admin

router = APIRouter(prefix="/api/orders", tags=["orders"])
DELIVERED, CANCELLED = "تم التسليم", "ملغي"
VALID_ORDER_STATUSES = {"بانتظار القبول", "قيد التجهيز", "جاهز للتوصيل", "قيد التوصيل", DELIVERED, CANCELLED}
SELLER_TRANSITIONS = {"بانتظار القبول": {"قيد التجهيز", CANCELLED},
    "قيد التجهيز": {"جاهز للتوصيل", CANCELLED}, "جاهز للتوصيل": set(),
    "قيد التوصيل": set(), DELIVERED: set(), CANCELLED: set()}
# Admins manage the operational lifecycle too, but a ready order must pass through
# the audited dispatch endpoint before it can enter transit.
ADMIN_TRANSITIONS = {
    "بانتظار القبول": {"قيد التجهيز", CANCELLED},
    "قيد التجهيز": {"جاهز للتوصيل", CANCELLED},
    "جاهز للتوصيل": {CANCELLED},
    "قيد التوصيل": {DELIVERED},
    DELIVERED: set(),
    CANCELLED: set(),
}

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
        db.add(DBOrderStatusHistory(
            id=f"order_history_{uuid.uuid4().hex}",
            order_id=order.id,
            old_status=None,
            new_status=order.status,
            changed_by_user_id=principal["id"],
            changed_by_role=principal["role"],
            note="تم إنشاء الطلب",
            created_at=order.date,
        ))
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

@router.get("/vendor/{vendor_id}/summary")
def get_vendor_sales_summary(
    vendor_id: str,
    principal: dict = Depends(require_seller_or_admin),
    db: Session = Depends(get_db),
):
    if principal["role"] != "ADMIN" and principal.get("store_id") != vendor_id:
        raise HTTPException(status_code=403, detail="لا يمكنك الاطلاع على تقارير متجر آخر.")
    store = db.query(DBVendorStore).filter(DBVendorStore.id == vendor_id).first()
    if store is None:
        raise HTTPException(status_code=404, detail="المتجر غير موجود")

    orders = db.query(DBOrder).filter(DBOrder.vendor_id == vendor_id).all()
    status_counts: dict[str, int] = defaultdict(int)
    delivered_gross = Decimal("0.00")
    pending_statuses = {"بانتظار القبول", "قيد التجهيز", "جاهز للتوصيل", "قيد التوصيل"}
    pending_count = 0
    cancelled_count = 0

    for order in orders:
        status_counts[order.status] += 1
        if order.status in pending_statuses:
            pending_count += 1
        elif order.status == CANCELLED:
            cancelled_count += 1
        elif order.status == DELIVERED:
            try:
                value = Decimal(str(order.total_price))
                if not value.is_finite() or value < 0:
                    raise InvalidOperation
                delivered_gross += value
            except InvalidOperation:
                raise HTTPException(
                    status_code=409,
                    detail="توجد قيمة طلب غير صالحة في البيانات المالية؛ راجع سجل الطلب.",
                )

    return {
        "store_id": store.id,
        "store_name": store.store_name,
        "currency": "YER",
        "order_count": len(orders),
        "pending_count": pending_count,
        "delivered_count": status_counts[DELIVERED],
        "cancelled_count": cancelled_count,
        "delivered_gross_value": float(delivered_gross.quantize(Decimal("0.01"))),
        "status_counts": dict(status_counts),
        "commission_configured": False,
        "commission_percent": None,
        "commission_value": None,
        "commission_note": "لم تُحدد نسبة العمولة بعد؛ لذلك لا يتم احتساب عمولة أو تسوية مالية.",
    }


@router.get("/notifications/mine")
def get_my_order_notifications(
    principal: dict = Depends(require_customer),
    db: Session = Depends(get_db),
):
    """Return persisted order lifecycle events for the authenticated customer only."""
    rows = (
        db.query(DBOrderStatusHistory, DBOrder)
        .join(DBOrder, DBOrder.id == DBOrderStatusHistory.order_id)
        .filter(DBOrder.client_id == principal["id"])
        .order_by(DBOrderStatusHistory.created_at.desc(), DBOrderStatusHistory.id.desc())
        .limit(100)
        .all()
    )
    return [
        {
            "id": event.id,
            "order_id": order.id,
            "old_status": event.old_status,
            "status": event.new_status,
            "note": event.note or "",
            "created_at": event.created_at,
            "vendor_name": order.vendor_name,
            "total_price": order.total_price,
        }
        for event, order in rows
    ]


@router.get("/{order_id}/reviews", response_model=list[ProductReviewSchema])
def get_order_reviews(
    order_id: str,
    principal: dict = Depends(get_current_principal),
    db: Session = Depends(get_db),
):
    order = db.query(DBOrder).filter(DBOrder.id == order_id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="الطلب غير موجود.")
    if principal["role"] != "ADMIN" and not (
        principal["role"] in {"CLIENT", "CUSTOMER"} and principal["id"] == order.client_id
    ):
        raise HTTPException(status_code=403, detail="لا يمكنك الاطلاع على تقييمات هذا الطلب.")
    return db.query(DBProductReview).filter(
        DBProductReview.order_id == order_id
    ).order_by(DBProductReview.created_at.asc()).all()


@router.post("/{order_id}/reviews", response_model=ProductReviewSchema, status_code=201)
def create_order_product_review(
    order_id: str,
    payload: ProductReviewCreateRequest,
    principal: dict = Depends(require_customer),
    db: Session = Depends(get_db),
):
    order = db.query(DBOrder).filter(
        DBOrder.id == order_id,
        DBOrder.client_id == principal["id"],
    ).first()
    if order is None:
        raise HTTPException(status_code=404, detail="الطلب غير موجود لهذا الحساب.")
    if order.status != DELIVERED:
        raise HTTPException(status_code=409, detail="لا يمكن تقييم المنتج قبل تسليم الطلب فعلياً.")

    try:
        items = json.loads(order.items_json)
    except (TypeError, json.JSONDecodeError):
        raise HTTPException(status_code=409, detail="تعذر التحقق من المنتجات المسجلة في الطلب.")
    if not isinstance(items, list):
        raise HTTPException(status_code=409, detail="تفاصيل منتجات الطلب غير صالحة.")
    product_ids = {
        str(item.get("product_id"))
        for item in items
        if isinstance(item, dict) and item.get("product_id")
    }
    if payload.product_id not in product_ids:
        raise HTTPException(status_code=403, detail="لا يمكنك تقييم منتج لم تشتره في هذا الطلب.")

    product = db.query(DBProduct).filter(
        DBProduct.id == payload.product_id,
        DBProduct.vendor_id == order.vendor_id,
    ).first()
    if product is None:
        raise HTTPException(status_code=409, detail="تعذر التحقق من المنتج المرتبط بهذا الطلب.")
    if db.query(DBProductReview).filter(
        DBProductReview.order_id == order_id,
        DBProductReview.product_id == payload.product_id,
    ).first():
        raise HTTPException(status_code=409, detail="سبق أن قيّمت هذا المنتج في هذا الطلب.")

    user = db.query(DBUser).filter(DBUser.id == principal["id"]).first()
    if user is None or user.status != "active":
        raise HTTPException(status_code=403, detail="الحساب غير نشط.")
    # Public reviews show only a first-name display label, not email/phone/account ID.
    reviewer_name = (user.name or "عميل").strip().split()[0] or "عميل"
    review = DBProductReview(
        id=f"review_{uuid.uuid4().hex}",
        product_id=product.id,
        order_id=order.id,
        client_id=user.id,
        reviewer_name=reviewer_name,
        rating=payload.rating,
        comment=payload.comment.strip(),
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(review)
    try:
        db.commit()
        db.refresh(review)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="سبق أن قيّمت هذا المنتج في هذا الطلب.")
    return review


@router.get("/{order_id}/history", response_model=list[OrderStatusHistorySchema])
def get_order_status_history(
    order_id: str,
    principal: dict = Depends(get_current_principal),
    db: Session = Depends(get_db),
):
    order = db.query(DBOrder).filter(DBOrder.id == order_id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    role = principal["role"]
    can_view = (
        role == "ADMIN"
        or (role in {"CLIENT", "CUSTOMER"} and principal["id"] == order.client_id)
        or (role in {"VENDOR", "SELLER"} and principal.get("store_id") == order.vendor_id)
    )
    if not can_view:
        raise HTTPException(status_code=403, detail="لا يمكنك الاطلاع على سجل هذا الطلب.")
    return db.query(DBOrderStatusHistory).filter(
        DBOrderStatusHistory.order_id == order_id
    ).order_by(DBOrderStatusHistory.created_at.asc(), DBOrderStatusHistory.id.asc()).all()


@router.put("/{order_id}/dispatch")
def dispatch_order(
    order_id: str,
    payload: DeliveryAssignmentRequest,
    principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Assign or reassign an internal delivery agent, recording the action in order history."""
    order = db.query(DBOrder).filter(DBOrder.id == order_id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    if order.status not in {"جاهز للتوصيل", "قيد التوصيل"}:
        raise HTTPException(status_code=409, detail="لا يمكن إسناد التوصيل إلا لطلب جاهز للتوصيل أو قيد التوصيل.")

    agent_name = payload.delivery_agent_name.strip()
    agent_phone = payload.delivery_agent_phone.strip()
    if len(agent_name) < 2:
        raise HTTPException(status_code=422, detail="أدخل اسم موظف التوصيل كاملاً.")
    now = datetime.now(timezone.utc).isoformat()
    previous_status = order.status
    previous_agent = order.delivery_agent_name
    is_reassignment = previous_status == "قيد التوصيل" and bool(previous_agent)
    order.delivery_agent_name = agent_name
    order.delivery_agent_phone = agent_phone
    order.delivery_notes = payload.delivery_notes.strip()
    order.delivery_assigned_at = now
    if previous_status == "جاهز للتوصيل":
        order.status = "قيد التوصيل"
    note_prefix = "إعادة إسناد التوصيل" if is_reassignment else "إسناد التوصيل الداخلي"
    note = f"{note_prefix} إلى {agent_name} ({agent_phone})."
    if is_reassignment:
        note = f"{note_prefix} من {previous_agent} إلى {agent_name} ({agent_phone})."
    if order.delivery_notes:
        note += f" ملاحظات: {order.delivery_notes}"
    db.add(DBOrderStatusHistory(
        id=f"order_history_{uuid.uuid4().hex}",
        order_id=order.id,
        old_status=previous_status,
        new_status=order.status,
        changed_by_user_id=principal["id"],
        changed_by_role=principal["role"],
        note=note,
        created_at=now,
    ))
    db.commit()
    db.refresh(order)
    return {
        "status": "dispatched",
        "order": OrderSchema.model_validate(order).model_dump(),
    }


@router.put("/{order_id}/status")
def update_order_status(order_id: str, status: str, principal: dict = Depends(require_seller_or_admin), db: Session = Depends(get_db)):
    order = db.query(DBOrder).filter(DBOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    if principal["role"] != "ADMIN" and principal.get("store_id") != order.vendor_id:
        raise HTTPException(status_code=403, detail="لا يمكنك تعديل طلب متجر آخر.")
    if status not in VALID_ORDER_STATUSES:
        raise HTTPException(status_code=422, detail="حالة الطلب غير معتمدة.")
    if status == order.status:
        return {"status": "unchanged", "new_status": status}
    if order.status in {DELIVERED, CANCELLED}:
        raise HTTPException(status_code=409, detail="الطلب منتهٍ ولا يمكن تغيير حالته.")
    transitions = ADMIN_TRANSITIONS if principal["role"] == "ADMIN" else SELLER_TRANSITIONS
    if status not in transitions.get(order.status, set()):
        if status == "قيد التوصيل":
            raise HTTPException(status_code=409, detail="يجب إسناد موظف التوصيل من لوحة الإدارة قبل بدء التوصيل.")
        raise HTTPException(status_code=409, detail="انتقال حالة الطلب غير مسموح من الحالة الحالية.")
    if status == DELIVERED:
        if principal["role"] != "ADMIN":
            raise HTTPException(status_code=403, detail="تأكيد التسليم النهائي من صلاحية الإدارة الداخلية فقط.")
        if not order.delivery_agent_name or not order.delivery_agent_phone:
            raise HTTPException(status_code=409, detail="لا يمكن تأكيد التسليم قبل إسناد موظف توصيل.")
        order.delivery_delivered_at = datetime.now(timezone.utc).isoformat()
    previous_status = order.status
    order.status = status
    db.add(DBOrderStatusHistory(
        id=f"order_history_{uuid.uuid4().hex}",
        order_id=order.id,
        old_status=previous_status,
        new_status=status,
        changed_by_user_id=principal["id"],
        changed_by_role=principal["role"],
        note="تحديث حالة الطلب",
        created_at=datetime.now(timezone.utc).isoformat(),
    ))
    db.commit()
    return {"status": "updated", "new_status": status}
