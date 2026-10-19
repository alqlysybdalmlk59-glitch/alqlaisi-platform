package com.alqulaisi.platform.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.alqulaisi.platform.data.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClientPortalScreen(onLogout: () -> Unit) {
    var selectedTab by remember { mutableStateOf(0) }
    val products by EcommerceRepository.products.collectAsState()
    val publishedProducts = products.filter { it.reviewStatus == ProductReviewStatus.PUBLISHED }
    val cart by EcommerceRepository.cart.collectAsState()
    val orders by EcommerceRepository.orders.collectAsState()
    val currentUser by EcommerceRepository.currentUser.collectAsState()
    var snackbarMessage by remember { mutableStateOf<String?>(null) }
    var selectedProductForDetail by remember { mutableStateOf<Product?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(when(selectedTab) { 0 -> "متجر القليسي"; 1 -> "سلة التسوق"; 2 -> "طلباتي"; else -> "حسابي والدعم" }) },
                actions = {
                    IconButton(onClick = onLogout) {
                        Icon(Icons.Default.ExitToApp, contentDescription = "تسجيل خروج")
                    }
                }
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.Store, contentDescription = null) },
                    label = { Text("المتجر") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = {
                        BadgedBox(badge = { if (cart.isNotEmpty()) Badge { Text("${cart.sumOf { it.quantity }}") } }) {
                            Icon(Icons.Default.ShoppingCart, contentDescription = null)
                        }
                    },
                    label = { Text("السلة") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.ListAlt, contentDescription = null) },
                    label = { Text("الطلبات") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Default.Person, contentDescription = null) },
                    label = { Text("حسابي") }
                )
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (selectedTab) {
                0 -> ClientStoreCatalogView(
                    products = publishedProducts,
                    onProductClick = { selectedProductForDetail = it },
                    onAddToCart = { product ->
                        if (product.isAvailable) {
                            EcommerceRepository.addToCart(product)
                            snackbarMessage = "تمت إضافة ${product.title} إلى السلة"
                        } else {
                            snackbarMessage = "المنتج غير متاح حالياً"
                        }
                    }
                )
                1 -> CartView(
                    cart = cart,
                    onRemove = { EcommerceRepository.removeFromCart(it) },
                    onCheckout = {
                        val success = EcommerceRepository.checkout()
                        if (success) {
                            snackbarMessage = "تم إرسال الطلبات بنجاح وتقسيمها حسب المتاجر!"
                            selectedTab = 2
                        }
                    }
                )
                2 -> OrdersView(orders.filter { it.clientId == currentUser?.id })
                3 -> ClientProfileView(currentUser)
            }

            selectedProductForDetail?.let { product ->
                ProductDetailDialog(
                    product = product,
                    onDismiss = { selectedProductForDetail = null },
                    onAddToCart = {
                        EcommerceRepository.addToCart(product)
                        snackbarMessage = "تمت إضافة المنتج إلى السلة"
                        selectedProductForDetail = null
                    }
                )
            }

            snackbarMessage?.let { msg ->
                Snackbar(
                    modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                    action = { TextButton(onClick = { snackbarMessage = null }) { Text("إغلاق") } }
                ) { Text(msg) }
            }
        }
    }
}

