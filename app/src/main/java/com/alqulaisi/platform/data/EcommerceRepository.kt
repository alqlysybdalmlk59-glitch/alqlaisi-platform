package com.alqulaisi.platform.data

import java.time.LocalDate
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Local prototype repository for the Android Compose screens.
 *
 * These StateFlows are in-memory demo state, not a production database or
 * server authorization boundary. The API-backed Flutter apps use backend/.
 */
object EcommerceRepository {
    private val orderSequence = AtomicLong(102)
    private val vendorSequence = AtomicLong(3)
    private val ticketSequence = AtomicLong(1)

    private val _currentUser = MutableStateFlow<User?>(
        User("u1", "أحمد العميل", "client@alqulaisi.com", "0770000001", UserRole.CLIENT)
    )
    val currentUser: StateFlow<User?> = _currentUser.asStateFlow()

    private val _products = MutableStateFlow<List<Product>>(
        listOf(
            Product(
                id = "p1",
                title = "دفاتر جامعية سلك",
                description = "دفاتر للجامعة والمحاضرات، ورق مناسب للكتابة اليومية",
                price = 150.0,
                imageUrl = "https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=500",
                vendorId = "v1",
                vendorName = "مكتبة القليسي",
                category = "دفاتر وكراسات",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.PUBLISHED,
                purchasePrice = 110.0
            ),
            Product(
                id = "p2",
                title = "طقم أقلام كتابة",
                description = "أقلام عملية للدراسة وتدوين الملاحظات",
                price = 180.0,
                imageUrl = "https://images.unsplash.com/photo-1455390582262-044cdead277a?w=500",
                vendorId = "v1",
                vendorName = "مكتبة القليسي",
                category = "أقلام وأدوات كتابة",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.PUBLISHED,
                purchasePrice = 135.0
            ),
            Product(
                id = "p3",
                title = "حقيبة مدرسية",
                description = "حقيبة متعددة الجيوب للاستخدام المدرسي والجامعي",
                price = 450.0,
                imageUrl = "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500",
                vendorId = "v2",
                vendorName = "مكتبة الطالب",
                category = "حقائب مدرسية",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.PUBLISHED,
                purchasePrice = 360.0
            ),
            Product(
                id = "p4",
                title = "ورق طباعة A4",
                description = "ورق أبيض للاستخدام المكتبي والطباعة",
                price = 0.0,
                imageUrl = "https://images.unsplash.com/photo-1562654501-a0ccc0fc3fb1?w=500",
                vendorId = "v3",
                vendorName = "مكتبة المعرفة",
                category = "ورق ومواد طباعة",
                isAvailable = false,
                reviewStatus = ProductReviewStatus.PENDING_REVIEW,
                purchasePrice = 400.0
            )
        )
    )
    val products: StateFlow<List<Product>> = _products.asStateFlow()

    private val _cart = MutableStateFlow<List<CartItem>>(emptyList())
    val cart: StateFlow<List<CartItem>> = _cart.asStateFlow()

    private val _orders = MutableStateFlow<List<Order>>(
        listOf(
            Order(
                id = "ord-101",
                clientId = "u1",
                clientName = "أحمد العميل",
                vendorId = "v1",
                vendorName = "مكتبة القليسي",
                items = listOf(CartItem(products.value[0], 1)),
                itemsPrice = 150.0,
                deliveryFee = 15.0,
                totalPrice = 165.0,
                address = "صنعاء - شارع الخمسين",
                status = OrderStatus.PENDING,
                date = "2026-10-20"
            ),
            Order(
                id = "ord-102",
                clientId = "u1",
                clientName = "أحمد العميل",
                vendorId = "v2",
                vendorName = "مكتبة الطالب",
                items = listOf(CartItem(products.value[2], 2)),
                itemsPrice = 900.0,
                deliveryFee = 15.0,
                totalPrice = 915.0,
                address = "صنعاء - شارع الخمسين",
                status = OrderStatus.COMPLETED,
                date = "2026-10-18"
            )
        )
    )
    val orders: StateFlow<List<Order>> = _orders.asStateFlow()

