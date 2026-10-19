package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.data.PlatformRepository
import com.example.model.OrderStatus
import com.example.model.UserRole
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ExampleRobolectricTest {

    private lateinit var repository: PlatformRepository

    @Before
    fun setUp() {
        repository = PlatformRepository()
    }

    @Test
    fun `read string from context matches platform name`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val appName = context.getString(R.string.app_name)
        assertEquals("منصة القليسي", appName)
    }

    @Test
    fun `test role switching and tenant profile update`() {
        assertEquals(UserRole.CUSTOMER, repository.currentUser.value.role)

        // Switch to Seller A
        repository.switchUser(repository.sellerUserA)
        assertEquals(UserRole.SELLER, repository.currentUser.value.role)
        assertEquals(501, repository.currentUser.value.storeId)

        // Switch to Admin
        repository.switchUser(repository.adminUser)
        assertEquals(UserRole.ADMIN, repository.currentUser.value.role)
        assertNull(repository.currentUser.value.storeId)
    }

    @Test
    fun `test review is blocked before delivered status`() {
        // Order 1002 is in PROCESSING status
        val (canReviewProcessing, msg) = repository.submitProductReview(
            orderId = 1002,
            productId = 4,
            rating = 5,
            comment = "ممتاز"
        )
        assertFalse("Review must be blocked when order is PROCESSING", canReviewProcessing)
        assertTrue(msg.contains("تم التسليم"))

        // Order 1001 is in DELIVERED status
        val (canReviewDelivered, _) = repository.submitProductReview(
            orderId = 1001,
            productId = 1,
            rating = 5,
            comment = "سماعة ممتازة"
        )
        assertTrue("Review must succeed when order is DELIVERED", canReviewDelivered)
    }

    @Test
    fun `test multi-vendor checkout splits orders per seller`() {
        // Initial cart has products from store 501 and store 502
        val initialOrderCount = repository.orders.value.size
        val result = repository.checkout("صنعاء - شارع حدة")
        val updatedOrders = repository.orders.value

        // Check that new orders were partitioned
        assertEquals(initialOrderCount + 2, updatedOrders.size)
        assertTrue(result.contains("2 طلبات مستقلة"))
    }

    @Test
    fun `test penetration test simulator blocks cross-role access`() {
        val attackAdminResult = repository.runPenetrationTest(1)
        assertTrue(attackAdminResult.passed)
        assertEquals(403, attackAdminResult.actualStatus)

        val crossTenantResult = repository.runPenetrationTest(2)
        assertTrue(crossTenantResult.passed)
        assertEquals(403, crossTenantResult.actualStatus)
    }

    @Test
    fun `test room database user insertion and retrieval`() = kotlinx.coroutines.test.runTest {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val db = androidx.room.Room.inMemoryDatabaseBuilder(context, com.example.data.local.AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()

        val userDao = db.userDao()

        val testUser = com.example.data.local.UserEntity(
            id = 555,
            email = "test.seller@alqulaisi.ye",
            fullName = "تاجر تجريبي",
            phoneNumber = "+967 777 000 999",
            role = "seller",
            status = "active",
            storeId = 99
        )

        userDao.insertUser(testUser)

        val retrieved = userDao.getUserByIdOnce(555)
        assertNotNull(retrieved)
        assertEquals("test.seller@alqulaisi.ye", retrieved?.email)
        assertEquals("seller", retrieved?.role)
        assertEquals(99, retrieved?.storeId)

        // Verify domain mapping
        val domainUser = retrieved?.toDomainUser()
        assertNotNull(domainUser)
        assertEquals(UserRole.SELLER, domainUser?.role)

        // Test UPDATE
        userDao.updateUserProfile(555, "تاجر معتمد جديد", "+967 777 111 222")
        val updated = userDao.getUserByIdOnce(555)
        assertEquals("تاجر معتمد جديد", updated?.fullName)
        assertEquals("+967 777 111 222", updated?.phoneNumber)

        // Test READ by Email
        val byEmail = userDao.getUserByEmail("test.seller@alqulaisi.ye")
        assertNotNull(byEmail)
        assertEquals(555, byEmail?.id)

        // Test DELETE
        userDao.deleteUserById(555)
        val afterDelete = userDao.getUserByIdOnce(555)
        assertNull(afterDelete)

        db.close()
    }

    @Test
    fun `test user viewmodel stateflow operations and filtering`() = kotlinx.coroutines.test.runTest {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val db = androidx.room.Room.inMemoryDatabaseBuilder(context, com.example.data.local.AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        val userDao = db.userDao()

        // Insert seed test data
        val u1 = com.example.data.local.UserEntity(
            id = 1,
            email = "customer@alqulaisi.ye",
            fullName = "خالد العميل",
            phoneNumber = "+967 771 111 222",
            role = "customer",
            status = "active"
        )
        val u2 = com.example.data.local.UserEntity(
            id = 2,
            email = "seller@alqulaisi.ye",
            fullName = "سالم البائع",
            phoneNumber = "+967 772 222 333",
            role = "seller",
            status = "active",
            storeId = 501
        )
        userDao.insertUser(u1)
        userDao.insertUser(u2)

        val viewModel = com.example.ui.viewmodel.UserViewModel(userDao)

        // Test StateFlow initial emission / collection
        val users = userDao.getUserByIdOnce(1)
        assertNotNull(users)
        assertEquals("خالد العميل", users?.fullName)

        // Test ViewModel Status Update
        viewModel.updateUserStatus(1, "suspended")
        val updatedU1 = userDao.getUserByIdOnce(1)
        assertEquals("suspended", updatedU1?.status)

        // Test Filter & Search setters
        viewModel.setRoleFilter("customer")
        assertEquals("customer", viewModel.selectedRoleFilter.value)

        viewModel.setSearchQuery("خالد")
        assertEquals("خالد", viewModel.searchQuery.value)

        // Test ViewModel Delete
        viewModel.deleteUser(2)
        val deletedU2 = userDao.getUserByIdOnce(2)
        assertNull(deletedU2)

        db.close()
    }
}
