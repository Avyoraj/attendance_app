# 🔔 Lock Screen Notification System

## Overview
The enhanced notification system provides **lock screen visibility** and **live countdown notifications** for the attendance app. All notifications are visible on both the lock screen and notification pane, with the cooldown notification featuring live updates every minute.

---

## 📱 Notification Types

### 1. ✅ Success Notification (Lock Screen + Sound)
**Triggered**: When attendance is successfully confirmed after 30-second verification

**Features**:
- ✅ Lock screen visibility with `VISIBILITY_PUBLIC`
- 🔊 Sound & vibration pattern (0ms, 500ms, 250ms, 500ms)
- 🟢 Green color theme
- 📌 High priority (`IMPORTANCE_HIGH`)
- ⏰ Auto-dismissible

**Example**:
```
✅ Attendance Confirmed!
🎓 Class CS101
Logged at 10:35
```

**Implementation**:
```dart
await NotificationService.showSuccessNotification(
  classId: 'CS101',
  message: 'Logged at 10:35',
);
```

---

### 2. ⏳ Cooldown Notification (Live/Ongoing)
**Triggered**: Immediately after successful confirmation

**Features**:
- 🔴 **Live countdown** - Updates every minute until cooldown ends
- 🔄 Ongoing notification (`setOngoing(true)`) - Can't be dismissed
- 🔓 Lock screen visibility
- 🔇 Silent updates (no sound/vibration)
- 🔵 Blue color theme
- 📌 Default priority (`IMPORTANCE_DEFAULT`)
- 📅 Shows next class time from schedule

**Example (updates live)**:
```
⏳ Cooldown Active
🎓 Class CS101
⏱️ 12 minutes remaining
📚 Next class: 11:00 AM
```

**Implementation**:
```dart
await NotificationService.showCooldownNotification(
  classId: 'CS101',
  classStartTime: DateTime.now(), // Current class time
);
```

**Live Update Mechanism**:
- Timer triggers every 1 minute
- Recalculates remaining time
- Updates notification text
- Auto-stops when cooldown ends (15 minutes)

---

### 3. ❌ Cancelled Notification (Lock Screen + Alert)
**Triggered**: When user leaves classroom during 30-second verification

**Features**:
- ❌ Lock screen visibility
- 📳 Vibration alert
- 🔴 Red color theme
- 📌 High priority (`IMPORTANCE_HIGH`)
- 📅 Shows next class time

**Example**:
```
❌ Attendance Cancelled
🎓 Class CS101
You left the classroom during verification
📚 Next class: 11:00 AM
```

**Implementation**:
```dart
await NotificationService.showCancelledNotification(
  classId: 'CS101',
  cancelledTime: DateTime.now(),
);
```

---

## 🏗️ Architecture

### Flutter Layer (`notification_service.dart`)
```
NotificationService (Static Class)
├── showSuccessNotification()      → Platform call → Android
├── showCooldownNotification()     → Platform call → Android + Timer
│   └── _startCooldownNotificationUpdates()  → Timer.periodic (1 min)
│       └── _updateCooldownNotification()    → Update Android notification
├── showCancelledNotification()    → Platform call → Android
└── stopCooldownNotification()     → Cancel timer + clear notification
```

### Android Layer (`MainActivity.kt` + `BeaconForegroundService.kt`)
```
MainActivity.kt (Method Channel Handlers)
├── showSuccessNotificationEnhanced    → BeaconForegroundService
├── showCooldownNotificationEnhanced   → BeaconForegroundService
├── showCancelledNotificationEnhanced  → BeaconForegroundService
└── stopCooldownNotification          → BeaconForegroundService

BeaconForegroundService.kt (Notification Builder)
├── SUCCESS_CHANNEL_ID     (IMPORTANCE_HIGH)
├── COOLDOWN_CHANNEL_ID    (IMPORTANCE_DEFAULT)
├── CANCELLED_CHANNEL_ID   (IMPORTANCE_HIGH)
└── Notification Methods
    ├── showSuccessNotificationEnhanced()
    ├── showCooldownNotificationEnhanced()
    └── showCancelledNotificationEnhanced()
```

---

## 🔐 Lock Screen Visibility

All notifications are configured for **lock screen visibility**:

### Android Configuration
```kotlin
// Notification Channel
lockscreenVisibility = Notification.VISIBILITY_PUBLIC

// Notification Builder
.setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
```

