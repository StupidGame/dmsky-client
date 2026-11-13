package app.dmsky.dmsky_client.notifications

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class NotificationScheduler(private val context: Context) {
    private val manager get() = WorkManager.getInstance(context)
    private val network = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

    fun schedule(account: NotificationAccount) {
        val request = PeriodicWorkRequestBuilder<BackgroundNotificationWorker>(account.intervalMinutes, TimeUnit.MINUTES)
            .setConstraints(network)
            .setInputData(Data.Builder().putString("accountKey", account.key).build()).build()
        manager.enqueueUniquePeriodicWork("notifications_${account.key}", ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    fun checkNow(key: String) {
        val request = OneTimeWorkRequestBuilder<BackgroundNotificationWorker>()
            .setConstraints(network).setInputData(Data.Builder().putString("accountKey", key).build()).build()
        manager.enqueueUniqueWork("notification_check_$key", ExistingWorkPolicy.KEEP, request)
    }

    fun cancel(key: String) {
        manager.cancelUniqueWork("notifications_$key")
        manager.cancelUniqueWork("notification_check_$key")
        NotificationManagerCompat.from(context).cancel(key, 1)
    }
}

/** Runs natively, so receiving notifications does not require a Flutter engine. */
class BackgroundNotificationWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result {
        val key = inputData.getString("accountKey") ?: return Result.failure()
        return synchronized(NotificationStore.lock(key)) {
            val store = NotificationStore(applicationContext)
            val account = try { store.read(key) } catch (_: Exception) { return@synchronized Result.failure() }
                ?: return@synchronized Result.success()
            if (!account.enabled) return@synchronized Result.success()
            val helper = NotificationHelper(applicationContext)
            if (!helper.hasPermission()) {
                store.write(account.copy(lastError = "端末の通知許可が無効です"))
                return@synchronized Result.success()
            }
            try {
                val body = JSONObject().put("i", account.token).put("markAsRead", false)
                    .put("limit", if (account.initialized) 100 else 1)
                account.sinceId?.let { body.put("sinceId", it) }
                val response = fetch(account.origin, body.toString())
                val batch = NotificationBatch.parse(response, account.initialized, account.seenIds.toSet())
                if (isStopped) return@synchronized Result.success()
                if (batch.unread.isNotEmpty()) helper.show(account, batch.unread)
                val seen = (account.seenIds + batch.ids).distinct().takeLast(200)
                store.write(account.copy(
                    initialized = true, sinceId = batch.newestId ?: account.sinceId,
                    seenIds = seen, lastCheck = System.currentTimeMillis(), lastError = null,
                ))
                Result.success()
            } catch (error: HttpStatusException) {
                store.write(account.copy(lastError = if (error.status == 401 || error.status == 403)
                    "通知を読む権限または認証情報を確認してください" else "サーバーの応答エラー (HTTP ${error.status})"))
                if (error.status >= 500) Result.retry() else Result.success()
            } catch (_: IOException) {
                store.write(account.copy(lastError = "サーバーに接続できませんでした"))
                Result.retry()
            } catch (_: Exception) {
                store.write(account.copy(lastError = "通知の取得に失敗しました"))
                Result.success()
            }
        }
    }

    private fun fetch(origin: String, body: String): String {
        val connection = URL("$origin/api/i/notifications").openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            if (connection.responseCode !in 200..299) throw HttpStatusException(connection.responseCode)
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                // Bound a malformed server response without keeping unbounded data in memory.
                val data = reader.readTextBounded(2 * 1024 * 1024)
                data
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun java.io.Reader.readTextBounded(limit: Int): String {
        val result = StringBuilder()
        val buffer = CharArray(8192)
        while (true) {
            val length = read(buffer)
            if (length < 0) return result.toString()
            if (result.length + length > limit) throw IOException("Notification response too large")
            result.append(buffer, 0, length)
        }
    }

    private class HttpStatusException(val status: Int) : IOException()
}
