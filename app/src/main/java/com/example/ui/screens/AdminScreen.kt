package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.PlatformRepository
import com.example.model.OrderStatus
import com.example.model.Product
import com.example.model.ProductReviewStatus
import com.example.model.Store
import com.example.model.StoreStatus
import com.example.ui.theme.RoleAdminColor
import com.example.ui.theme.StatusError
import com.example.ui.theme.StatusSuccess
import com.example.ui.theme.StatusWarning

import com.example.data.local.UserEntity
import com.example.ui.viewmodel.UserViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminScreen(
    repository: PlatformRepository,
    userViewModel: UserViewModel? = null,
    modifier: Modifier = Modifier
) {
    val stores by repository.stores.collectAsState()
    val products by repository.products.collectAsState()
    val orders by repository.orders.collectAsState()

    var selectedTab by remember { mutableStateOf(0) } // 0: Overview, 1: Stores, 2: Products, 3: Delivery, 4: Room Users
    var rejectStoreDialogTarget by remember { mutableStateOf<Store?>(null) }
    var rejectProductDialogTarget by remember { mutableStateOf<Product?>(null) }
    var showAddUserDialog by remember { mutableStateOf(false) }

    val pendingStores = stores.filter { it.status == StoreStatus.PENDING_REVIEW }
    val pendingProducts = products.filter { it.reviewStatus == ProductReviewStatus.PENDING_REVIEW }

    val roomUsers = userViewModel?.filteredUsers?.collectAsState()?.value ?: emptyList()
    val userSearchQuery = userViewModel?.searchQuery?.collectAsState()?.value ?: ""
    val userRoleFilter = userViewModel?.selectedRoleFilter?.collectAsState()?.value ?: "all"

    Scaffold(
        topBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
            ) {
                ScrollableTabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = RoleAdminColor,
                    edgePadding = 12.dp
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("المؤشرات", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Dashboard, contentDescription = "Dashboard") },
                        modifier = Modifier.testTag("admin_tab_dashboard")
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = {
                            val badge = pendingStores.size
                            Text(if (badge > 0) "المتاجر ($badge)" else "المتاجر", fontWeight = FontWeight.Bold)
                        },
                        icon = {
                            BadgedBox(badge = { if (pendingStores.isNotEmpty()) Badge { Text("${pendingStores.size}") } }) {
                                Icon(Icons.Default.Store, contentDescription = "Stores")
                            }
                        },
                        modifier = Modifier.testTag("admin_tab_stores")
                    )
                    Tab(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        text = {
                            val badge = pendingProducts.size
                            Text(if (badge > 0) "المنتجات ($badge)" else "المنتجات", fontWeight = FontWeight.Bold)
                        },
                        icon = {
                            BadgedBox(badge = { if (pendingProducts.isNotEmpty()) Badge { Text("${pendingProducts.size}") } }) {
                                Icon(Icons.Default.Rule, contentDescription = "Product Reviews")
                            }
                        },
                        modifier = Modifier.testTag("admin_tab_products")
                    )
                    Tab(
                        selected = selectedTab == 3,
                        onClick = { selectedTab = 3 },
                        text = { Text("التوصيل", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.DeliveryDining, contentDescription = "Delivery") },
                        modifier = Modifier.testTag("admin_tab_delivery")
                    )
                    Tab(
                        selected = selectedTab == 4,
                        onClick = { selectedTab = 4 },
                        text = { Text("المستخدمون (Room)", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.People, contentDescription = "Users") },
                        modifier = Modifier.testTag("admin_tab_users")
                    )
                }
            }
        },
        modifier = modifier
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                // Header Banner
                item {
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = RoleAdminColor.copy(alpha = 0.12f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Icon(Icons.Default.AdminPanelSettings, contentDescription = null, tint = RoleAdminColor, modifier = Modifier.size(36.dp))
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = "لوحة التحكم والإشراف المركزي (الإدارة)",
                                    fontWeight = FontWeight.ExtraBold,
                                    style = MaterialTheme.typography.titleMedium,
                                    color = RoleAdminColor
                                )
                                Text(
                                    text = "صلاحيات حصرية لمراجعة المتاجر والمنتجات وإدارة التوصيل وعمولات المنصة.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                when (selectedTab) {
                    0 -> {
                        // Operational KPIs
                        item {
                            Text("المؤشرات التشغيلية للمنصة", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                        }

                        item {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                KpiCard(
                                    title = "المتاجر المعتمدة",
                                    value = "${stores.count { it.status == StoreStatus.APPROVED }}",
                                    icon = Icons.Default.Store,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.weight(1f)
                                )
                                KpiCard(
                                    title = "طلبات فتح المتاجر",
                                    value = "${pendingStores.size}",
                                    icon = Icons.Default.PendingActions,
                                    color = StatusWarning,
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }

                        item {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                KpiCard(
                                    title = "منتجات تنتظر المراجعة",
                                    value = "${pendingProducts.size}",
                                    icon = Icons.Default.Rule,
                                    color = if (pendingProducts.isEmpty()) StatusSuccess else StatusError,
                                    modifier = Modifier.weight(1f)
                                )
                                KpiCard(
                                    title = "إجمالي الطلبات",
                                    value = "${orders.size}",
                                    icon = Icons.Default.ReceiptLong,
                                    color = MaterialTheme.colorScheme.secondary,
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }

                        item {
                            val totalPlatformCommission = orders.sumOf { it.platformCommission }
                            Card(
                                shape = RoundedCornerShape(16.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Text("أرباح وعمولات المنصة المحتسبة", fontWeight = FontWeight.Bold)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(
                                        "${String.format("%,.0f", totalPlatformCommission)} ر.ي",
                                        style = MaterialTheme.typography.headlineMedium,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = StatusSuccess
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        "محتسبة بنسبة قابلة للضبط (8% - 10%) وفق سياسة كل متجر.",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }

                    1 -> {
                        // Store Approval Queue
                        item {
                            Text(
                                text = "طلبات فتح المتاجر المعلقة (${pendingStores.size})",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        if (pendingStores.isEmpty()) {
                            item {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(32.dp)
                                    ) {
                                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = StatusSuccess, modifier = Modifier.size(48.dp))
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text("تم تدقيق واعتماد جميع المتاجر!", fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }

                        items(pendingStores, key = { it.id }) { store ->
                            Card(
                                shape = RoundedCornerShape(16.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(store.name, fontWeight = FontWeight.ExtraBold, style = MaterialTheme.typography.titleMedium)
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = StatusWarning.copy(alpha = 0.15f)
                                        ) {
                                            Text(
                                                "بانتظار القرار",
                                                color = StatusWarning,
                                                fontWeight = FontWeight.Bold,
                                                style = MaterialTheme.typography.labelSmall,
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                            )
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text("وصف النشاط: ${store.description}", style = MaterialTheme.typography.bodySmall)
                                    Text("هاتف التواصل: ${store.phone}", style = MaterialTheme.typography.bodySmall)

                                    Divider(modifier = Modifier.padding(vertical = 12.dp))

                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        OutlinedButton(
                                            onClick = { rejectStoreDialogTarget = store },
                                            colors = ButtonDefaults.outlinedButtonColors(contentColor = StatusError),
                                            shape = RoundedCornerShape(8.dp),
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Text("رفض مع توثيق السبب")
                                        }

                                        Button(
                                            onClick = { repository.adminApproveStore(store.id) },
                                            colors = ButtonDefaults.buttonColors(containerColor = StatusSuccess),
                                            shape = RoundedCornerShape(8.dp),
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text("اعتماد المتجر")
                                        }
                                    }
                                }
                            }
                        }

                        // List of already approved stores
                        item {
                            Spacer(modifier = Modifier.height(12.dp))
                            Text("المتاجر المعتمدة النشطة", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
                        }

                        items(stores.filter { it.status == StoreStatus.APPROVED }, key = { it.id }) { store ->
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    modifier = Modifier.padding(14.dp)
                                ) {
                                    Column {
                                        Text(store.name, fontWeight = FontWeight.Bold)
                                        Text("عمولة المنصة: ${(store.commissionRate * 100).toInt()}%", style = MaterialTheme.typography.labelSmall)
                                    }
                                    Icon(Icons.Default.Verified, contentDescription = null, tint = StatusSuccess)
                                }
                            }
                        }
                    }

                    2 -> {
                        // Product Quality Assurance / Review Queue
                        item {
                            Text(
                                text = "المنتجات المعلقة للمراجعة قبل النشر (${pendingProducts.size})",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        if (pendingProducts.isEmpty()) {
                            item {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(32.dp)
                                    ) {
                                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = StatusSuccess, modifier = Modifier.size(48.dp))
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text("تم تدقيق جميع المنتجات ولا توجد طلبات معلقة!", fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }

                        items(pendingProducts, key = { it.id }) { product ->
                            Card(
                                shape = RoundedCornerShape(16.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(product.name, fontWeight = FontWeight.ExtraBold, style = MaterialTheme.typography.titleMedium)
                                        Text(product.storeName, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                                    }

                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(product.description, style = MaterialTheme.typography.bodySmall)
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(
                                        "السعر المقترح: ${String.format("%,.0f", product.price)} ر.ي  |  التصنيف: ${product.category}",
                                        style = MaterialTheme.typography.bodySmall,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )

                                    Divider(modifier = Modifier.padding(vertical = 12.dp))

                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        OutlinedButton(
                                            onClick = { rejectProductDialogTarget = product },
                                            colors = ButtonDefaults.outlinedButtonColors(contentColor = StatusError),
                                            shape = RoundedCornerShape(8.dp),
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Text("رفض مع ملاحظات")
                                        }

                                        Button(
                                            onClick = { repository.adminApproveProduct(product.id) },
                                            colors = ButtonDefaults.buttonColors(containerColor = StatusSuccess),
                                            shape = RoundedCornerShape(8.dp),
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text("اعتماد ونشر للعملاء")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    3 -> {
                        // Internal Delivery Dispatch
                        item {
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                            ) {
                                Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.ElectricRickshaw, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Text(
                                        text = "وفق الاتفاق: التوصيل يتم عبر آلية داخلية يديرها موظفو المنصة يدوياً بدون تكامل خارجي. الإدارة تتابع تسليم الطلبات للعميل.",
                                        style = MaterialTheme.typography.bodySmall
                                    )
                                }
                            }
                        }

                        items(orders, key = { it.id }) { order ->
                            Card(
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(order.orderNumber, fontWeight = FontWeight.Bold)
                                        Text(order.status.labelAr, fontWeight = FontWeight.Bold, color = RoleAdminColor)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text("المتجر: ${order.storeName}  |  العميل: ${order.customerName}", style = MaterialTheme.typography.bodySmall)
                                    Text("العنوان: ${order.deliveryAddress}", style = MaterialTheme.typography.bodySmall)

                                    if (order.status == OrderStatus.OUT_FOR_DELIVERY) {
                                        Spacer(modifier = Modifier.height(10.dp))
                                        Button(
                                            onClick = { repository.updateOrderStatus(order.id, OrderStatus.DELIVERED) },
                                            colors = ButtonDefaults.buttonColors(containerColor = StatusSuccess),
                                            shape = RoundedCornerShape(8.dp),
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Icon(Icons.Default.DoneAll, contentDescription = null)
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Text("تأكيد التسليم الفعلي للعميل (تم التسليم)")
                                        }
                                    }
                                }
                            }
                    }

                    4 -> {
                        // Room Database User Management via UserViewModel StateFlow
                        item {
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f)
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(14.dp)
                                ) {
                                    Icon(Icons.Default.Storage, contentDescription = null, tint = RoleAdminColor)
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Column {
                                        Text(
                                            text = "إدارة مستخدمي قاعدة بيانات Room المحلية",
                                            fontWeight = FontWeight.Bold,
                                            style = MaterialTheme.typography.bodyMedium
                                        )
                                        Text(
                                            text = "مربوطة مباشرة بـ UserViewModel وتدفقات StateFlow المباشرة.",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        }

                        if (userViewModel != null) {
                            val users by userViewModel.filteredUsers.collectAsState()
                            val searchQuery by userViewModel.searchQuery.collectAsState()
                            val selectedRoleFilter by userViewModel.selectedRoleFilter.collectAsState()

                            item {
                                OutlinedTextField(
                                    value = searchQuery,
                                    onValueChange = { userViewModel.setSearchQuery(it) },
                                    placeholder = { Text("بحث في قاعدة البيانات المحلية...") },
                                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                                    singleLine = true,
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.fillMaxWidth().testTag("room_users_search")
                                )
                            }

                            item {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    listOf("all" to "الكل", "customer" to "العملاء", "seller" to "البائعون", "admin" to "الإدارة").forEach { (key, label) ->
                                        FilterChip(
                                            selected = selectedRoleFilter == key,
                                            onClick = { userViewModel.setRoleFilter(key) },
                                            label = { Text(label, fontSize = 12.sp) }
                                        )
                                    }
                                }
                            }

                            item {
                                Row(
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text(
                                        text = "المستخدمون المخزنون محلياً (${users.size})",
                                        fontWeight = FontWeight.Bold,
                                        style = MaterialTheme.typography.titleSmall
                                    )
                                    Button(
                                        onClick = { showAddUserDialog = true },
                                        shape = RoundedCornerShape(10.dp),
                                        colors = ButtonDefaults.buttonColors(containerColor = RoleAdminColor)
                                    ) {
                                        Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("إضافة مستخدم", fontSize = 12.sp)
                                    }
                                }
                            }

                            if (users.isEmpty()) {
                                item {
                                    Card(
                                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Column(
                                            horizontalAlignment = Alignment.CenterHorizontally,
                                            modifier = Modifier.fillMaxWidth().padding(24.dp)
                                        ) {
                                            Icon(Icons.Default.SearchOff, contentDescription = null, modifier = Modifier.size(40.dp))
                                            Spacer(modifier = Modifier.height(8.dp))
                                            Text("لا يوجد مستخدمون مطابقون في Room DB")
                                        }
                                    }
                                }
                            }

                            items(users, key = { it.id }) { userEntity ->
                                Card(
                                    shape = RoundedCornerShape(14.dp),
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(14.dp)) {
                                        Row(
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Column(modifier = Modifier.weight(1f)) {
                                                Text(userEntity.fullName, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
                                                Text(userEntity.email, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                                Text(userEntity.phoneNumber, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.outline)
                                            }

                                            // Status Badge
                                            Surface(
                                                shape = RoundedCornerShape(6.dp),
                                                color = if (userEntity.status == "active") StatusSuccess.copy(alpha = 0.15f) else StatusError.copy(alpha = 0.15f)
                                            ) {
                                                Text(
                                                    text = if (userEntity.status == "active") "نشط" else "موقوف",
                                                    color = if (userEntity.status == "active") StatusSuccess else StatusError,
                                                    style = MaterialTheme.typography.labelSmall,
                                                    fontWeight = FontWeight.Bold,
                                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                                )
                                            }
                                        }

                                        Spacer(modifier = Modifier.height(8.dp))
                                        Row(
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text(
                                                "الدور: ${userEntity.role} ${if (userEntity.storeId != null) "(متجر #${userEntity.storeId})" else ""}",
                                                style = MaterialTheme.typography.labelSmall,
                                                fontWeight = FontWeight.SemiBold,
                                                color = MaterialTheme.colorScheme.primary
                                            )

                                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                // Toggle Status Button
                                                OutlinedButton(
                                                    onClick = {
                                                        val nextStatus = if (userEntity.status == "active") "suspended" else "active"
                                                        userViewModel.updateUserStatus(userEntity.id, nextStatus)
                                                    },
                                                    shape = RoundedCornerShape(8.dp)
                                                ) {
                                                    Text(if (userEntity.status == "active") "تجميد الحساب" else "تنشيط", fontSize = 11.sp)
                                                }

                                                // Delete Button
                                                IconButton(
                                                    onClick = { userViewModel.deleteUser(userEntity.id) },
                                                    modifier = Modifier.size(36.dp)
                                                ) {
                                                    Icon(Icons.Default.DeleteOutline, contentDescription = "Delete", tint = StatusError)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Reject Store Dialog
    rejectStoreDialogTarget?.let { store ->
        var reason by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { rejectStoreDialogTarget = null },
            title = { Text("رفض طلب فتح المتجر", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text("سجل سبب الرفض ليظهر للبائع حتى يتمكن من تعديله:")
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = reason,
                        onValueChange = { reason = it },
                        label = { Text("سبب الرفض") },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp)
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        repository.adminRejectStore(store.id, reason)
                        rejectStoreDialogTarget = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = StatusError),
                    enabled = reason.isNotBlank()
                ) {
                    Text("تأكيد الرفض")
                }
            },
            dismissButton = {
                TextButton(onClick = { rejectStoreDialogTarget = null }) {
                    Text("إلغاء")
                }
            }
        )
    }

    // Reject Product Dialog
    rejectProductDialogTarget?.let { product ->
        var notes by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { rejectProductDialogTarget = null },
            title = { Text("رفض نشر المنتج", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text("سجل ملاحظات الإدارة للبائع (مثل جودة الوصف أو السعر):")
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = notes,
                        onValueChange = { notes = it },
                        label = { Text("الملاحظات") },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp)
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        repository.adminRejectProduct(product.id, notes)
                        rejectProductDialogTarget = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = StatusError),
                    enabled = notes.isNotBlank()
                ) {
                    Text("تسجيل الرفض")
                }
            },
            dismissButton = {
                TextButton(onClick = { rejectProductDialogTarget = null }) {
                    Text("إلغاء")
                }
            }
        )
    }

    // Add User to Room Dialog
    if (showAddUserDialog && userViewModel != null) {
        var name by remember { mutableStateOf("") }
        var email by remember { mutableStateOf("") }
        var phone by remember { mutableStateOf("") }
        var role by remember { mutableStateOf("customer") }
        var storeIdStr by remember { mutableStateOf("") }

        AlertDialog(
            onDismissRequest = { showAddUserDialog = false },
            title = { Text("إضافة مستخدم جديد إلى Room DB", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = name,
                        onValueChange = { name = it },
                        label = { Text("الاسم الكامل") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it },
                        label = { Text("البريد الإلكتروني") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = phone,
                        onValueChange = { phone = it },
                        label = { Text("رقم الهاتف") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Text("الدور:", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodySmall)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("customer" to "عميل", "seller" to "بائع", "admin" to "إدارة").forEach { (r, label) ->
                            FilterChip(
                                selected = role == r,
                                onClick = { role = r },
                                label = { Text(label) }
                            )
                        }
                    }
                    if (role == "seller") {
                        OutlinedTextField(
                            value = storeIdStr,
                            onValueChange = { storeIdStr = it },
                            label = { Text("معرف المتجر التابع له (Store ID)") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val newId = (System.currentTimeMillis() % 10000).toInt() + 1000
                        val entity = UserEntity(
                            id = newId,
                            email = email,
                            fullName = name,
                            phoneNumber = phone,
                            role = role,
                            status = "active",
                            storeId = storeIdStr.toIntOrNull()
                        )
                        userViewModel.insertUser(entity)
                        showAddUserDialog = false
                    },
                    enabled = name.isNotBlank() && email.isNotBlank()
                ) {
                    Text("إضافة وحفظ")
                }
            },
            dismissButton = {
                TextButton(onClick = { showAddUserDialog = false }) {
                    Text("إلغاء")
                }
            }
        )
    }
}

@Composable
fun KpiCard(
    title: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = modifier
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(24.dp))
            Spacer(modifier = Modifier.height(8.dp))
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.ExtraBold, color = color)
            Text(title, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