### Importance Levels
- **Success/Cancelled**: `IMPORTANCE_HIGH` → Shows on lock screen with sound
- **Cooldown**: `IMPORTANCE_DEFAULT` → Shows on lock screen silently

---

## ⏱️ Live Countdown Feature

### How It Works
1. **Initial Display**: Shows cooldown notification immediately after confirmation
2. **Timer Start**: `Timer.periodic(Duration(minutes: 1))` starts
3. **Live Updates**: Every minute:
   - Calculate remaining time
   - Update notification text
   - Show updated notification
4. **Auto-Stop**: Timer stops when cooldown ends (15 minutes)

### Example Timeline
```
10:35:00  ✅ Attendance confirmed
10:35:01  ⏳ Cooldown notification shown: "15 minutes remaining"
10:36:00  ⏳ Updated: "14 minutes remaining"
10:37:00  ⏳ Updated: "13 minutes remaining"
...
10:49:00  ⏳ Updated: "1 minute remaining"
10:50:00  🎉 Timer stopped, notification cleared
```

### Code Flow
```dart
// Start cooldown notification
showCooldownNotification() {
  _cooldownEndTime = now + 15 minutes;
  _updateCooldownNotification();  // Show initial
  _startCooldownNotificationUpdates();  // Start timer
}

// Timer callback (every minute)
Timer.periodic(Duration(minutes: 1), (timer) {
  final remaining = _cooldownEndTime - now;
  if (remaining <= 0) {
    timer.cancel();  // Stop timer
    stopCooldownNotification();  // Clear notification
  } else {
    _updateCooldownNotification();  // Update notification
  }
});
```

---

## 🎯 Integration Points in `home_screen.dart`

### 1. Success + Cooldown (After Confirmation)
```dart
// Line ~690 - confirmAttendance callback
if (result['success'] == true) {
  _showSnackBar('✅ Attendance confirmed successfully!');
  
  // 🔔 Show success notification (lock screen + sound)
  await NotificationService.showSuccessNotification(
    classId: _currentClassId!,
    message: 'Logged at ${DateTime.now().hour}:${DateTime.now().minute}',
  );
  
  // 🔔 Show cooldown notification with live countdown
  await NotificationService.showCooldownNotification(
    classId: _currentClassId!,
    classStartTime: DateTime.now(),
  );
  
  _loadCooldownInfo();
}
```

### 2. Cancelled (When User Leaves Early)
```dart
// Line ~720 - Cancel attendance
setState(() {
  _beaconStatus = '❌ Attendance Cancelled!';
  _isCheckingIn = false;
});

// 🔔 Show cancelled notification with next class info
if (_currentClassId != null) {
  await NotificationService.showCancelledNotification(
    classId: _currentClassId!,
    cancelledTime: DateTime.now(),
  );
}
```

---

## 📋 Notification Channels

### Success Channel
```kotlin
NotificationChannel(
  id = "attendance_success_channel",
  name = "Attendance Success",
  importance = IMPORTANCE_HIGH,  // Lock screen + sound
  lockscreenVisibility = VISIBILITY_PUBLIC,
  vibrationPattern = [0, 500, 250, 500],
  sound = DEFAULT_NOTIFICATION_URI
)
```

### Cooldown Channel
```kotlin
NotificationChannel(
  id = "attendance_cooldown_channel",
  name = "Cooldown & Next Class",
  importance = IMPORTANCE_DEFAULT,  // Silent updates
  lockscreenVisibility = VISIBILITY_PUBLIC,
  vibration = false,
  sound = null
)
```

### Cancelled Channel
```kotlin
NotificationChannel(
  id = "attendance_cancelled_channel",
  name = "Attendance Cancelled",
  importance = IMPORTANCE_HIGH,  // Lock screen + vibration
  lockscreenVisibility = VISIBILITY_PUBLIC,
  vibrationPattern = [0, 500, 500, 500],
  lightColor = Color.RED
)
```

---

## 🧪 Testing Guide

### Test Lock Screen Visibility
1. **Run app** and mark attendance
2. **Lock device** immediately after confirmation
3. **Check lock screen**:
   - ✅ Success notification should appear with sound
   - ⏳ Cooldown notification should appear silently

