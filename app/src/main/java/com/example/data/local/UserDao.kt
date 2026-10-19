package com.example.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object (DAO) for the User entity in the Al-Qulaisi Multi-Vendor Platform.
 * Defines comprehensive Create, Read, Update, and Delete (CRUD) operations for Room database.
 */
@Dao
interface UserDao {

    // =========================================================================
    // CREATE (Insert operations)
    // =========================================================================

    /**
     * Inserts a single user into the database. If the user already exists, it is replaced.
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUser(user: UserEntity)

    /**
     * Inserts multiple users in a single transaction.
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUsers(users: List<UserEntity>)

    // =========================================================================
    // READ (Query operations - Reactive Flow and One-shot)
    // =========================================================================

    /**
     * Observes all users ordered by ID ascending. Emits whenever data changes.
     */
    @Query("SELECT * FROM users ORDER BY id ASC")
    fun getAllUsers(): Flow<List<UserEntity>>

    /**
     * Observes a single user by their unique primary key ID.
     */
    @Query("SELECT * FROM users WHERE id = :userId LIMIT 1")
    fun getUserById(userId: Int): Flow<UserEntity?>

    /**
     * Retrieves a single user by ID synchronously within a coroutine.
     */
    @Query("SELECT * FROM users WHERE id = :userId LIMIT 1")
    suspend fun getUserByIdOnce(userId: Int): UserEntity?

    /**
     * Retrieves a user by their email address for login verification.
     */
    @Query("SELECT * FROM users WHERE email = :email LIMIT 1")
    suspend fun getUserByEmail(email: String): UserEntity?

    /**
     * Retrieves a user by their phone number.
     */
    @Query("SELECT * FROM users WHERE phone_number = :phone LIMIT 1")
    suspend fun getUserByPhone(phone: String): UserEntity?

    /**
     * Observes users belonging to a specific role (e.g. "customer", "seller", "admin").
     */
    @Query("SELECT * FROM users WHERE role = :role ORDER BY id ASC")
    fun getUsersByRole(role: String): Flow<List<UserEntity>>

    /**
     * Observes active users only.
     */
    @Query("SELECT * FROM users WHERE status = 'active' ORDER BY id ASC")
    fun getActiveUsers(): Flow<List<UserEntity>>

    /**
     * Retrieves the seller account managing a specific store ID (Tenant isolation).
     */
    @Query("SELECT * FROM users WHERE store_id = :storeId LIMIT 1")
    suspend fun getUserByStoreId(storeId: Int): UserEntity?

    /**
     * Searches users by name or email.
     */
    @Query("SELECT * FROM users WHERE full_name LIKE '%' || :query || '%' OR email LIKE '%' || :query || '%' ORDER BY full_name ASC")
    fun searchUsers(query: String): Flow<List<UserEntity>>

    /**
     * Returns total user count in the database.
     */
    @Query("SELECT COUNT(*) FROM users")
    suspend fun getUsersCount(): Int

    // =========================================================================
    // UPDATE operations
    // =========================================================================

    /**
     * Updates an entire UserEntity row.
     */
    @Update
    suspend fun updateUser(user: UserEntity)

    /**
     * Updates only account status (e.g. active, suspended) by admin.
     */
    @Query("UPDATE users SET status = :newStatus WHERE id = :userId")
    suspend fun updateUserStatus(userId: Int, newStatus: String)

    /**
     * Updates user personal profile information.
     */
    @Query("UPDATE users SET full_name = :fullName, phone_number = :phone WHERE id = :userId")
    suspend fun updateUserProfile(userId: Int, fullName: String, phone: String)

    /**
     * Updates JWT session token upon login/refresh.
     */
    @Query("UPDATE users SET auth_token = :token WHERE id = :userId")
    suspend fun updateAuthToken(userId: Int, token: String)

    // =========================================================================
    // DELETE operations
    // =========================================================================

    /**
     * Deletes a specific UserEntity.
     */
    @Delete
    suspend fun deleteUser(user: UserEntity)

    /**
     * Deletes a user by their ID.
     */
    @Query("DELETE FROM users WHERE id = :userId")
    suspend fun deleteUserById(userId: Int)

    /**
     * Clears all users from the database.
     */
    @Query("DELETE FROM users")
    suspend fun clearAllUsers()
}
