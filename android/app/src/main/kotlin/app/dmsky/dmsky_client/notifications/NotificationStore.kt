package app.dmsky.dmsky_client.notifications

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.URI
import java.security.KeyStore
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class NotificationAccount(
    val origin: String,
    val username: String,
    val token: String,
    val enabled: Boolean = false,
    val intervalMinutes: Long = 15,
    val initialized: Boolean = false,
    val sinceId: String? = null,
    val seenIds: List<String> = emptyList(),
    val lastCheck: Long = 0,
    val lastError: String? = null,
) {
    val key: String get() = NotificationStore.accountKey(origin, username)
    val label: String get() = "@$username@${URI(origin).authority}"

    fun toJson(): JSONObject = JSONObject().apply {
        put("origin", origin); put("username", username); put("token", token)
        put("enabled", enabled); put("intervalMinutes", intervalMinutes)
        put("initialized", initialized); put("sinceId", sinceId)
        put("seenIds", JSONArray(seenIds)); put("lastCheck", lastCheck)
        put("lastError", lastError)
    }

    companion object {
        fun fromJson(json: JSONObject): NotificationAccount {
            val seen = json.optJSONArray("seenIds") ?: JSONArray()
            return NotificationAccount(
                json.getString("origin"), json.getString("username"), json.getString("token"),
                json.optBoolean("enabled"), json.optLong("intervalMinutes", 15),
                json.optBoolean("initialized"), json.optString("sinceId").takeIf { it.isNotBlank() },
                (0 until seen.length()).map { seen.getString(it) },
                json.optLong("lastCheck"), json.optString("lastError").takeIf { it.isNotBlank() },
            )
        }
    }
}

/** Credentials stay encrypted in internal storage excluded from Android backup. */
class NotificationStore(context: Context) {
    private val directory = File(context.noBackupFilesDir, "background-notifications").apply { mkdirs() }

    fun keys(): List<String> = directory.listFiles()?.filter { it.name.matches(Regex("[0-9a-f]{64}")) }
        ?.map { it.name } ?: emptyList()

    fun read(key: String): NotificationAccount? {
        val file = file(key)
        if (!file.baseFile.exists()) return null
        val bytes = file.readFully()
        require(bytes.size > 13 && bytes[0] == 1.toByte())
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, bytes.copyOfRange(1, 13)))
        cipher.updateAAD(key.toByteArray(Charsets.UTF_8))
        val json = cipher.doFinal(bytes.copyOfRange(13, bytes.size)).toString(Charsets.UTF_8)
        return NotificationAccount.fromJson(JSONObject(json))
    }

    fun write(account: NotificationAccount) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        cipher.updateAAD(account.key.toByteArray(Charsets.UTF_8))
        require(cipher.iv.size == 12)
        val bytes = byteArrayOf(1) + cipher.iv + cipher.doFinal(account.toJson().toString().toByteArray(Charsets.UTF_8))
        val file = file(account.key)
        val output = file.startWrite()
        try {
            output.write(bytes)
            file.finishWrite(output)
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
        }
    }

    fun remove(key: String) = file(key).delete()

    private fun file(key: String): AtomicFile {
        require(key.matches(Regex("[0-9a-f]{64}")))
        return AtomicFile(File(directory, key))
    }

    private fun secretKey(): SecretKey = synchronized(KEY_ALIAS) {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey) ?: KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore",
        ).apply {
            init(KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }

    companion object {
        private const val KEY_ALIAS = "dmsky.background-notifications.v1"
        private val locks = ConcurrentHashMap<String, Any>()
        fun lock(key: String): Any = locks.getOrPut(key) { Any() }

        fun accountKey(origin: String, username: String): String = MessageDigest.getInstance("SHA-256")
            .digest("$origin\n$username".toByteArray(Charsets.UTF_8))
            .joinToString("") { (it.toInt() and 0xff).toString(16).padStart(2, '0') }

        fun validateOrigin(value: String): String {
            val uri = URI(value)
            require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null &&
                (uri.path.isNullOrEmpty() || uri.path == "/") && uri.query == null && uri.fragment == null) {
                "Background notifications require an HTTPS server origin."
            }
            return URI("https", null, uri.host.lowercase(), uri.port, null, null, null).toASCIIString()
        }
    }
}
