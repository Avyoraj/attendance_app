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
                    BeaconForegroundService.updateNotification(text)
                    android.util.Log.d("MainActivity", "✅ updateNotification completed")
                    result.success(true)
                }
                "showSuccessNotification" -> {
                    val title = call.argument<String>("title") ?: "Attendance"
                    val message = call.argument<String>("message") ?: "Logged"
                    BeaconForegroundService.showSuccessNotification(this, title, message)
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

