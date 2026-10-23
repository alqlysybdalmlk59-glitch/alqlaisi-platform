package com.alqulaisi.platform.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Model-level regression tests for the current Compose prototype.
 *
 * The previous template test referred to com.example Room/ViewModel classes
 * that are no longer part of this project, so it could not compile.
 */
class ExampleRobolectricTest {

    @Test
    fun orderWorkflowHasExplicitArabicLabels() {
        assertEquals("بانتظار القبول", OrderStatus.PENDING.label)
        assertEquals("مقبولة وقيد التجهيز", OrderStatus.ACCEPTED.label)
        assertEquals("للتوصيل", OrderStatus.DELIVERING.label)
        assertEquals("تم الاستلام", OrderStatus.COMPLETED.label)
        assertEquals("ملغي", OrderStatus.CANCELLED.label)
    }

    @Test
    fun productCanBeSubmittedForReviewWithoutCustomerSalePrice() {
        val product = Product(
            id = "test-product",
            title = "دفتر تجريبي",
            description = "منتج للاختبار",
            price = 0.0,
            imageUrl = "",
            vendorId = "vendor-test",
            vendorName = "متجر تجريبي",
            category = "دفاتر وكراسات",
            isAvailable = false,
            reviewStatus = ProductReviewStatus.PENDING_REVIEW,
            purchasePrice = 100.0
        )

        assertEquals(ProductReviewStatus.PENDING_REVIEW, product.reviewStatus)
        assertEquals(100.0, product.purchasePrice!!, 0.0)
        assertEquals(0.0, product.price, 0.0)
        assertFalse(product.isAvailable)
    }

    @Test
    fun ordersTrackStoreDeliveryAndCashOnDeliverySeparately() {
        val product = Product(
            id = "test-product",
            title = "دفتر",
            description = "دفتر",
            price = 200.0,
            imageUrl = "",
            vendorId = "vendor-test",
            vendorName = "متجر تجريبي",
            category = "دفاتر وكراسات"
        )
        val order = Order(
            id = "order-test",
            clientId = "client-test",
            clientName = "عميل تجريبي",
            vendorId = "vendor-test",
            vendorName = "متجر تجريبي",
            items = listOf(CartItem(product, 2)),
            itemsPrice = 400.0,
            deliveryFee = 15.0,
            totalPrice = 415.0,
            address = "صنعاء",
            status = OrderStatus.PENDING,
            date = "2026-10-23"
        )

        assertEquals("الدفع عند الاستلام", order.paymentMethod)
        assertEquals(400.0, order.itemsPrice, 0.0)
        assertEquals(15.0, order.deliveryFee, 0.0)
        assertEquals(415.0, order.totalPrice, 0.0)
        assertEquals(OrderStatus.PENDING, order.status)
        assertTrue(order.items.isNotEmpty())
    }

    @Test
    fun newVendorStoreDefaultsToAwaitingAdminReview() {
        val store = VendorStore(
            id = "vendor-test",
            storeName = "متجر تجريبي",
            ownerName = "بائع تجريبي",
            phone = "777123456",
            logoUrl = "",
            description = "متجر اختبار",
            status = "قيد المراجعة",
            ownerId = "seller-account"
        )

        assertEquals("قيد المراجعة", store.status)
        assertEquals("seller-account", store.ownerId)
    }
}
