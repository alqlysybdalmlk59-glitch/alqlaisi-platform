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
                title = { 
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("منصة القليسي", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                    }
                },
                actions = {
                    IconButton(onClick = { /* Notifications */ }) {
                        BadgedBox(badge = { Badge { Text("2") } }) {
                            Icon(Icons.Default.Notifications, contentDescription = "الإشعارات")
                        }
                    }
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
                    icon = { Icon(Icons.Default.Home, contentDescription = null) },
                    label = { Text("الرئيسية") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.Category, contentDescription = null) },
                    label = { Text("الفئات") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.Explore, contentDescription = null) },
                    label = { Text("استكشاف") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = {
                        BadgedBox(badge = { if (cart.isNotEmpty()) Badge { Text("${cart.sumOf { it.quantity }}") } }) {
                            Icon(Icons.Default.ShoppingCart, contentDescription = null)
                        }
                    },
                    label = { Text("السلة") }
                )
                NavigationBarItem(
                    selected = selectedTab == 4,
                    onClick = { selectedTab = 4 },
                    icon = { Icon(Icons.Default.Person, contentDescription = null) },
                    label = { Text("حسابي") }
                )
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (selectedTab) {
                0, 2 -> ClientStoreCatalogView(
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
                1 -> CategoriesGridView(
                    products = publishedProducts,
                    onProductClick = { selectedProductForDetail = it }
                )
                3 -> CartView(
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
                4 -> ClientProfileView(currentUser)
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
    val categories = listOf("الكل", "دفاتر وكراسات", "أقلام وأدوات كتابة", "حقائب مدرسية", "كتب ومراجع", "ورق ومواد طباعة")

    val filteredProducts = products.filter { product ->
        val matchesSearch = product.title.contains(searchQuery, ignoreCase = true) ||
            product.vendorName.contains(searchQuery, ignoreCase = true) ||
            product.description.contains(searchQuery, ignoreCase = true) ||
            product.category.contains(searchQuery, ignoreCase = true)
        val matchesCategory = selectedCategory == "الكل" || product.category == selectedCategory
        matchesSearch && matchesCategory
    }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("أنا أتسوق لـ...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            )
        }

        // Promotional Banner Carousel
        item {
            Card(
                modifier = Modifier.fillMaxWidth().height(150.dp),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
            ) {
                Box(modifier = Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.CenterStart) {
                    Column {
                        Text("خصومات كبرى تصل إلى 25% حصرياً", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.onPrimaryContainer)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("تسوق الآن أحدث المنتجات والقرطاسية المدرسية والأجهزة", fontSize = 13.sp, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f))
                    }
                }
            }
        }

        // Featured Categories
        item {
            Text("الفئات المميزة", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Spacer(modifier = Modifier.height(8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(categories) { cat ->
                    FilterChip(
                        selected = selectedCategory == cat,
                        onClick = { selectedCategory = cat },
                        label = { Text(cat) }
                    )
                }
            }
        }

        item {
            Text("المنتجات المتاحة", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }

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

@Composable
fun CategoriesGridView(products: List<Product>, onProductClick: (Product) -> Unit) {
    val categories = listOf("أجهزة الكمبيوتر", "ملابس", "إلكترونيات", "الصحة والجمال", "مجوهرات ومشاهدة")
    var selectedCat by remember { mutableStateOf(categories.first()) }
    val catProducts = products.filter { it.category == selectedCat || selectedCat.isEmpty() }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("استعراض التصنيفات", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(modifier = Modifier.height(12.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(categories) { cat ->
                FilterChip(
                    selected = selectedCat == cat,
                    onClick = { selectedCat = cat },
                    label = { Text(cat) }
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(catProducts) { product ->
                Card(modifier = Modifier.fillMaxWidth(), onClick = { onProductClick(product) }) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        AsyncImage(model = product.imageUrl, contentDescription = null, modifier = Modifier.size(60.dp).clip(RoundedCornerShape(8.dp)), contentScale = ContentScale.Crop)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(product.title, fontWeight = FontWeight.Bold)
                            Text("${product.price} ر.ي", color = MaterialTheme.colorScheme.primary)
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
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = onCheckout, modifier = Modifier.fillMaxWidth()) {
                        Text("تأكيد الطلب وإرساله")
                    }
                }
            }
        }
    }
}

@Composable
fun ClientProfileView(currentUser: User?) {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.AccountCircle, contentDescription = null, modifier = Modifier.size(80.dp), tint = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.height(12.dp))
                Text(currentUser?.name ?: "مستخدم", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text(currentUser?.email ?: "", color = MaterialTheme.colorScheme.secondary)
                Text("الهاتف: ${currentUser?.phone}", fontSize = 14.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text("العنوان: ${currentUser?.address}", fontSize = 14.sp)
            }
        }
    }
}
