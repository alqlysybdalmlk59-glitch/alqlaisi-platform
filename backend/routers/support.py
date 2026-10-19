from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import DBSupportTicket
from schemas import SupportTicketSchema
from typing import List

router = APIRouter(prefix="/api/support", tags=["support"])

@router.get("/", response_model=List[SupportTicketSchema])
def get_all_tickets(db: Session = Depends(get_db)):
    return db.query(DBSupportTicket).all()

@router.post("/", response_model=SupportTicketSchema)
def create_ticket(ticket: SupportTicketSchema, db: Session = Depends(get_db)):
    db_ticket = DBSupportTicket(**ticket.dict())
    db.add(db_ticket)
    db.commit()
    db.refresh(db_ticket)
    return db_ticket

@router.put("/{ticket_id}/respond")
def respond_ticket(ticket_id: str, response: str, db: Session = Depends(get_db)):
    ticket = db.query(DBSupportTicket).filter(DBSupportTicket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="تذكرة الدعم غير موجودة")
    ticket.response = response
    ticket.status = "تم الرد والإغلاق"
    db.commit()
    return {"status": "closed"}