    private val _vendors = MutableStateFlow<List<VendorStore>>(
        listOf(
            VendorStore(
                id = "v1",
                storeName = "مكتبة القليسي",
                ownerName = "محمد البائع",
                phone = "0771111111",
                logoUrl = "",
                description = "دفاتر وأقلام واحتياجات الطلاب",
                status = "مفعل",
                ownerId = "v1",
                deliveryFee = 15.0
            ),
            VendorStore(
                id = "v2",
                storeName = "مكتبة الطالب",
                ownerName = "سارة البائعة",
                phone = "0772222222",
                logoUrl = "",
                description = "حقائب ولوازم مدرسية وجامعية",
                status = "مفعل",
                ownerId = "v2",
                deliveryFee = 15.0
            ),
            VendorStore(
                id = "v3",
                storeName = "مكتبة المعرفة",
                ownerName = "خالد البائع",
                phone = "0773333333",
                logoUrl = "",
                description = "كتب وورق ولوازم طباعة",
                status = "قيد المراجعة",
                ownerId = "v3",
                deliveryFee = 15.0
            )
        )
    )
    val vendors: StateFlow<List<VendorStore>> = _vendors.asStateFlow()

    private val _supportTickets = MutableStateFlow<List<SupportTicket>>(
        listOf(
            SupportTicket(
                id = "t1",
                userId = "u1",
                userName = "أحمد العميل",
                userRole = UserRole.CLIENT,
                subject = "استفسار عن موعد التوصيل",
                details = "متى سيتم توصيل الطلب ord-101؟",
                status = "مفتوحة"
            )
        )
    )
    val supportTickets: StateFlow<List<SupportTicket>> = _supportTickets.asStateFlow()

    fun login(email: String, role: UserRole) {
        // Demo role switch only. Production authentication belongs to the API.
        _currentUser.value = when (role) {
            UserRole.CLIENT -> User("u1", "أحمد العميل", email, "0770000001", UserRole.CLIENT)
            UserRole.VENDOR -> User("v1", "محمد البائع", email, "0771111111", UserRole.VENDOR)
            UserRole.ADMIN -> User("admin1", "مدير النظام", email, "0779999999", UserRole.ADMIN)
        }
    }

    fun logout() {
        _currentUser.value = null
        _cart.value = emptyList()
    }

    private fun currentVendorStore(user: User? = _currentUser.value): VendorStore? {
        if (user == null || user.role != UserRole.VENDOR) return null
        return _vendors.value.firstOrNull { store ->
            store.ownerId == user.id || (store.ownerId.isBlank() && store.id == user.id)
        }
    }

    private fun isPurchasable(product: Product): Boolean =
        product.reviewStatus == ProductReviewStatus.PUBLISHED &&
            product.isAvailable &&
            product.price > 0.0 &&
            product.price.isFinite()

    fun addToCart(product: Product) {
        if (_currentUser.value?.role != UserRole.CLIENT) return
        val currentProduct = _products.value.firstOrNull { it.id == product.id } ?: return
        if (!isPurchasable(currentProduct)) return

        val existing = _cart.value.firstOrNull { it.product.id == currentProduct.id }
        _cart.value = if (existing == null) {
            _cart.value + CartItem(currentProduct, 1)
        } else {
            _cart.value.map { item ->
                if (item.product.id == currentProduct.id) {
                    item.copy(product = currentProduct, quantity = item.quantity + 1)
                } else {
                    item
                }
            }
        }
    }

    fun removeFromCart(productId: String) {
        _cart.value = _cart.value.filterNot { it.product.id == productId }
    }

    fun clearCart() {
        _cart.value = emptyList()
    }

