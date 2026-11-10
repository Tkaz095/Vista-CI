package com.vista.vista_mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelId = "vista_ci_runs"
    private val payloadExtra = "vista_ci_notification_payload"
    private var notificationChannel: MethodChannel? = null
    private var dartReady = false
    private var pendingPayload: String? = null
    private val manager: NotificationManager
        get() = getSystemService(NotificationManager::class.java)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vista_ci/notifications")
        notificationChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val payload = pendingPayload ?: intent?.getStringExtra(payloadExtra)
                    pendingPayload = null
                    intent?.removeExtra(payloadExtra)
                    dartReady = true
                    result.success(payload)
                }
                "show" -> {
                    try {
                        showNotification(call.arguments as Map<*, *>)
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("notification_failed", "Cannot display notification", null)
                    }
                }
                "clear" -> {
                    manager.cancelAll()
                    pendingPayload = null
                    intent?.removeExtra(payloadExtra)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = intent.getStringExtra(payloadExtra) ?: return
        intent.removeExtra(payloadExtra)
        if (dartReady) notificationChannel?.invokeMethod("notificationTap", payload)
        else pendingPayload = payload
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Kết quả CI", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Thông báo workflow bắt đầu và kết quả chạy CI"
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            manager.createNotificationChannel(channel)
        }
    }

    @Suppress("DEPRECATION")
    private fun showNotification(args: Map<*, *>) {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val tag = args["tag"] as String
        val payload = args["payload"] as String
        val click = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = Uri.parse("vista-ci://notification/${Uri.encode(tag)}")
            putExtra(payloadExtra, payload)
        }
        val pending = PendingIntent.getActivity(this, 0, click, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, channelId)
            else Notification.Builder(this)
        builder.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(args["title"] as String)
            .setContentText(args["body"] as String)
            .setStyle(Notification.BigTextStyle().bigText(args["body"] as String))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setCategory(Notification.CATEGORY_STATUS)
            .setPriority(Notification.PRIORITY_HIGH)
            .setWhen((args["timestamp"] as Number).toLong())
        manager.notify(tag, 0, builder.build())
    }
}
