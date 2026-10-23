"""Authenticated CRUD endpoints for each customer's saved delivery addresses."""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from models import DBCustomerAddress
from routers.dependencies import get_db, require_customer
from schemas import CustomerAddressRequest, CustomerAddressSchema

router = APIRouter(prefix="/api/customer", tags=["customer addresses"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _clear_default(db: Session, user_id: str, except_id: str | None = None) -> None:
    rows = db.query(DBCustomerAddress).filter(DBCustomerAddress.user_id == user_id).all()
    for row in rows:
        if row.id != except_id:
            row.is_default = False


@router.get("/addresses", response_model=list[CustomerAddressSchema])
def list_my_addresses(principal: dict = Depends(require_customer), db: Session = Depends(get_db)):
    return (
        db.query(DBCustomerAddress)
        .filter(DBCustomerAddress.user_id == principal["id"])
        .order_by(DBCustomerAddress.is_default.desc(), DBCustomerAddress.created_at.asc())
        .all()
    )


@router.post("/addresses", response_model=CustomerAddressSchema, status_code=201)
def create_or_reuse_address(
    payload: CustomerAddressRequest,
    principal: dict = Depends(require_customer),
    db: Session = Depends(get_db),
):
    """Save an address; repeating the same phone/address updates the existing row instead of duplicating it."""
    user_id = principal["id"]
    phone, address_text = payload.phone.strip(), payload.address.strip()
    existing = db.query(DBCustomerAddress).filter(
        DBCustomerAddress.user_id == user_id,
        DBCustomerAddress.phone == phone,
        DBCustomerAddress.address == address_text,
    ).first()
    address_count = db.query(DBCustomerAddress).filter(DBCustomerAddress.user_id == user_id).count()
    now = _now()
    make_default = payload.is_default or address_count == 0
    if existing is not None:
        existing.label = payload.label.strip()
        existing.recipient_name = payload.recipient_name.strip()
        existing.notes = payload.notes.strip()
        existing.updated_at = now
        if make_default:
            _clear_default(db, user_id, except_id=existing.id)
            existing.is_default = True
        db.commit()
        db.refresh(existing)
        return existing

    if make_default:
        _clear_default(db, user_id)
    row = DBCustomerAddress(
        id=f"address_{uuid.uuid4().hex}",
        user_id=user_id,
        label=payload.label.strip(),
        recipient_name=payload.recipient_name.strip(),
        phone=phone,
        address=address_text,
        notes=payload.notes.strip(),
        is_default=make_default,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.put("/addresses/{address_id}", response_model=CustomerAddressSchema)
def update_my_address(
    address_id: str,
    payload: CustomerAddressRequest,
    principal: dict = Depends(require_customer),
    db: Session = Depends(get_db),
):
    row = db.query(DBCustomerAddress).filter(
        DBCustomerAddress.id == address_id,
        DBCustomerAddress.user_id == principal["id"],
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="عنوان التوصيل غير موجود لهذا الحساب.")
    if payload.is_default:
        _clear_default(db, principal["id"], except_id=row.id)
    row.label = payload.label.strip()
    row.recipient_name = payload.recipient_name.strip()
    row.phone = payload.phone.strip()
    row.address = payload.address.strip()
    row.notes = payload.notes.strip()
    row.is_default = payload.is_default
    row.updated_at = _now()
    if not row.is_default and db.query(DBCustomerAddress).filter(
        DBCustomerAddress.user_id == principal["id"],
        DBCustomerAddress.id != row.id,
        DBCustomerAddress.is_default.is_(True),
    ).count() == 0:
        row.is_default = True
    db.commit()
    db.refresh(row)
    return row


@router.delete("/addresses/{address_id}")
def delete_my_address(
    address_id: str,
    principal: dict = Depends(require_customer),
    db: Session = Depends(get_db),
):
    row = db.query(DBCustomerAddress).filter(
        DBCustomerAddress.id == address_id,
        DBCustomerAddress.user_id == principal["id"],
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="عنوان التوصيل غير موجود لهذا الحساب.")
    user_id, was_default = principal["id"], row.is_default
    db.delete(row)
    db.commit()
    if was_default:
        replacement = db.query(DBCustomerAddress).filter(
            DBCustomerAddress.user_id == user_id
        ).order_by(DBCustomerAddress.created_at.asc(), DBCustomerAddress.id.asc()).first()
        if replacement is not None:
            replacement.is_default = True
            replacement.updated_at = _now()
            db.commit()
    return {"status": "deleted", "address_id": address_id}
