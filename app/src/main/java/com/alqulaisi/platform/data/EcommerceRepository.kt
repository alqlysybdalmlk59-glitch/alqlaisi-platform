package com.alqulaisi.platform.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object EcommerceRepository {
    private val _currentUser = MutableStateFlow<User?>(
        User("u1", "أحمد العميل", "client@alqulaisi.com", "0770000001", UserRole.CLIENT)
    )
    val currentUser: StateFlow<User?> = _currentUser.asStateFlow()

    private val _products = MutableStateFlow<List<Product>>(
        listOf(
            Product("p1", "هاتف ذكي برو ماكس", "شاشة أوليد 6.7 إنش، ذاكرة 256 جيجابايت", 850.0, "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500", "v1", "متجر التقنية الحديثة", "إلكترونيات", true, ProductReviewStatus.PUBLISHED),
            Product("p2", "ساعة ذكية رياضية", "مقاومة للماء، قياس نبضات القلب ونسبة الأكسجين", 120.0, "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500", "v1", "متجر التقنية الحديثة", "إلكترونيات", true, ProductReviewStatus.PUBLISHED),
            Product("p3", "حذاء رياضي أنيق", "مريح جداً للجري والمشي اليومي", 45.0, "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500", "v2", "متجر الأزياء العصرية", "أزياء", true, ProductReviewStatus.PUBLISHED),
            Product("p4", "طقم العناية بالبشرة الطبيعي", "منتجات طبيعية 100% للعناية اليومية", 65.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=500", "v3", "متجر الجمال والعناية", "صحة وجمال", true, ProductReviewStatus.PENDING_REVIEW)
        )
    )
    val products: StateFlow<List<Product>> = _products.asStateFlow()

    private val _cart = MutableStateFlow<List<CartItem>>(emptyList())
    val cart: StateFlow<List<CartItem>> = _cart.asStateFlow()

    private val _orders = MutableStateFlow<List<Order>>(
        listOf(
            Order("ord-101", "u1", "أحمد العميل", "v1", "متجر التقنية الحديثة", listOf(CartItem(products.value[0], 1)), 850.0, 15.0, 865.0, "الدفع عند الاستلام", "صنعاء - شارع الخمسين", "بانتظار القبول", "2025-05-10"),
            Order("ord-102", "u1", "أحمد العميل", "v2", "متجر الأزياء العصرية", listOf(CartItem(products.value[2], 2)), 90.0, 15.0, 105.0, "الدفع عند الاستلام", "صنعاء - شارع الخمسين", "تم الاستلام", "2025-05-12")
        )
    )
    val orders: StateFlow<List<Order>> = _orders.asStateFlow()

    private val _vendors = MutableStateFlow<List<VendorStore>>(
        listOf(
            VendorStore("v1", "متجر التقنية الحديثة", "محمد التقني", "0771111111", "", "متجر متخصص بالأجهزة الإلكترونية والذكية", "مفعل"),
            VendorStore("v2", "متجر الأزياء العصرية", "سارة الأنيقة", "0772222222", "", "أحدث صيحات الموضة والأزياء", "مفعل"),
            VendorStore("v3", "متجر الجمال والعناية", "خالد الجمال", "0773333333", "", "منتجات تجميل وعناية بالبشرة", "قيد المراجعة")
        )
    )
    val vendors: StateFlow<List<VendorStore>> = _vendors.asStateFlow()

    private val _supportTickets = MutableStateFlow<List<SupportTicket>>(
        listOf(
            SupportTicket("t1", "u1", "أحمد العميل", UserRole.CLIENT, "استفسار عن موعد التوصيل", "متى سيتم توصيل الطلب ord-101؟", "مفتوحة")
        )
    )
    val supportTickets: StateFlow<List<SupportTicket>> = _supportTickets.asStateFlow()

    fun login(email: String, role: UserRole) {
        val user = when(role) {
            UserRole.CLIENT -> User("u1", "أحمد العميل", email, "0770000001", UserRole.CLIENT)
            UserRole.VENDOR -> User("v1", "محمد التاجر", email, "0771111111", UserRole.VENDOR)
            UserRole.ADMIN -> User("admin1", "مدير النظام العام", email, "0779999999", UserRole.ADMIN)
        }
        _currentUser.value = user
    }

    fun logout() {
        _currentUser.value = null
    }

    fun addToCart(product: Product) {
        if (!product.isAvailable) return
        val currentList = _cart.value.toMutableList()
        val existing = currentList.find { it.product.id == product.id }
        if (existing != null) {
            existing.quantity++
        } else {
            currentList.add(CartItem(product, 1))
        }
        _cart.value = currentList
    }

    fun removeFromCart(productId: String) {
        _cart.value = _cart.value.filter { it.product.id != productId }
    }

    fun clearCart() {
        _cart.value = emptyList()
    }

    // تقسيم الطلبات حسب البائع تلقائياً
    fun checkout(): Boolean {
        if (_cart.value.isEmpty()) return false
        val user = _currentUser.value ?: return false
        
        val itemsByVendor = _cart.value.groupBy { it.product.vendorId }
        val newOrders = mutableListOf<Order>()

        itemsByVendor.forEach { (vendorId, items) ->
            val vendorName = items.first().product.vendorName
            val itemsPrice = items.sumOf { it.product.price * it.quantity }
            val deliveryFee = 15.0
            val total = itemsPrice + deliveryFee
            
            val newOrder = Order(
                id = "ord-${System.currentTimeMillis().toString().takeLast(5)}",
                clientId = user.id,
                clientName = user.name,
                vendorId = vendorId,
                vendorName = vendorName,
                items = items,
                itemsPrice = itemsPrice,
                deliveryFee = deliveryFee,
                totalPrice = total,
                paymentMethod = "الدفع عند الاستلام",
                address = user.address,
                status = "بانتظار القبول",
                date = "اليوم"
            )
            newOrders.add(newOrder)
        }

        _orders.value = newOrders + _orders.value
        clearCart()
        return true
    }

    fun addProduct(product: Product) {
        _products.value = listOf(product) + _products.value
    }

    fun toggleProductAvailability(productId: String) {
        _products.value = _products.value.map {
            if (it.id == productId) it.copy(isAvailable = !it.isAvailable) else it
        }
    }

    fun approveProduct(productId: String) {
        _products.value = _products.value.map {
            if (it.id == productId) it.copy(reviewStatus = ProductReviewStatus.PUBLISHED) else it
        }
    }

    fun rejectProduct(productId: String, notes: String) {
        _products.value = _products.value.map {
            if (it.id == productId) it.copy(reviewStatus = ProductReviewStatus.REJECTED, adminNotes = notes) else it
        }
    }

    fun updateOrderStatus(orderId: String, newStatus: String) {
        _orders.value = _orders.value.map {
            if (it.id == orderId) it.copy(status = newStatus) else it
        }
    }

    fun registerVendorStore(storeName: String, ownerName: String, phone: String, desc: String) {
        val newVendor = VendorStore(
            id = "v-${System.currentTimeMillis()}",
            storeName = storeName,
            ownerName = ownerName,
            phone = phone,
            logoUrl = "",
            description = desc,
            status = "قيد المراجعة"
        )
        _vendors.value = listOf(newVendor) + _vendors.value
    }

    fun approveVendor(vendorId: String) {
        _vendors.value = _vendors.value.map {
            if (it.id == vendorId) it.copy(status = "مفعل") else it
        }
    }

    fun rejectVendor(vendorId: String, notes: String) {
        _vendors.value = _vendors.value.map {
            if (it.id == vendorId) it.copy(status = "مرفوض", adminNotes = notes) else it
        }
    }

    fun addSupportTicket(subject: String, details: String) {
        val user = _currentUser.value ?: return
        val ticket = SupportTicket(
            id = "t-${System.currentTimeMillis().toString().takeLast(4)}",
            userId = user.id,
            userName = user.name,
            userRole = user.role,
            subject = subject,
            details = details
        )
        _supportTickets.value = listOf(ticket) + _supportTickets.value
    }

    fun respondSupportTicket(ticketId: String, response: String) {
        _supportTickets.value = _supportTickets.value.map {
            if (it.id == ticketId) it.copy(response = response, status = "تم الرد والإغلاق") else it
        }
    }
}
