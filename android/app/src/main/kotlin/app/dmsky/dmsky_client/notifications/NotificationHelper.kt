package app.dmsky.dmsky_client.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import app.dmsky.dmsky_client.MainActivity
import app.dmsky.dmsky_client.R
import org.json.JSONObject

class NotificationHelper(private val context: Context) {
    fun hasPermission(): Boolean = NotificationManagerCompat.from(context).areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context,
            Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)

    fun createChannel(account: NotificationAccount) {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(channelId(account.key), account.label, NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "${account.label} の新着通知"
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE
                }
            )
        }
    }

    fun show(account: NotificationAccount, items: List<JSONObject>) {
        if (!hasPermission()) return
        createChannel(account)
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "app.dmsky.dmsky_client.NOTIFICATION.${account.key}"
            putExtra(ACCOUNT_EXTRA, account.key)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val latest = items.maxWithOrNull(compareBy<JSONObject> { it.optString("createdAt") }.thenBy { it.optString("id") })!!
        val message = NotificationBatch.describe(latest)
        val notification = NotificationCompat.Builder(context, channelId(account.key))
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(account.label)
            .setContentText(if (items.size == 1) message else "${items.size}件の新着通知 · $message")
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setContentIntent(pending).setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setNumber(items.size).build()
        try {
            NotificationManagerCompat.from(context).notify(account.key, 1, notification)
        } catch (_: SecurityException) {
            // Permission can be revoked between the check and posting.
        }
    }

    companion object {
        const val ACCOUNT_EXTRA = "dmsky.notification.account"
        fun channelId(key: String) = "account_$key"
    }
}