    /**
     * Revalidates every cart item at checkout and creates one COD order per
     * approved store. No inventory quantities are tracked in this prototype.
     */
    fun checkout(): Boolean {
        val user = _currentUser.value ?: return false
        if (user.role != UserRole.CLIENT || _cart.value.isEmpty()) return false

        val validatedItems = mutableListOf<CartItem>()
        for (item in _cart.value) {
            val liveProduct = _products.value.firstOrNull { it.id == item.product.id } ?: return false
            if (item.quantity < 1 || !isPurchasable(liveProduct)) return false
            val store = _vendors.value.firstOrNull { it.id == liveProduct.vendorId }
                ?: return false
            if (store.status != "مفعل") return false
            validatedItems += CartItem(liveProduct, item.quantity)
        }

        val newOrders = mutableListOf<Order>()
        for ((vendorId, items) in validatedItems.groupBy { it.product.vendorId }) {
            val store = _vendors.value.firstOrNull { it.id == vendorId && it.status == "مفعل" }
                ?: return false
            val itemsPrice = items.sumOf { it.product.price * it.quantity }
            val deliveryFee = store.deliveryFee.coerceAtLeast(0.0)
            val sequence = orderSequence.incrementAndGet()

            newOrders += Order(
                id = "ord-${System.currentTimeMillis()}-$sequence",
                clientId = user.id,
                clientName = user.name,
                vendorId = vendorId,
                vendorName = store.storeName,
                items = items,
                itemsPrice = itemsPrice,
                deliveryFee = deliveryFee,
                totalPrice = itemsPrice + deliveryFee,
                paymentMethod = "الدفع عند الاستلام",
                address = user.address,
                status = OrderStatus.PENDING,
                date = LocalDate.now().toString()
            )
        }

        if (newOrders.isEmpty()) return false
        _orders.value = newOrders + _orders.value
        clearCart()
        return true
    }

    /**
     * Seller submissions never set the customer-facing price or availability.
     * Management reviews the product and sets the final sale price.
     */
    fun addProduct(product: Product): Boolean {
        val user = _currentUser.value ?: return false
        if (user.role != UserRole.VENDOR) return false
        val store = currentVendorStore(user) ?: return false
        if (store.status != "مفعل" || product.vendorId != store.id) return false
        if (product.title.isBlank() || product.category.isBlank()) return false
        if (product.purchasePrice == null ||
            !product.purchasePrice.isFinite() ||
            product.purchasePrice <= 0.0
        ) return false

        val pendingProduct = product.copy(
            price = 0.0,
            vendorId = store.id,
            vendorName = store.storeName,
            isAvailable = false,
            reviewStatus = ProductReviewStatus.PENDING_REVIEW,
            adminNotes = ""
        )
        _products.value = listOf(pendingProduct) + _products.value.filterNot { it.id == product.id }
        return true
    }

    fun toggleProductAvailability(productId: String): Boolean {
        val user = _currentUser.value ?: return false
        if (user.role != UserRole.VENDOR) return false
        val store = currentVendorStore(user) ?: return false
        if (store.status != "مفعل") return false

        val product = _products.value.firstOrNull { it.id == productId } ?: return false
        if (product.vendorId != store.id || product.reviewStatus != ProductReviewStatus.PUBLISHED) {
            return false
        }

        _products.value = _products.value.map {
            if (it.id == productId) it.copy(isAvailable = !it.isAvailable) else it
        }
        return true
    }

    fun approveProduct(productId: String, salePrice: Double): Boolean {
        if (_currentUser.value?.role != UserRole.ADMIN) return false
        if (!salePrice.isFinite() || salePrice <= 0.0) return false
        val product = _products.value.firstOrNull { it.id == productId } ?: return false
        if (product.reviewStatus != ProductReviewStatus.PENDING_REVIEW) return false

        _products.value = _products.value.map {
            if (it.id == productId) {
                it.copy(
                    price = salePrice,
                    isAvailable = false,
                    reviewStatus = ProductReviewStatus.PUBLISHED,
                    adminNotes = ""
                )
            } else {
                it
            }
        }
        return true
    }

    fun rejectProduct(productId: String, notes: String): Boolean {
        if (_currentUser.value?.role != UserRole.ADMIN || notes.isBlank()) return false
        val product = _products.value.firstOrNull { it.id == productId } ?: return false
        if (product.reviewStatus != ProductReviewStatus.PENDING_REVIEW) return false

        _products.value = _products.value.map {
            if (it.id == productId) {
                it.copy(
                    isAvailable = false,
                    reviewStatus = ProductReviewStatus.REJECTED,
                    adminNotes = notes.trim()
                )
            } else {
                it
            }
        }
        return true
    }