@Composable
fun ClientStoreCatalogView(
    products: List<Product>,
    onProductClick: (Product) -> Unit,
    onAddToCart: (Product) -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("الكل") }
    val categories = listOf("الكل", "إلكترونيات", "أزياء", "صحة وجمال")

    val filteredProducts = products.filter { product ->
        val matchesSearch = product.title.contains(searchQuery, ignoreCase = true) || product.vendorName.contains(searchQuery, ignoreCase = true)
        val matchesCategory = selectedCategory == "الكل" || product.category == selectedCategory
        matchesSearch && matchesCategory
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = { searchQuery = it },
            placeholder = { Text("ابحث عن منتج أو متجر...") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(12.dp))

        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(categories) { cat ->
                FilterChip(
                    selected = selectedCategory == cat,
                    onClick = { selectedCategory = cat },
                    label = { Text(cat) }
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            items(filteredProducts) { product ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    onClick = { onProductClick(product) }
                ) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        AsyncImage(
                            model = product.imageUrl,
                            contentDescription = null,
                            modifier = Modifier.size(80.dp).clip(RoundedCornerShape(8.dp)),
                            contentScale = ContentScale.Crop
                        )
                        Spacer(modifier = Modifier.width(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(product.title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text("المتجر: ${product.vendorName}", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("${product.price} ر.ي", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = if (product.isAvailable) "متاح" else "غير متاح مؤقتاً",
                                    fontSize = 11.sp,
                                    color = if (product.isAvailable) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                                )
                            }
                        }
                        Button(
                            onClick = { onAddToCart(product) },
                            enabled = product.isAvailable
                        ) {
                            Icon(Icons.Default.AddShoppingCart, contentDescription = null, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ProductDetailDialog(product: Product, onDismiss: () -> Unit, onAddToCart: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(product.title, fontWeight = FontWeight.Bold) },
        text = {
            Column {
                AsyncImage(
                    model = product.imageUrl,
                    contentDescription = null,
                    modifier = Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text("المتجر: ${product.vendorName}", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.secondary)
                Spacer(modifier = Modifier.height(4.dp))
                Text(product.description, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text("السعر: ${product.price} ر.ي", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.primary)
            }
        },
        confirmButton = {
            Button(onClick = onAddToCart, enabled = product.isAvailable) {
                Text("إضافة إلى السلة")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("إغلاق") }
        }
    )
}

@Composable
fun CartView(cart: List<CartItem>, onRemove: (String) -> Unit, onCheckout: () -> Unit) {
    val itemsByVendor = cart.groupBy { it.product.vendorId }
    val totalItemsPrice = cart.sumOf { it.product.price * it.quantity }
    val totalDeliveryFee = itemsByVendor.size * 15.0

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        if (cart.isEmpty()) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Text("سلة التسوق فارغة", color = MaterialTheme.colorScheme.secondary)
            }
        } else {
            LazyColumn(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                items(itemsByVendor.keys.toList()) { vendorId ->
                    val vendorItems = itemsByVendor[vendorId] ?: emptyList()
                    val vendorName = vendorItems.firstOrNull()?.product?.vendorName ?: ""

                    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text("طلب منفصل لمتجر: $vendorName", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            Text("رسوم التوصيل: 15.0 ر.ي", fontSize = 12.sp)
                            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

                            vendorItems.forEach { item ->
                                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(item.product.title, fontWeight = FontWeight.SemiBold)
                                        Text("الكمية: ${item.quantity} | ${item.product.price * item.quantity} ر.ي", fontSize = 12.sp)
                                    }
                                    IconButton(onClick = { onRemove(item.product.id) }) {
                                        Icon(Icons.Default.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("مجموع المنتجات:")
                        Text("$totalItemsPrice ر.ي")
                    }
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("إجمالي التوصيل (${itemsByVendor.size} متاجر):")
                        Text("$totalDeliveryFee ر.ي")
                    }
                    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("الإجمالي الكلي:", fontWeight = FontWeight.Bold)
                        Text("${totalItemsPrice + totalDeliveryFee} ر.ي", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary, fontSize = 18.sp)
                    }
                    Text("طريقة الدفع: الدفع عند الاستلام", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary, modifier = Modifier.padding(top = 4.dp))
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
            Button(
                onClick = onCheckout,
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("تأكيد الطلب والدفع عند الاستلام", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun OrdersView(orders: List<Order>) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items(orders) { order ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("طلب #: ${order.id}", fontWeight = FontWeight.Bold)
                        Text(order.status, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("المتجر: ${order.vendorName}", fontSize = 13.sp)
                    Text("العنوان: ${order.address}", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("الإجمالي: ${order.totalPrice} ر.ي (${order.paymentMethod})", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
fun ClientProfileView(user: User?) {
    var ticketSubject by remember { mutableStateOf("") }
    var ticketDetails by remember { mutableStateOf("") }
    var showSupportDialog by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("الملف الشخصي", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text("الاسم: ${user?.name}")
                Text("البريد: ${user?.email}")
                Text("الهاتف: ${user?.phone}")
                Text("العنوان الافتراضي: ${user?.address}")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = { showSupportDialog = true },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(Icons.Default.SupportAgent, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("تقديم طلب دعم أو شكوى")
        }

        if (showSupportDialog) {
            AlertDialog(
                onDismissRequest = { showSupportDialog = false },
                title = { Text("تقديم طلب دعم") },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(value = ticketSubject, onValueChange = { ticketSubject = it }, label = { Text("عنوان الشكوى أو الطلب") })
                        OutlinedTextField(value = ticketDetails, onValueChange = { ticketDetails = it }, label = { Text("التفاصيل") })
                    }
                },
                confirmButton = {
                    Button(onClick = {
                        if (ticketSubject.isNotBlank()) {
                            EcommerceRepository.addSupportTicket(ticketSubject, ticketDetails)
                            showSupportDialog = false
                        }
                    }) {
                        Text("إرسال")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showSupportDialog = false }) { Text("إلغاء") }
                }
            )
        }
    }
}
