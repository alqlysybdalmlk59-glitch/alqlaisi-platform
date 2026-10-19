from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey, Text
from sqlalchemy.orm import relationship
from database import Base

class DBUser(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    role = Column(String, nullable=False)  # CLIENT, VENDOR, ADMIN
    phone = Column(String, default="0770000000")
    address = Column(String, default="صنعاء - اليمن")

class DBVendorStore(Base):
    __tablename__ = "vendor_stores"

    id = Column(String, primary_key=True, index=True)
    store_name = Column(String, nullable=False)
    owner_name = Column(String, nullable=False)
    phone = Column(String, nullable=False)
    description = Column(Text, default="")
    status = Column(String, default="قيد المراجعة")  # مفعل, قيد المراجعة, مرفوض
    admin_notes = Column(Text, default="")

class DBProduct(Base):
    __tablename__ = "products"

    id = Column(String, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(Text, default="")
    price = Column(Float, nullable=False)
    image_url = Column(String, default="")
    vendor_id = Column(String, nullable=False)
    vendor_name = Column(String, nullable=False)
    category = Column(String, default="عام")
    is_available = Column(Boolean, default=True)  # متاح / غير متاح مؤقتاً (بدون كميات مخزون)
    review_status = Column(String, default="منشور")  # منشور, قيد المراجعة, مرفوض
    admin_notes = Column(Text, default="")

class DBOrder(Base):
    __tablename__ = "orders"

    id = Column(String, primary_key=True, index=True)
    client_id = Column(String, nullable=False)
    client_name = Column(String, nullable=False)
    vendor_id = Column(String, nullable=False)
    vendor_name = Column(String, nullable=False)
    items_json = Column(Text, nullable=False)  # JSON representation of items
    items_price = Column(Float, nullable=False)
    delivery_fee = Column(Float, default=15.0)
    total_price = Column(Float, nullable=False)
    payment_method = Column(String, default="الدفع عند الاستلام")
    address = Column(String, nullable=False)
    status = Column(String, default="بانتظار القبول")
    date = Column(String, nullable=False)

class DBSupportTicket(Base):
    __tablename__ = "support_tickets"

    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, nullable=False)
    user_name = Column(String, nullable=False)
    user_role = Column(String, nullable=False)
    subject = Column(String, nullable=False)
    details = Column(Text, nullable=False)
    status = Column(String, default="مفتوحة")
    response = Column(Text, default="")
