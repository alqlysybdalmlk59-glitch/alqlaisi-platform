package com.example.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.data.local.UserDao
import com.example.data.local.UserEntity
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

/**
 * UI State representing the state of user data loaded from Room database.
 */
sealed interface UserUiState {
    data object Loading : UserUiState
    data class Success(val users: List<UserEntity>) : UserUiState
    data class Error(val message: String) : UserUiState
}

/**
 * ViewModel that uses [UserDao] to expose database operations to the UI layer using StateFlow.
 * Follows modern Android MVVM and reactive patterns.
 */
class UserViewModel(
    private val userDao: UserDao
) : ViewModel() {

    // -------------------------------------------------------------
    // Reactive Streams from Room DAO
    // -------------------------------------------------------------

    /**
     * Complete list of users observed reactively from Room.
     */
    val allUsers: StateFlow<List<UserEntity>> = userDao.getAllUsers()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    /**
     * Active users only.
     */
    val activeUsers: StateFlow<List<UserEntity>> = userDao.getActiveUsers()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    // -------------------------------------------------------------
    // UI Filters and Selection State
    // -------------------------------------------------------------
    private val _selectedRoleFilter = MutableStateFlow("all") // "all", "customer", "seller", "admin"
    val selectedRoleFilter: StateFlow<String> = _selectedRoleFilter.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _selectedUser = MutableStateFlow<UserEntity?>(null)
    val selectedUser: StateFlow<UserEntity?> = _selectedUser.asStateFlow()

    private val _operationMessage = MutableStateFlow<String?>(null)
    val operationMessage: StateFlow<String?> = _operationMessage.asStateFlow()

    /**
     * Dynamically filtered users based on role filter and search query.
     */
    val filteredUsers: StateFlow<List<UserEntity>> = combine(
        allUsers,
        _selectedRoleFilter,
        _searchQuery
    ) { users, roleFilter, query ->
        users.filter { user ->
            val matchesRole = roleFilter == "all" || user.role.equals(roleFilter, ignoreCase = true)
            val matchesQuery = query.isBlank() ||
                    user.fullName.contains(query, ignoreCase = true) ||
                    user.email.contains(query, ignoreCase = true) ||
                    user.phoneNumber.contains(query)
            matchesRole && matchesQuery
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    /**
     * High-level UI state wrapping the filtered users stream.
     */
    val uiState: StateFlow<UserUiState> = filteredUsers
        .map<List<UserEntity>, UserUiState> { users ->
            UserUiState.Success(users)
        }
        .catch { e ->
            emit(UserUiState.Error(e.message ?: "حدث خطأ غير متوقع أثناء تحميل المستخدمين"))
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = UserUiState.Loading
        )

    // -------------------------------------------------------------
    // Database Operations (CRUD Actions)
    // -------------------------------------------------------------

    /**
     * Inserts or updates a user in Room database.
     */
    fun insertUser(user: UserEntity) {
        viewModelScope.launch {
            try {
                userDao.insertUser(user)
                _operationMessage.value = "تم حفظ المستخدم '${user.fullName}' بنجاح في قاعدة البيانات المحلية"
            } catch (e: Exception) {
                _operationMessage.value = "فشل حفظ المستخدم: ${e.message}"
            }
        }
    }

    /**
     * Updates profile details of an existing user.
     */
    fun updateUserProfile(userId: Int, fullName: String, phone: String) {
        viewModelScope.launch {
            try {
                userDao.updateUserProfile(userId, fullName, phone)
                _operationMessage.value = "تم تحديث الملف الشخصي بنجاح"
            } catch (e: Exception) {
                _operationMessage.value = "فشل تحديث البيانات: ${e.message}"
            }
        }
    }

    /**
     * Updates account status (e.g. active, suspended) by admin.
     */
    fun updateUserStatus(userId: Int, newStatus: String) {
        viewModelScope.launch {
            try {
                userDao.updateUserStatus(userId, newStatus)
                _operationMessage.value = "تم تعديل حالة الحساب إلى: $newStatus"
            } catch (e: Exception) {
                _operationMessage.value = "فشل تعديل الحالة: ${e.message}"
            }
        }
    }

    /**
     * Deletes a user from Room database.
     */
    fun deleteUser(userId: Int) {
        viewModelScope.launch {
            try {
                userDao.deleteUserById(userId)
                if (_selectedUser.value?.id == userId) {
                    _selectedUser.value = null
                }
                _operationMessage.value = "تم حذف المستخدم بنجاح"
            } catch (e: Exception) {
                _operationMessage.value = "فشل الحذف: ${e.message}"
            }
        }
    }

    /**
     * Selects a user for detailed inspection or editing in the UI.
     */
    fun selectUser(user: UserEntity?) {
        _selectedUser.value = user
    }

    /**
     * Sets active role filter (all, customer, seller, admin).
     */
    fun setRoleFilter(role: String) {
        _selectedRoleFilter.value = role
    }

    /**
     * Sets live search filter query.
     */
    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    /**
     * Clears user feedback toast/message.
     */
    fun clearOperationMessage() {
        _operationMessage.value = null
    }

    // -------------------------------------------------------------
    // Factory for instantiation
    // -------------------------------------------------------------
    class Factory(private val userDao: UserDao) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(UserViewModel::class.java)) {
                return UserViewModel(userDao) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
        }
    }
}
