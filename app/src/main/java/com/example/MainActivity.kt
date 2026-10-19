package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.example.data.PlatformRepository
import com.example.data.local.AppDatabase
import com.example.data.local.LocalUserRepository
import com.example.ui.screens.MainAppScreen
import com.example.ui.theme.MyApplicationTheme

import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.ui.viewmodel.UserViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                val context = LocalContext.current
                val database = remember { AppDatabase.getDatabase(context) }
                val localUserRepository = remember { LocalUserRepository(database.userDao()) }
                val repository = remember { PlatformRepository(localUserRepository) }
                val userViewModel: UserViewModel = viewModel(
                    factory = UserViewModel.Factory(database.userDao())
                )
                Surface(modifier = Modifier.fillMaxSize()) {
                    MainAppScreen(
                        repository = repository,
                        userViewModel = userViewModel
                    )
                }
            }
        }
    }
}
