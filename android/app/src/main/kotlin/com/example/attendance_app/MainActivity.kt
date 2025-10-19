package com.example.attendance_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.attendance_app/beacon_service"
    
    companion object {
        var methodChannel: MethodChannel? = null
    }
    
    // Removed battery optimization auto-request - too annoying
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    BeaconForegroundService.startService(this)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    BeaconForegroundService.stopService(this)
                    result.success(true)
                }
                "updateNotification" -> {
                    val text = call.argument<String>("text") ?: "Scanning..."
                    android.util.Log.d("MainActivity", "📢 updateNotification called with text: $text")
                    
                    // Ensure service is running before updating notification
                    if (!BeaconForegroundService.isServiceRunning()) {
                        android.util.Log.w("MainActivity", "⚠️ Service not running, starting it first...")
                        BeaconForegroundService.startService(this)
                        // Wait a moment for service to initialize
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            BeaconForegroundService.updateNotification(text)
                        }, 500)
                    } else {
                        BeaconForegroundService.updateNotification(text)
                    }
                    
                    android.util.Log.d("MainActivity", "✅ updateNotification completed")
                    result.success(true)
                }
                "showSuccessNotification" -> {
                    val title = call.argument<String>("title") ?: "Attendance"
                    val message = call.argument<String>("message") ?: "Logged"
                    BeaconForegroundService.showSuccessNotification(this, title, message)
                    result.success(true)
                }
                "showSuccessNotificationEnhanced" -> {
                    val title = call.argument<String>("title") ?: "✅ Attendance Confirmed"
                    val message = call.argument<String>("message") ?: "Logged"
                    val classId = call.argument<String>("classId") ?: ""
                    BeaconForegroundService.showSuccessNotificationEnhanced(this, title, message, classId)
                    result.success(true)
                }
                "showCooldownNotificationEnhanced" -> {
                    val title = call.argument<String>("title") ?: "🕐 Cooldown Active"
                    val message = call.argument<String>("message") ?: "Next check-in available"
                    val classId = call.argument<String>("classId") ?: ""
                    val remainingMinutes = call.argument<Int>("remainingMinutes") ?: 15
                    BeaconForegroundService.showCooldownNotificationEnhanced(this, title, message, classId, remainingMinutes)
                    result.success(true)
                }
                "showCancelledNotificationEnhanced" -> {
                    val title = call.argument<String>("title") ?: "❌ Attendance Cancelled"
                    val message = call.argument<String>("message") ?: "Try again next class"
                    val classId = call.argument<String>("classId") ?: ""
                    BeaconForegroundService.showCancelledNotificationEnhanced(this, title, message, classId)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val isIgnoring = BatteryOptimizationHelper.isIgnoringBatteryOptimizations(this)
                    result.success(isIgnoring)
                }
                "requestDisableBatteryOptimization" -> {
                    BatteryOptimizationHelper.requestDisableBatteryOptimization(this)
                    result.success(true)
                }
                "openBatteryOptimizationSettings" -> {
                    BatteryOptimizationHelper.openBatteryOptimizationSettings(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

