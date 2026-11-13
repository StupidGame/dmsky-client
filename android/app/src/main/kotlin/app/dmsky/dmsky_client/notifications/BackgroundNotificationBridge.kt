package app.dmsky.dmsky_client.notifications

import android.content.Intent
import android.os.Build
import android.provider.Settings
import app.dmsky.dmsky_client.MainActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class BackgroundNotificationBridge(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val store = NotificationStore(activity)
    private val scheduler = NotificationScheduler(activity)
    private val helper = NotificationHelper(activity)
    private val channel = MethodChannel(messenger, CHANNEL, StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "status" -> {
                        val (origin, username) = identity(call)
                        val key = NotificationStore.accountKey(origin, username)
                        synchronized(NotificationStore.lock(key)) {
                            val config = store.read(key)
                            result.success(mapOf(
                                "enabled" to (config?.enabled ?: false),
                                "intervalMinutes" to (config?.intervalMinutes ?: 15),
                                "lastCheck" to (config?.lastCheck ?: 0),
                                "lastError" to config?.lastError,
                                "permissionGranted" to helper.hasPermission(),
                            ))
                        }
                    }
                    "configure" -> {
                        val (origin, username) = identity(call)
                        val key = NotificationStore.accountKey(origin, username)
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val interval = call.argument<Number>("intervalMinutes")?.toLong() ?: 15
                        require(interval in listOf(15L, 30L, 60L)) { "確認間隔が不正です" }
                        val token = if (enabled) call.argument<String>("token").orEmpty() else ""
                        require(!enabled || token.isNotBlank()) { "ログインしたアカウントが必要です" }
                        synchronized(NotificationStore.lock(key)) {
                            val old = try { store.read(key) } catch (_: Exception) { null }
                            val base = if (old?.enabled == true && enabled) old else NotificationAccount(origin, username, token)
                            val config = base.copy(token = token, enabled = enabled, intervalMinutes = interval, lastError = null)
                            store.write(config)
                            if (enabled) {
                                helper.createChannel(config)
                                scheduler.schedule(config)
                            } else scheduler.cancel(key)
                        }
                        result.success(null)
                    }
                    "remove" -> {
                        val (origin, username) = identity(call)
                        remove(NotificationStore.accountKey(origin, username))
                        result.success(null)
                    }
                    "sync" -> {
                        val accounts = call.argument<List<Map<String, Any?>>>("accounts").orEmpty().associate { args ->
                            val origin = NotificationStore.validateOrigin(args["origin"] as String)
                            val username = args["username"] as String
                            NotificationStore.accountKey(origin, username) to args
                        }
                        for (key in store.keys()) {
                            val args = accounts[key]
                            if (args == null) { remove(key); continue }
                            synchronized(NotificationStore.lock(key)) {
                                val config = try { store.read(key) } catch (_: Exception) { null }
                                if (config == null) { scheduler.cancel(key); store.remove(key) }
                                else if (config.enabled) {
                                    val token = args["token"] as? String
                                    if (token.isNullOrBlank()) { scheduler.cancel(key); store.remove(key) }
                                    else {
                                        val updated = config.copy(token = token)
                                        store.write(updated)
                                        scheduler.schedule(updated)
                                    }
                                }
                            }
                        }
                        result.success(null)
                    }
                    "checkNow" -> {
                        val (origin, username) = identity(call)
                        val key = NotificationStore.accountKey(origin, username)
                        synchronized(NotificationStore.lock(key)) {
                            require(store.read(key)?.enabled == true) { "先に通知を有効にしてください" }
                            scheduler.checkNow(key)
                        }
                        result.success(null)
                    }
                    "openSettings" -> {
                        val (origin, username) = identity(call)
                        val key = NotificationStore.accountKey(origin, username)
                        val hasChannel = synchronized(NotificationStore.lock(key)) { store.read(key) != null }
                        val intent = if (Build.VERSION.SDK_INT >= 26 && hasChannel) Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                            putExtra(Settings.EXTRA_CHANNEL_ID, NotificationHelper.channelId(NotificationStore.accountKey(origin, username)))
                        } else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:${activity.packageName}"))
                        activity.runOnUiThread { activity.startActivity(intent) }
                        result.success(null)
                    }
                    "takeLaunch" -> {
                        val source = activity.intent
                        val key = source.getStringExtra(NotificationHelper.ACCOUNT_EXTRA)
                        source.removeExtra(NotificationHelper.ACCOUNT_EXTRA)
                        val config = key?.let { synchronized(NotificationStore.lock(it)) { store.read(it) } }
                        result.success(config?.let { mapOf("origin" to it.origin, "username" to it.username) })
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("INVALID_ARGUMENT", error.message, null)
            } catch (_: Exception) {
                result.error("NOTIFICATION_ERROR", "通知設定を処理できませんでした。設定をやり直してください。", null)
            }
        }
    }

    private fun identity(call: MethodCall): Pair<String, String> {
        val origin = NotificationStore.validateOrigin(call.argument<String>("origin").orEmpty())
        val username = call.argument<String>("username").orEmpty()
        require(username.isNotBlank() && username.length <= 256) { "アカウント名が不正です" }
        return origin to username
    }

    private fun remove(key: String) = synchronized(NotificationStore.lock(key)) {
        scheduler.cancel(key)
        store.remove(key)
    }

    fun notificationOpened() { channel.invokeMethod("notificationOpened", null) }
    fun dispose() { channel.setMethodCallHandler(null) }

    companion object { const val CHANNEL = "app.dmsky.client/background_notifications" }
}
