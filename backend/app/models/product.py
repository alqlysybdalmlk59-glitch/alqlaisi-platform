from enum import Enum
from datetime import datetime
from typing import Optional, List
try:
    from pydantic import BaseModel, Field
except ImportError:
    class BaseModel:
        def __init__(self, **kwargs):
            for k, v in kwargs.items():
                setattr(self, k, v)
    def Field(default=None, **kwargs):
        return default


class ProductReviewStatus(str, Enum):
    DRAFT = "draft"                    # مسودة
    PENDING_REVIEW = "pending_review"  # قيد المراجعة من الإدارة
    APPROVED = "approved"              # مقبول ومنشور
    REJECTED = "rejected"              # مرفوض مع ملاحظات


class ProductBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    description: str = Field(..., max_length=1000)
    price: float = Field(..., gt=0)
    category: str = Field(..., min_length=2, max_length=50)
    image_url: Optional[str] = None
    # NOTE: As explicitly mandated by the platform agreement, there is NO stock quantity / inventory counter.
    # Availability is managed strictly via manual boolean toggle by the seller:
    is_available: bool = True  # متاح أو غير متاح مؤقتاً


class ProductCreate(ProductBase):
    submit_for_review: bool = True


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = Field(None, gt=0)
    category: Optional[str] = None
    image_url: Optional[str] = None
    is_available: Optional[bool] = None  # Manual toggle only


class ProductReviewDecision(BaseModel):
    decision: ProductReviewStatus  # APPROVED or REJECTED
    rejection_reason: Optional[str] = None


class ProductResponse(ProductBase):
    id: int
    store_id: int
    store_name: Optional[str] = None
    review_status: ProductReviewStatus
    rejection_reason: Optional[str] = None
    average_rating: float = 0.0
    reviews_count: int = 0
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
