package com.alqulaisi.platform.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alqulaisi.platform.data.EcommerceRepository
import com.alqulaisi.platform.data.UserRole

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(onLoginSuccess: () -> Unit) {
    var email by remember { mutableStateOf("client@alqulaisi.com") }
    var selectedRole by remember { mutableStateOf(UserRole.CLIENT) }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "منصة القليسي",
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            Text(
                text = "منصة التجارة الإلكترونية متعددة البائعين",
                fontSize = 14.sp,
                color = MaterialTheme.colorScheme.secondary,
                modifier = Modifier.padding(bottom = 32.dp)
            )

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("البريد الإلكتروني") },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            Text("اختر نوع الحساب الدخول:", fontWeight = FontWeight.SemiBold, modifier = Modifier.align(Alignment.Start))
            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                FilterChip(
                    selected = selectedRole == UserRole.CLIENT,
                    onClick = { selectedRole = UserRole.CLIENT; email = "client@alqulaisi.com" },
                    label = { Text("عميل") }
                )
                FilterChip(
                    selected = selectedRole == UserRole.VENDOR,
                    onClick = { selectedRole = UserRole.VENDOR; email = "vendor@alqulaisi.com" },
                    label = { Text("بائع") }
                )
                FilterChip(
                    selected = selectedRole == UserRole.ADMIN,
                    onClick = { selectedRole = UserRole.ADMIN; email = "admin@alqulaisi.com" },
                    label = { Text("إدارة النظام") }
                )
            }

            Spacer(modifier = Modifier.height(36.dp))

            Button(
                onClick = {
                    EcommerceRepository.login(email, selectedRole)
                    onLoginSuccess()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("تسجيل الدخول", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}
