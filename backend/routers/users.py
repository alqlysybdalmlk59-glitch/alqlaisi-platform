from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import database
import models
from schemas import UserSchema, BaseModel
from pydantic import BaseModel as PydanticBase

router = APIRouter(prefix="/api/users", tags=["Users & Authentication"])

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

class LoginRequest(PydanticBase):
    email: str
    password: str = ""

class GoogleLoginRequest(PydanticBase):
    email: str
    name: str
    photo_url: str = ""

@post_route = router.post("/register", response_model=UserSchema)
@router.post("/register", response_model=UserSchema)
def register_user(user: UserSchema, db: Session = Depends(get_db)):
    existing = db.query(models.DBUser).filter(models.DBUser.email == user.email).first()
    if existing:
        return existing
    db_user = models.DBUser(
        id=user.id or f"u_{user.email}",
        name=user.name,
        email=user.email,
        role=user.role.upper(),
        phone=user.phone,
        address=user.address
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/login", response_model=UserSchema)
def login_user(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.DBUser).filter(models.DBUser.email == req.email).first()
    if not user:
        # إنشاء مستخدم افتراضي تلقائياً إن لمש يكن موجوداً لتسهيل التجربة
        role = "ADMIN" if "admin" in req.email.lower() else ("VENDOR" if "vendor" in req.email.lower() else "CLIENT")
        user = models.DBUser(
            id=f"u_{req.email}",
            name=req.email.split('@')[0],
            email=req.email,
            role=role,
            phone="0771234567",
            address="صنعاء - اليمن"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user

@router.post("/google-login", response_model=UserSchema)
def google_login(req: GoogleLoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.DBUser).filter(models.DBUser.email == req.email).first()
    if not user:
        user = models.DBUser(
            id=f"g_{req.email}",
            name=req.name,
            email=req.email,
            role="CLIENT",
            phone="0770000000",
            address="صنعاء - اليمن"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user

@router.get("/", response_model=List[UserSchema])
def get_users(db: Session = Depends(get_db)):
    return db.query(models.DBUser).all()
