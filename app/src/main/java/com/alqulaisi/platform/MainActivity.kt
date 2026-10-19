package com.alqulaisi.platform

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.alqulaisi.platform.data.EcommerceRepository
import com.alqulaisi.platform.data.UserRole
import com.alqulaisi.platform.ui.screens.AdminPortalScreen
import com.alqulaisi.platform.ui.screens.ClientPortalScreen
import com.alqulaisi.platform.ui.screens.LoginScreen
import com.alqulaisi.platform.ui.screens.VendorPortalScreen
import com.alqulaisi.platform.ui.theme.AlQulaisiPlatformTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AlQulaisiPlatformTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val currentUser by EcommerceRepository.currentUser.collectAsState()

                    if (currentUser == null) {
                        LoginScreen {
                            // Login handled in repository
                        }
                    } else {
                        when (currentUser?.role) {
                            UserRole.CLIENT -> ClientPortalScreen {
                                EcommerceRepository.logout()
                            }
                            UserRole.VENDOR -> VendorPortalScreen {
                                EcommerceRepository.logout()
                            }
                            UserRole.ADMIN -> AdminPortalScreen {
                                EcommerceRepository.logout()
                            }
                            null -> LoginScreen {}
                        }
                    }
                }
            }
        }
    }
}
