from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import DBSupportTicket
from schemas import SupportTicketSchema
from routers.dependencies import get_current_principal, require_admin

router = APIRouter(prefix="/api/support", tags=["support"])


@router.get("/")
def get_all_tickets(
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(DBSupportTicket).all()


@router.post("/", response_model=SupportTicketSchema, status_code=201)
def create_ticket(
    ticket: SupportTicketSchema,
    principal: dict = Depends(get_current_principal),
    db: Session = Depends(get_db),
):
    data = ticket.dict()
    data["user_id"] = principal["id"]
    data["user_name"] = principal["name"]
    data["user_role"] = principal["role"]
    data["status"] = "مفتوحة"
    data["response"] = ""
    db_ticket = DBSupportTicket(**data)
    db.add(db_ticket)
    db.commit()
    db.refresh(db_ticket)
    return db_ticket


@router.put("/{ticket_id}/respond")
def respond_ticket(
    ticket_id: str,
    response: str,
    _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    ticket = db.query(DBSupportTicket).filter(DBSupportTicket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="تذكرة الدعم غير موجودة")
    ticket.response = response
    ticket.status = "تم الرد والإغلاق"
    db.commit()
    return {"status": "closed"}