### Test Live Countdown
1. **Mark attendance** successfully
2. **Wait 1 minute** with screen locked
3. **Check notification pane**:
   - Cooldown notification should update from "15 minutes" to "14 minutes"
4. **Wait 5 more minutes**:
   - Should show "9 minutes remaining"
5. **Wait 15 minutes total**:
   - Notification should disappear automatically

### Test Cancelled Notification
1. **Start check-in** (get within beacon range)
2. **Leave classroom** during 30-second verification
3. **Check lock screen**:
   - ❌ Cancelled notification should appear with vibration
   - Should show next class time

---

## 🔧 Configuration

### Modify Cooldown Duration
```dart
// In app_constants.dart
static const Duration cooldownDuration = Duration(minutes: 15);

// Notification service automatically uses this value
```

### Modify Update Frequency
```dart
// In notification_service.dart
Timer.periodic(const Duration(minutes: 1), (timer) {
  // Change to seconds for testing:
  // Duration(seconds: 10)
});
```

### Modify Vibration Pattern
```kotlin
// In BeaconForegroundService.kt
vibrationPattern = longArrayOf(0, 500, 250, 500)
// Format: [delay, vibrate, pause, vibrate, ...]
```

---

## 📊 Notification Priority Matrix

| Type | Lock Screen | Sound | Vibration | Ongoing | Priority |
|------|-------------|-------|-----------|---------|----------|
| Success | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | HIGH |
| Cooldown | ✅ Yes | ❌ No | ❌ No | ✅ Yes | DEFAULT |
| Cancelled | ✅ Yes | ❌ No | ✅ Yes | ❌ No | HIGH |

---

## 🚀 Deployment Notes

### Android Permissions (Already Configured)
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
```

### Notification Permission (Runtime)
The app automatically requests notification permission on Android 13+.

### Battery Optimization
For reliable live updates, users should disable battery optimization for the app:
- **Settings → Apps → Attendance App → Battery → Unrestricted**

---

## 🐛 Troubleshooting

### Notifications Not Appearing on Lock Screen
**Cause**: Notification channel importance too low  
**Fix**: Channels use `IMPORTANCE_HIGH` or `IMPORTANCE_DEFAULT` - both show on lock screen

### Cooldown Not Updating Live
**Cause**: Timer not running or app in background  
**Fix**: Timer runs in Dart isolate, should work even when app is minimized. Check battery optimization settings.

### Notifications Disappearing Immediately
**Cause**: User swiping away or system clearing  
**Fix**: Cooldown uses `setOngoing(true)` to prevent dismissal

### No Sound on Success
**Cause**: Notification channel created with wrong settings  
**Fix**: Clear app data to recreate channels, or change channel ID in code

---

## 📈 Future Enhancements

### Potential Improvements
1. **Custom Sound**: Use college bell sound for success notification
2. **Action Buttons**: "View Schedule" button in notification
3. **Rich Content**: Show class schedule in expanded notification
4. **Wear OS**: Sync notifications to smartwatch
5. **Configurable Timer**: Let users choose update frequency (30 sec / 1 min / 5 min)

### Code Hooks for Customization
```dart
// notification_service.dart
static const Duration _updateInterval = Duration(minutes: 1);  // Change here

// BeaconForegroundService.kt
const val SUCCESS_SOUND_URI = "..."  // Custom sound
```

---

## 📚 Related Documentation
- [Schedule Integration Guide](./SCHEDULE_INTEGRATION.md)
- [Beacon Status Widget](./BEACON_STATUS_WIDGET.md)
- [Home Screen Architecture](./HOME_SCREEN_ARCHITECTURE.md)
- [App Constants](./lib/core/constants/app_constants.dart)

---

## ✅ Summary

The notification system provides:
- ✅ **Lock screen visibility** for all notification types
- ✅ **Live countdown** with minute-by-minute updates
- ✅ **Schedule-aware messages** (shows actual class times)
- ✅ **Ongoing notification** for cooldown (can't dismiss)
- ✅ **Visual feedback** (green/blue/red colors)
- ✅ **Audio/haptic feedback** for success/cancelled
- ✅ **Automatic cleanup** when cooldown ends

**Total Lines of Code**: ~450 lines (Flutter + Android)  
**Files Modified**: 4 (notification_service.dart, MainActivity.kt, BeaconForegroundService.kt, home_screen.dart)  
**Status**: ✅ Complete & Ready for Testing
