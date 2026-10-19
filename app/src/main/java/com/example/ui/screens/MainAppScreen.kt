package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
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
import com.example.model.UserRole
import com.example.ui.theme.RoleAdminColor
import com.example.ui.theme.RoleCustomerColor
import com.example.ui.theme.RoleSellerColor
import com.example.ui.viewmodel.UserViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainAppScreen(
    repository: PlatformRepository,
    userViewModel: UserViewModel? = null,
    modifier: Modifier = Modifier
) {
    val currentUser by repository.currentUser.collectAsState()
    var currentNavIndex by remember { mutableStateOf(0) }
    var showRoleSwitcherMenu by remember { mutableStateOf(false) }

    // Synchronize bottom nav selection when user switches role from the top bar
    LaunchedEffect(currentUser.role) {
        currentNavIndex = when (currentUser.role) {
            UserRole.CUSTOMER -> 0
            UserRole.SELLER -> 1
            UserRole.ADMIN -> 2
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.size(36.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    Icons.Default.Storefront,
                                    contentDescription = "Logo",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(22.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "منصة القليسي",
                                fontWeight = FontWeight.ExtraBold,
                                style = MaterialTheme.typography.titleMedium
                            )
                            Text(
                                text = "منظومة التجارة متعددة البائعين",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                },
                actions = {
                    // Role Switcher Button
                    Box {
                        FilledTonalButton(
                            onClick = { showRoleSwitcherMenu = true },
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.filledTonalButtonColors(
                                containerColor = when (currentUser.role) {
                                    UserRole.CUSTOMER -> RoleCustomerColor.copy(alpha = 0.15f)
                                    UserRole.SELLER -> RoleSellerColor.copy(alpha = 0.15f)
                                    UserRole.ADMIN -> RoleAdminColor.copy(alpha = 0.15f)
                                },
                                contentColor = when (currentUser.role) {
                                    UserRole.CUSTOMER -> RoleCustomerColor
                                    UserRole.SELLER -> RoleSellerColor
                                    UserRole.ADMIN -> RoleAdminColor
                                }
                            ),
                            modifier = Modifier.testTag("role_switcher_button")
                        ) {
                            Icon(
                                when (currentUser.role) {
                                    UserRole.CUSTOMER -> Icons.Default.Person
                                    UserRole.SELLER -> Icons.Default.Store
                                    UserRole.ADMIN -> Icons.Default.Shield
                                },
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(currentUser.role.labelAr, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                        }

                        DropdownMenu(
                            expanded = showRoleSwitcherMenu,
                            onDismissRequest = { showRoleSwitcherMenu = false }
                        ) {
                            DropdownMenuItem(
                                text = {
                                    Column {
                                        Text("العميل: ${repository.customerUser.fullName}", fontWeight = FontWeight.Bold)
                                        Text("تصفح، سلة موحدة، طلبات مجزأة", style = MaterialTheme.typography.labelSmall)
                                    }
                                },
                                leadingIcon = { Icon(Icons.Default.Person, contentDescription = null, tint = RoleCustomerColor) },
                                onClick = {
                                    repository.switchUser(repository.customerUser)
                                    showRoleSwitcherMenu = false
                                },
                                modifier = Modifier.testTag("switch_to_customer")
                            )

                            Divider()

                            DropdownMenuItem(
                                text = {
                                    Column {
                                        Text("البائع أ: متجر القليسي للتقنية", fontWeight = FontWeight.Bold)
                                        Text("إدارة منتجات إلكترونية بدون مخزون", style = MaterialTheme.typography.labelSmall)
                                    }
                                },
                                leadingIcon = { Icon(Icons.Default.Store, contentDescription = null, tint = RoleSellerColor) },
                                onClick = {
                                    repository.switchUser(repository.sellerUserA)
                                    showRoleSwitcherMenu = false
                                },
                                modifier = Modifier.testTag("switch_to_seller_a")
                            )

                            DropdownMenuItem(
                                text = {
                                    Column {
                                        Text("البائع ب: أزياء النخبة", fontWeight = FontWeight.Bold)
                                        Text("متجر مستقل لعزل المستأجرين", style = MaterialTheme.typography.labelSmall)
                                    }
                                },
                                leadingIcon = { Icon(Icons.Default.Checkroom, contentDescription = null, tint = RoleSellerColor) },
                                onClick = {
                                    repository.switchUser(repository.sellerUserB)
                                    showRoleSwitcherMenu = false
                                },
                                modifier = Modifier.testTag("switch_to_seller_b")
                            )

                            Divider()

                            DropdownMenuItem(
                                text = {
                                    Column {
                                        Text("الإدارة: ${repository.adminUser.fullName}", fontWeight = FontWeight.Bold)
                                        Text("اعتماد المتاجر والمنتجات والإشراف", style = MaterialTheme.typography.labelSmall)
                                    }
                                },
                                leadingIcon = { Icon(Icons.Default.AdminPanelSettings, contentDescription = null, tint = RoleAdminColor) },
                                onClick = {
                                    repository.switchUser(repository.adminUser)
                                    showRoleSwitcherMenu = false
                                },
                                modifier = Modifier.testTag("switch_to_admin")
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                windowInsets = WindowInsets.navigationBars,
                modifier = Modifier.testTag("main_bottom_nav")
            ) {
                NavigationBarItem(
                    selected = currentNavIndex == 0,
                    onClick = { currentNavIndex = 0 },
                    icon = { Icon(if (currentNavIndex == 0) Icons.Default.ShoppingBag else Icons.Outlined.ShoppingBag, contentDescription = "Customer") },
                    label = { Text("تطبيق العميل", fontSize = 11.sp) },
                    modifier = Modifier.testTag("nav_customer")
                )

                NavigationBarItem(
                    selected = currentNavIndex == 1,
                    onClick = { currentNavIndex = 1 },
                    icon = { Icon(if (currentNavIndex == 1) Icons.Default.Store else Icons.Outlined.Store, contentDescription = "Seller") },
                    label = { Text("تطبيق البائع", fontSize = 11.sp) },
                    modifier = Modifier.testTag("nav_seller")
                )

                NavigationBarItem(
                    selected = currentNavIndex == 2,
                    onClick = { currentNavIndex = 2 },
                    icon = { Icon(if (currentNavIndex == 2) Icons.Default.AdminPanelSettings else Icons.Outlined.AdminPanelSettings, contentDescription = "Admin") },
                    label = { Text("لوحة الإدارة", fontSize = 11.sp) },
                    modifier = Modifier.testTag("nav_admin")
                )

                NavigationBarItem(
                    selected = currentNavIndex == 3,
                    onClick = { currentNavIndex = 3 },
                    icon = { Icon(if (currentNavIndex == 3) Icons.Default.Shield else Icons.Outlined.Shield, contentDescription = "Security Inspector") },
                    label = { Text("الوسيط والأمان", fontSize = 11.sp) },
                    modifier = Modifier.testTag("nav_security")
                )
            }
        },
        modifier = modifier
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when (currentNavIndex) {
                0 -> CustomerScreen(repository = repository)
                1 -> SellerScreen(repository = repository)
                2 -> AdminScreen(repository = repository, userViewModel = userViewModel)
                3 -> SecurityInspectorScreen(repository = repository)
            }
        }
    }
}
