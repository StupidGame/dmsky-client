package app.dmsky.dmsky_client

import android.content.Intent
import app.dmsky.dmsky_client.notifications.BackgroundNotificationBridge
import app.dmsky.dmsky_client.notifications.NotificationHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var notifications: BackgroundNotificationBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notifications = BackgroundNotificationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.hasExtra(NotificationHelper.ACCOUNT_EXTRA)) notifications?.notificationOpened()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        notifications?.dispose()
        notifications = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
