package com.example.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Main Room Database for the Al-Qulaisi Multi-Vendor Platform.
 */
@Database(
    entities = [UserEntity::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {

    abstract fun userDao(): UserDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context, scope: CoroutineScope = CoroutineScope(Dispatchers.IO)): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "alqulaisi_platform.db"
                )
                    .fallbackToDestructiveMigration()
                    .addCallback(AppDatabaseCallback(scope))
                    .build()
                INSTANCE = instance
                instance
            }
        }

        private class AppDatabaseCallback(
            private val scope: CoroutineScope
        ) : RoomDatabase.Callback() {
            override fun onCreate(db: SupportSQLiteDatabase) {
                super.onCreate(db)
                INSTANCE?.let { database ->
                    scope.launch(Dispatchers.IO) {
                        populateInitialUsers(database.userDao())
                    }
                }
            }

            private suspend fun populateInitialUsers(userDao: UserDao) {
                val seedUsers = listOf(
                    UserEntity(
                        id = 101,
                        email = "ahmed.customer@alqulaisi.ye",
                        fullName = "أحمد خالد العمري",
                        phoneNumber = "+967 771 234 567",
                        role = "customer",
                        status = "active",
                        storeId = null,
                        authToken = "jwt.customer.token.101"
                    ),
                    UserEntity(
                        id = 201,
                        email = "electro.seller@alqulaisi.ye",
                        fullName = "صالح مهدي (متجر القليسي للتقنية)",
                        phoneNumber = "+967 777 888 111",
                        role = "seller",
                        status = "active",
                        storeId = 501,
                        authToken = "jwt.seller.token.201"
                    ),
                    UserEntity(
                        id = 202,
                        email = "fashion.seller@alqulaisi.ye",
                        fullName = "مروان الحداد (أزياء النخبة)",
                        phoneNumber = "+967 773 444 222",
                        role = "seller",
                        status = "active",
                        storeId = 502,
                        authToken = "jwt.seller.token.202"
                    ),
                    UserEntity(
                        id = 999,
                        email = "admin@alqulaisi.ye",
                        fullName = "عبدالملك القليسي (مدير المنصة)",
                        phoneNumber = "+967 770 000 001",
                        role = "admin",
                        status = "active",
                        storeId = null,
                        authToken = "jwt.admin.token.999"
                    )
                )
                userDao.insertUsers(seedUsers)
            }
        }
    }
}
