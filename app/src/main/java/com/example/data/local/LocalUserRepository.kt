package com.example.data.local

import com.example.model.User
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * Repository abstracting Room database operations for User management.
 */
class LocalUserRepository(private val userDao: UserDao) {

    val allUsers: Flow<List<User>> = userDao.getAllUsers().map { entities ->
        entities.map { it.toDomainUser() }
    }

    val activeUsers: Flow<List<User>> = userDao.getActiveUsers().map { entities ->
        entities.map { it.toDomainUser() }
    }

    fun getUserById(userId: Int): Flow<User?> = userDao.getUserById(userId).map { it?.toDomainUser() }

    suspend fun getUserByIdOnce(userId: Int): User? = userDao.getUserByIdOnce(userId)?.toDomainUser()

    suspend fun getUserByEmail(email: String): User? = userDao.getUserByEmail(email)?.toDomainUser()

    fun getUsersByRole(role: String): Flow<List<User>> = userDao.getUsersByRole(role).map { entities ->
        entities.map { it.toDomainUser() }
    }

    fun searchUsers(query: String): Flow<List<User>> = userDao.searchUsers(query).map { entities ->
        entities.map { it.toDomainUser() }
    }

    suspend fun insertUser(user: User) {
        userDao.insertUser(UserEntity.fromDomainUser(user))
    }

    suspend fun updateUserStatus(userId: Int, status: String) {
        userDao.updateUserStatus(userId, status)
    }

    suspend fun updateUserProfile(userId: Int, fullName: String, phone: String) {
        userDao.updateUserProfile(userId, fullName, phone)
    }

    suspend fun deleteUserById(userId: Int) {
        userDao.deleteUserById(userId)
    }

    suspend fun countUsers(): Int {
        return userDao.getUsersCount()
    }
}
