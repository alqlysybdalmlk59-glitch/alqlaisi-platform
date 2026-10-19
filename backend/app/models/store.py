from enum import Enum
from datetime import datetime
from typing import Optional
try:
    from pydantic import BaseModel, Field
except ImportError:
    class BaseModel:
        def __init__(self, **kwargs):
            for k, v in kwargs.items():
                setattr(self, k, v)
    def Field(default=None, **kwargs):
        return default


class StoreStatus(str, Enum):
    PENDING_REVIEW = "pending_review"  # قيد المراجعة
    APPROVED = "approved"              # مقبول / معتمد
    REJECTED = "rejected"              # مرفوض مع ملاحظات
    SUSPENDED = "suspended"            # موقوف مؤقتاً


class StoreBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    description: str = Field(..., max_length=500)
    phone: str = Field(..., min_length=8, max_length=20)
    logo_url: Optional[str] = None


class StoreCreate(StoreBase):
    pass


class StoreUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    phone: Optional[str] = None
    logo_url: Optional[str] = None


class StoreReviewAction(BaseModel):
    status: StoreStatus
    rejection_reason: Optional[str] = None


class StoreResponse(StoreBase):
    id: int
    owner_id: int
    status: StoreStatus
    rejection_reason: Optional[str] = None
    commission_rate: float = 0.10  # Configurable platform commission
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
