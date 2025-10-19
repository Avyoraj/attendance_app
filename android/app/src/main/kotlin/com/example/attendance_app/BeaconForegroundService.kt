package com.example.attendance_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class BeaconForegroundService : Service() {
    
    private var wakeLock: PowerManager.WakeLock? = null
    private lateinit var notificationManager: NotificationManager
    
    companion object {
        const val CHANNEL_ID = "beacon_service_channel"
        const val SUCCESS_CHANNEL_ID = "attendance_success_channel"
        const val NOTIFICATION_ID = 1001
        const val SUCCESS_NOTIFICATION_ID = 2000
        const val METHOD_CHANNEL = "com.example.attendance_app/beacon_service"
        
        @Volatile // Ensure visibility across threads
        private var serviceInstance: BeaconForegroundService? = null
        
        fun updateNotification(text: String) {
            android.util.Log.d("BeaconService", "📢 updateNotification called (static), serviceInstance = $serviceInstance")
            val instance = serviceInstance
            if (instance == null) {
                android.util.Log.w("BeaconService", "⚠️ Service not yet started - notification update skipped")
                // Don't log as error - this is expected during initialization
            } else {
                instance.updateNotificationText(text)
            }
        }
        
        fun showSuccessNotification(context: Context, title: String, message: String) {
            android.util.Log.d("BeaconService", "🔔 Showing success notification: $title - $message")
            
            // This can be called from anywhere to show success notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Create success channel if needed
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    SUCCESS_CHANNEL_ID,
                    "Attendance Success",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Attendance logged notifications"
                    setShowBadge(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    enableLights(true)
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // Create success notification
            val notificationIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                notificationIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(context, SUCCESS_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText(message))
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)  // Dismissible
                .setShowWhen(true)
                .setWhen(System.currentTimeMillis())
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setDefaults(Notification.DEFAULT_ALL)  // Sound + vibration
                .build()
                
            notificationManager.notify(SUCCESS_NOTIFICATION_ID, notification)
            android.util.Log.d("BeaconService", "✅ Success notification shown: $title")
        }
        
        fun startService(context: Context) {
            android.util.Log.d("BeaconService", "🚀 startService() called")
            val intent = Intent(context, BeaconForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            android.util.Log.d("BeaconService", "✅ Service start requested")
        }
        
        fun stopService(context: Context) {
            android.util.Log.d("BeaconService", "🛑 stopService() called")
            val intent = Intent(context, BeaconForegroundService::class.java)
            context.stopService(intent)
            android.util.Log.d("BeaconService", "✅ Service stop requested")
        }
        
        fun isServiceRunning(): Boolean {
            return serviceInstance != null
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("BeaconService", "📱 Service onCreate() called")
        
        // Set instance FIRST before any other initialization
        serviceInstance = this
        android.util.Log.d("BeaconService", "✅ serviceInstance set to: $serviceInstance")
        
        // Initialize notification manager
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Create notification channel (required for Android O+)
        createNotificationChannel()
        
        // Start foreground immediately (required within 5 seconds of service start)
        try {
            startForeground(NOTIFICATION_ID, createNotification())
            android.util.Log.d("BeaconService", "✅ Service started in foreground")
        } catch (e: Exception) {
            android.util.Log.e("BeaconService", "❌ Failed to start foreground service", e)
        }
        
        // Acquire wake lock to keep CPU running
        acquireWakeLock()
        
        android.util.Log.d("BeaconService", "✅ Service fully initialized and running")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Keep service running even if app is killed
        // START_STICKY will restart the service if it gets killed
        return START_STICKY
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        // Restart service if task is removed from recents
        val restartServiceIntent = Intent(applicationContext, BeaconForegroundService::class.java).also {
            it.setPackage(packageName)
        }
        val restartServicePendingIntent = PendingIntent.getService(
            this,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.ELAPSED_REALTIME,
            android.os.SystemClock.elapsedRealtime() + 1000,
            restartServicePendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        android.util.Log.d("BeaconService", "🛑 Service onDestroy() called")
        
        // Release wake lock first
        releaseWakeLock()
        
        // Clear instance last
        serviceInstance = null
        android.util.Log.d("BeaconService", "✅ Service destroyed, instance cleared")
        
        super.onDestroy()
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "AttendanceApp::BeaconScanningWakeLock"
            ).apply {
                setReferenceCounted(false)  // Don't use reference counting
                acquire() // Infinite wake lock - will hold until released
            }
            android.util.Log.d("BeaconService", "✅ Wake lock acquired")
        } catch (e: Exception) {
            android.util.Log.e("BeaconService", "❌ Failed to acquire wake lock", e)
            e.printStackTrace()
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Beacon Scanning Service",
                NotificationManager.IMPORTANCE_LOW  // 🔇 LOW = Silent updates
            ).apply {
                description = "Continuously scans for classroom beacons"
                setShowBadge(false)  // No badge for scanning updates
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableLights(false)  // No LED light
                enableVibration(false)  // No vibration
                setSound(null, null)  // No sound
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🎓 Attendance Tracker")
            .setContentText("🔍 Monitoring for classroom beacons...")
            .setStyle(NotificationCompat.BigTextStyle().bigText("🔍 Monitoring for classroom beacons..."))
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
    
    fun updateNotificationText(text: String) {
        try {
            android.util.Log.d("BeaconService", "📲 Updating notification: $text")
            
            val notificationIntent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("🎓 Attendance Tracker")
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setShowWhen(true)
                .setWhen(System.currentTimeMillis())
                .setPriority(NotificationCompat.PRIORITY_LOW)  // 🔇 Low priority = Silent
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .setSilent(true)  // 🔇 Explicitly silent
                .setOnlyAlertOnce(true)  // 🔇 Only alert on first show
                .build()
                
            notificationManager.notify(NOTIFICATION_ID, notification)
            android.util.Log.d("BeaconService", "✅ Notification updated successfully")
        } catch (e: Exception) {
            android.util.Log.e("BeaconService", "❌ Failed to update notification", e)
        }
    }
}
