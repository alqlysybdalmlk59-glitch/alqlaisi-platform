package com.alqulaisi.platform.data

enum class UserRole {
    CLIENT, VENDOR, ADMIN
}

data class User(
    val id: String,
    val name: String,
    val email: String,
    val phone: String = "0500000000",
    val role: UserRole,
    val address: String = "صنعاء - شارع الخمسين",
    val token: String = ""
)

enum class ProductReviewStatus {
    DRAFT, PENDING_REVIEW, PUBLISHED, REJECTED
}

/**
 * The order workflow is deliberately explicit so screens and repository rules
 * cannot silently create misspelled status labels.
 */
enum class OrderStatus(val label: String) {
    PENDING("بانتظار القبول"),
    ACCEPTED("مقبولة وقيد التجهيز"),
    DELIVERING("للتوصيل"),
    COMPLETED("تم الاستلام"),
    CANCELLED("ملغي")
}

data class Product(
    val id: String,
    val title: String,
    val description: String,
    /** Final customer-facing price; the administrator sets it during approval. */
    val price: Double,
    val imageUrl: String,
    val vendorId: String,
    val vendorName: String,
    val category: String,
    /** Manual availability only: this is not an inventory quantity. */
    val isAvailable: Boolean = true,
    val reviewStatus: ProductReviewStatus = ProductReviewStatus.PUBLISHED,
    val adminNotes: String = "",
    /** Purchase price agreed with the seller; never used as the customer price. */
    val purchasePrice: Double? = null
)

data class CartItem(
    val product: Product,
    val quantity: Int
)

data class Order(
    val id: String,
    val clientId: String,
    val clientName: String,
    val vendorId: String,
    val vendorName: String,
    val items: List<CartItem>,
    val itemsPrice: Double,
    val deliveryFee: Double = 15.0,
    val totalPrice: Double,
    val paymentMethod: String = "الدفع عند الاستلام",
    val address: String,
    val status: OrderStatus,
    val date: String
)

data class VendorStore(
    val id: String,
    val storeName: String,
    val ownerName: String,
    val phone: String,
    val logoUrl: String,
    val description: String,
    val status: String, // "مفعل", "قيد المراجعة", "مرفوض"
    val adminNotes: String = "",
    val ownerId: String = "",
    val deliveryFee: Double = 15.0
)

data class SupportTicket(
    val id: String,
    val userId: String,
    val userName: String,
    val userRole: UserRole,
    val subject: String,
    val details: String,
    val status: String = "مفتوحة", // "مفتوحة", "قيد المعالجة", "مغلقة"
    val response: String = ""
)
