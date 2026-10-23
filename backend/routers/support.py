import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from models import DBSupportTicket
from schemas import SupportTicketCreateRequest, SupportTicketSchema
from routers.dependencies import get_db, get_current_principal, require_admin

router = APIRouter(prefix="/api/support", tags=["support"])

@router.get("/")
def get_all_tickets(_principal: dict = Depends(require_admin), db: Session = Depends(get_db)):
    return db.query(DBSupportTicket).order_by(DBSupportTicket.id.desc()).all()

@router.get("/mine", response_model=list[SupportTicketSchema])
def get_my_tickets(principal: dict = Depends(get_current_principal), db: Session = Depends(get_db)):
    return db.query(DBSupportTicket).filter(DBSupportTicket.user_id == principal["id"]).order_by(
        DBSupportTicket.id.desc()).all()

@router.post("/", response_model=SupportTicketSchema, status_code=201)
def create_ticket(ticket: SupportTicketCreateRequest, principal: dict = Depends(get_current_principal),
    db: Session = Depends(get_db)):
    record = DBSupportTicket(id=f"ticket_{uuid.uuid4().hex}", user_id=principal["id"],
        user_name=principal["name"], user_role=principal["role"], subject=ticket.subject.strip(),
        details=ticket.details.strip(), status="مفتوحة", response="")
    db.add(record)
    db.commit()
    db.refresh(record)
    return record

@router.put("/{ticket_id}/respond")
def respond_ticket(ticket_id: str, response: str, _principal: dict = Depends(require_admin),
    db: Session = Depends(get_db)):
    ticket = db.query(DBSupportTicket).filter(DBSupportTicket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="تذكرة الدعم غير موجودة")
    ticket.response, ticket.status = response[:5000], "تم الرد والإغلاق"
    db.commit()
    return {"status": "closed"}
