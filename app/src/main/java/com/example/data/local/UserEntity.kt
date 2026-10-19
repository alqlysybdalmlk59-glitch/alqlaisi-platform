package com.example.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.example.model.User
import com.example.model.UserRole
import com.example.model.UserStatus

/**
 * Room Database entity representing a user in the Al-Qulaisi platform.
 * Supports Customers, Sellers, and Admins with tenant store mapping.
 */
@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey(autoGenerate = false)
    val id: Int,

    @ColumnInfo(name = "email")
    val email: String,

    @ColumnInfo(name = "full_name")
    val fullName: String,

    @ColumnInfo(name = "phone_number")
    val phoneNumber: String,

    @ColumnInfo(name = "role")
    val role: String, // "customer", "seller", "admin"

    @ColumnInfo(name = "status")
    val status: String = "active", // "active", "suspended", "pending_approval"

    @ColumnInfo(name = "store_id")
    val storeId: Int? = null,

    @ColumnInfo(name = "auth_token")
    val authToken: String = "",

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis()
) {
    fun toDomainUser(): User {
        val domainRole = when (role.lowercase()) {
            "seller" -> UserRole.SELLER
            "admin" -> UserRole.ADMIN
            else -> UserRole.CUSTOMER
        }
        val domainStatus = when (status.lowercase()) {
            "suspended" -> UserStatus.SUSPENDED
            "pending_approval" -> UserStatus.PENDING_APPROVAL
            else -> UserStatus.ACTIVE
        }
        return User(
            id = id,
            email = email,
            fullName = fullName,
            phone = phoneNumber,
            role = domainRole,
            status = domainStatus,
            storeId = storeId,
            token = authToken
        )
    }

    companion object {
        fun fromDomainUser(user: User): UserEntity {
            return UserEntity(
                id = user.id,
                email = user.email,
                fullName = user.fullName,
                phoneNumber = user.phone,
                role = user.role.name.lowercase(),
                status = user.status.name.lowercase(),
                storeId = user.storeId,
                authToken = user.token
            )
        }
    }
}