    fun updateOrderStatus(orderId: String, newStatus: OrderStatus): Boolean {
        val user = _currentUser.value ?: return false
        val order = _orders.value.firstOrNull { it.id == orderId } ?: return false

        val allowed = when (user.role) {
            UserRole.ADMIN -> {
                (order.status == OrderStatus.DELIVERING && newStatus == OrderStatus.COMPLETED) ||
                    (order.status != OrderStatus.COMPLETED &&
                        order.status != OrderStatus.CANCELLED &&
                        newStatus == OrderStatus.CANCELLED)
            }

            UserRole.VENDOR -> {
                val store = currentVendorStore(user)
                store != null && store.status == "مفعل" && store.id == order.vendorId &&
                    ((order.status == OrderStatus.PENDING && newStatus == OrderStatus.ACCEPTED) ||
                        (order.status == OrderStatus.ACCEPTED && newStatus == OrderStatus.DELIVERING))
            }

            UserRole.CLIENT -> {
                order.clientId == user.id &&
                    order.status == OrderStatus.PENDING &&
                    newStatus == OrderStatus.CANCELLED
            }
        }
        if (!allowed) return false

        _orders.value = _orders.value.map {
            if (it.id == orderId) it.copy(status = newStatus) else it
        }
        return true
    }

    fun registerVendorStore(storeName: String, ownerName: String, phone: String, desc: String): Boolean {
        val user = _currentUser.value ?: return false
        if (user.role != UserRole.VENDOR || currentVendorStore(user) != null) return false
        if (storeName.isBlank() || ownerName.isBlank() || phone.isBlank() || desc.isBlank()) return false

        val newVendor = VendorStore(
            id = "v-${System.currentTimeMillis()}-${vendorSequence.incrementAndGet()}",
            storeName = storeName.trim(),
            ownerName = ownerName.trim(),
            phone = phone.trim(),
            logoUrl = "",
            description = desc.trim(),
            status = "قيد المراجعة",
            ownerId = user.id,
            deliveryFee = 15.0
        )
        _vendors.value = listOf(newVendor) + _vendors.value
        return true
    }

    fun approveVendor(vendorId: String): Boolean {
        if (_currentUser.value?.role != UserRole.ADMIN) return false
        val vendor = _vendors.value.firstOrNull { it.id == vendorId } ?: return false
        if (vendor.status != "قيد المراجعة") return false

        _vendors.value = _vendors.value.map {
            if (it.id == vendorId) it.copy(status = "مفعل", adminNotes = "") else it
        }
        return true
    }

    fun rejectVendor(vendorId: String, notes: String): Boolean {
        if (_currentUser.value?.role != UserRole.ADMIN || notes.isBlank()) return false
        val vendor = _vendors.value.firstOrNull { it.id == vendorId } ?: return false
        if (vendor.status != "قيد المراجعة") return false

        _vendors.value = _vendors.value.map {
            if (it.id == vendorId) it.copy(status = "مرفوض", adminNotes = notes.trim()) else it
        }
        return true
    }

    fun addSupportTicket(subject: String, details: String): Boolean {
        val user = _currentUser.value ?: return false
        if (subject.isBlank() || details.isBlank()) return false
        val ticket = SupportTicket(
            id = "t-${System.currentTimeMillis()}-${ticketSequence.incrementAndGet()}",
            userId = user.id,
            userName = user.name,
            userRole = user.role,
            subject = subject.trim(),
            details = details.trim()
        )
        _supportTickets.value = listOf(ticket) + _supportTickets.value
        return true
    }

    fun respondSupportTicket(ticketId: String, response: String): Boolean {
        if (_currentUser.value?.role != UserRole.ADMIN || response.isBlank()) return false
        if (_supportTickets.value.none { it.id == ticketId }) return false
        _supportTickets.value = _supportTickets.value.map {
            if (it.id == ticketId) it.copy(response = response.trim(), status = "تم الرد والإغلاق") else it
        }
        return true
    }
}
