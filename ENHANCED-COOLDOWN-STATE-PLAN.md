# Enhanced Cooldown & State Management - Complete Fix 🎯

**Date**: October 19, 2025  
**Status**: IN PROGRESS

---

## 🎯 Issues Identified by User

### Issue 1: Cooldown Time Display ⏰
**Current:**
```
Cooldown Active
Next check-in available in: 12 minutes
```

**Problem:** Not aligned with college schedule

**User's College Schedule:**
- 10:30 AM - 1:30 PM: Classes (1-hour each)
- 1:30 PM - 2:00 PM: Break (30 min)
- 2:00 PM - 5:30 PM: Classes (1-hour each)

**Needed:**
```
Cooldown Active
Class ends at: 11:30 AM
Next class starts at: 11:30 AM
Can mark attendance after: 11:30 AM
```

---

### Issue 2: Backend Delete Strategy 🗑️

**Current Behavior:**
```
Timer expires → Mark as cancelled → DELETE immediately
                                      ↓
                            Frontend loses state info
                                      ↓
                         Card shows "Scanning" (confusing!)
```

**Problem:**
- User sees "cancelled" for 1 second
- Then backend deletes record
- Frontend syncs → no record found
- Card switches to "Scanning for beacon..."
- **CONFUSION**: "Did it cancel? Can I check in again?"

**Solution:**
```
Timer expires → Mark as cancelled → Keep for CLASS DURATION (1 hour)
                                     ↓
                          Frontend keeps showing "cancelled" state
                                     ↓
                          "Try again in next class at 11:30 AM"
                                     ↓
                After 1 hour (class ends) → DELETE from database
```

**Benefits:**
- ✅ Consistent state for full class period
- ✅ Clear message: "Cancelled, try again next class"
- ✅ No confusion about whether they can retry immediately
- ✅ Database stays clean after class ends

---

### Issue 3: Notification Visibility 🔔

**Problem 1: Success notification not visible**
```
Current: Shows inside app only
Needed:  Shows on lock screen, notification shade
```

**Problem 2: No cooldown notification**
```
Missing: "Next class at 11:30 AM - You can mark attendance then"
```

---

## ✅ Solutions Implemented

### Solution 1: Backend Two-Stage Cleanup ✅

**Updated `cleanupExpiredProvisional()` function:**

```javascript
async function cleanupExpiredProvisional() {
  const now = new Date();
  const confirmationWindowMs = 3 * 60 * 1000; // 3 minutes
  const classDurationMs = 60 * 60 * 1000; // 1 hour
  
  // STAGE 1: Mark expired provisionals as "cancelled" (keep for 1 hour)
  const expiredProvisionals = await Attendance.find({
    status: 'provisional',
    checkInTime: { $lt: new Date(now - confirmationWindowMs) }
  });
  
  for (const record of expiredProvisionals) {
    record.status = 'cancelled';
    record.cancelledAt = now;
    record.cancellationReason = 'Expired...';
    await record.save(); // ✅ KEEP (don't delete yet)
  }
  
  // STAGE 2: Delete cancelled records after class ends (1 hour)
  const oldCancelledRecords = await Attendance.find({
    status: 'cancelled',
    checkInTime: { $lt: new Date(now - classDurationMs) }
  });
  
  for (const record of oldCancelledRecords) {
    await Attendance.deleteOne({ _id: record._id }); // 🗑️ DELETE
  }
}
```

**Timeline:**
```
10:00:00 - User checks in → Provisional
10:01:00 - User logs out → Timer stops
10:03:00 - 3 min window expires
10:05:00 - Cleanup runs:
           Stage 1: Mark as "cancelled" ✅
           Stage 2: Check if 1 hour passed → NO (keep)
           
10:30:00 - Next class starts (user can try again)
11:00:00 - Original class ended (1 hour since 10:00)
11:05:00 - Cleanup runs:
           Stage 1: No new expired provisionals
           Stage 2: Find cancelled from 10:00 → DELETE 🗑️
```

---

### Solution 2: Class Schedule Integration (TODO)

**Need to implement:**

#### A. Constants for Class Schedule
```dart
// lib/core/constants/app_constants.dart

class AppConstants {
  // Existing...
  
  // 🎯 NEW: College Schedule
  static const classDuration = Duration(hours: 1);
  static const breakTime = Duration(minutes: 30);
  
  // Class timings
  static const List<TimeRange> classTimings = [
    TimeRange(start: '10:30', end: '11:30'),
    TimeRange(start: '11:30', end: '12:30'),
    TimeRange(start: '12:30', end: '13:30'),
    // Break: 13:30 - 14:00
    TimeRange(start: '14:00', end: '15:00'),
    TimeRange(start: '15:00', end: '16:00'),
    TimeRange(start: '16:00', end: '17:00'),
    TimeRange(start: '17:00', end: '17:30'),
  ];
}

class TimeRange {
  final String start; // "10:30"
  final String end;   // "11:30"
  
  const TimeRange({required this.start, required this.end});
}
```

#### B. Helper to Calculate Next Class
```dart
// lib/core/utils/schedule_utils.dart

class ScheduleUtils {
  /// Get current class period
  static TimeRange? getCurrentClass() {
    final now = DateTime.now();
    final currentTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    
    for (var classTime in AppConstants.classTimings) {
      if (_isTimeBetween(currentTime, classTime.start, classTime.end)) {
        return classTime;
      }
    }
    return null; // No class right now (break or outside college hours)
  }
  
  /// Get next class start time
  static DateTime? getNextClassStartTime() {
    final now = DateTime.now();
    
    for (var classTime in AppConstants.classTimings) {
      final classStart = _parseTime(classTime.start);
      if (classStart.isAfter(now)) {
        return classStart;
      }
    }
    return null; // No more classes today
  }
  
  /// Calculate cooldown end time (current class ends)
  static DateTime getCooldownEndTime(DateTime checkInTime) {
    // Find which class this check-in belongs to
    final checkInTimeStr = '${checkInTime.hour}:${checkInTime.minute.toString().padLeft(2, '0')}';
    
    for (var classTime in AppConstants.classTimings) {
      if (_isTimeBetween(checkInTimeStr, classTime.start, classTime.end)) {
        // Return end time of this class
        return _parseTime(classTime.end);
      }
    }
    
    // Fallback: 1 hour from check-in
    return checkInTime.add(AppConstants.classDuration);
  }
  
  /// Format time remaining until next class
  static String formatTimeUntilNextClass() {
    final nextClass = getNextClassStartTime();
    if (nextClass == null) return 'No more classes today';
    
    final now = DateTime.now();
    final duration = nextClass.difference(now);
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
```

#### C. Enhanced Cooldown Display
```dart
// In beacon_status_widget.dart

if (cooldownInfo != null && cooldownInfo!['inCooldown'] == true) ...[
  Container(
    child: Column(
      children: [
        // Current class ends at
        Text('Current class ends at:'),
        Text(
          ScheduleUtils.formatTime(cooldownInfo!['classEndTime']),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
        ),
        
        Divider(),
        
        // Next class starts at
        if (cooldownInfo!['nextClassTime'] != null) ...[
          Text('Next class starts at:'),
          Text(
            ScheduleUtils.formatTime(cooldownInfo!['nextClassTime']),
            style: TextStyle(fontSize: 20, color: Colors.blue)
          ),
          
          Text('Can mark attendance in:'),
          Text(
            ScheduleUtils.formatTimeUntil(cooldownInfo!['nextClassTime']),
            style: TextStyle(fontSize: 18)
          ),
        ],
      ],
    ),
  ),
],
```

---

### Solution 3: Enhanced Cancelled State Display (TODO)

**Current:**
```
❌ Attendance Cancelled!
(Backend deletes immediately → "Scanning...")
```

**Needed:**
```
❌ Attendance Cancelled!
Class ends at: 11:30 AM
Try again in next class at: 11:30 AM
Time remaining: 25 minutes
```

**Implementation:**
```dart
// In beacon_status_widget.dart

if (status.contains('Cancelled') || status.contains('cancelled')) ...[
  const SizedBox(height: 20),
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade200),
    ),
    child: Column(
      children: [
        // Cancelled badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 8),
            Text('Attendance Cancelled', style: TextStyle(...)),
          ],
        ),
        
        const SizedBox(height: 12),
        Divider(),
        const SizedBox(height: 12),
        
        // When can retry
        Text('This class ends at:'),
        Text(
          _formatClassEndTime(cooldownInfo),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
        ),
        
        const SizedBox(height: 8),
        
        Text('Try again in next class at:'),
        Text(
          _formatNextClassTime(cooldownInfo),
          style: TextStyle(fontSize: 18, color: Colors.blue.shade700)
        ),
        
        const SizedBox(height: 8),
        
        // Countdown
        Text(
          'Can mark attendance in: ${_formatTimeRemaining(cooldownInfo)}',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700)
        ),
      ],
    ),
  ),
],
```

---

### Solution 4: Lock Screen Notifications (TODO)

#### A. Update Android Notification Channel
```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt

private fun createNotificationChannel() {
    val channel = NotificationChannel(
        CHANNEL_ID,
        "Attendance Tracking",
        NotificationManager.IMPORTANCE_HIGH // ✅ Changed from DEFAULT
    ).apply {
        description = "Beacon detection and attendance tracking"
        enableLights(true)
        lightColor = Color.BLUE
        enableVibration(true)
        setShowBadge(true)
        lockscreenVisibility = Notification.VISIBILITY_PUBLIC // ✅ NEW: Show on lock screen
    }
}
```

#### B. Attendance Confirmed Notification
```dart
// When attendance confirmed

await platform.invokeMethod('showSuccessNotification', {
  'title': '✅ Attendance Confirmed!',
  'message': 'Class ${classId} attendance recorded successfully',
  'priority': 'high', // ✅ High priority for lock screen
  'sound': true,
  'vibrate': true,
});
```

#### C. Cooldown Notification
```dart
// After confirmation, schedule cooldown notification

await platform.invokeMethod('showCooldownNotification', {
  'title': '⏰ Next Class Available',
  'message': 'You can mark attendance for next class at ${nextClassTime}',
  'scheduledTime': nextClassStartTime.toIso8601String(),
  'ongoing': true, // ✅ Persistent until dismissed
});
```

---

## 📊 Complete User Flow

### Flow 1: Successful Attendance
```
10:00 AM - User enters Class 101
           Status: "Scanning..."
           
10:00:10 - Beacon detected
           Status: "⏳ Check-in recorded"
           Timer: "02:50 remaining"
           Progress bar: Moving
           
10:03:00 - Timer expires, user in range
           Status: "✅ Attendance CONFIRMED!"
           Badge: Green "Attendance Confirmed"
           Cooldown card appears:
           ┌─────────────────────────────┐
           │ 🕒 Cooldown Active          │
           │ Class: 101                  │
           │                             │
           │ Current class ends at:      │
           │     11:00 AM                │
           │                             │
           │ Next class starts at:       │
           │     11:00 AM                │
           │                             │
           │ Can mark attendance in:     │
           │     57 minutes              │
           └─────────────────────────────┘
           
           Notification: "✅ Attendance Confirmed! Class 101"
           Lock screen: Shows notification ✅
           
10:05 AM - User logs out
           (Cooldown state persisted)
           
10:15 AM - User logs back in
           Cooldown card still shows:
           "Can mark attendance in: 45 minutes"
           
11:00 AM - Class ends
           Cooldown expires
           Status: "Scanning for classroom beacon..."
           Ready for next class!
```

### Flow 2: Cancelled Attendance (User Leaves Early)
```
10:00 AM - User enters Class 102
           Check-in starts
           Timer: "03:00"
           
10:01:00 - User walks away
           RSSI drops
           
10:03:00 - Timer expires, user out of range
           Status: "❌ Attendance Cancelled!"
           Badge: Red "Attendance Cancelled"
           
           ⚠️ OLD BEHAVIOR (BAD):
           10:03:05 - Backend deletes record
           10:03:06 - Frontend syncs
           10:03:07 - Status: "Scanning..." ← CONFUSING!
           
           ✅ NEW BEHAVIOR (GOOD):
           Card shows:
           ┌─────────────────────────────┐
           │ ❌ Attendance Cancelled     │
           │                             │
           │ This class ends at:         │
           │     11:00 AM                │
           │                             │
           │ Try again in next class at: │
           │     11:00 AM                │
           │                             │
           │ Can mark attendance in:     │
           │     57 minutes              │
           └─────────────────────────────┘
           
           (State stays "cancelled" until 11:00 AM)
           
11:00 AM - Class ends (1 hour since 10:00)
11:05 AM - Backend cleanup deletes record
           Frontend syncs
           Status: "Scanning..." ✅ NOW it makes sense!
```

### Flow 3: User Logs Out During Provisional
```
10:00 AM - Check in → Provisional
10:01:00 - Logout (never return)
10:05:00 - Backend: Mark as "cancelled"
           (Record kept for 1 hour)
           
11:05 AM - Backend: Delete old cancelled
           (Clean database)
```

---

## 🎯 Summary of Changes

### ✅ Already Implemented:

1. **Backend Two-Stage Cleanup**
   - Stage 1: Mark provisional → cancelled (keep for 1 hour)
   - Stage 2: Delete cancelled after class ends

### 📝 TODO (Need to Implement):

1. **Class Schedule Integration**
   - [ ] Add class timings to AppConstants
   - [ ] Create ScheduleUtils helper
   - [ ] Calculate next class start time
   - [ ] Calculate current class end time

2. **Enhanced Cooldown Card**
   - [ ] Show "Class ends at: 11:00 AM"
   - [ ] Show "Next class starts at: 11:00 AM"
   - [ ] Show countdown to next class

3. **Enhanced Cancelled Card**
   - [ ] Keep cancelled state visible for full hour
   - [ ] Show "Try again in next class at: X"
   - [ ] Show countdown until retry

4. **Lock Screen Notifications**
   - [ ] Update notification importance to HIGH
   - [ ] Enable lock screen visibility
   - [ ] Add success notification
   - [ ] Add cooldown notification

5. **Notification Content**
   - [ ] "✅ Attendance Confirmed! Class 101"
   - [ ] "⏰ Next class at 11:00 AM - You can mark attendance then"

---

**Next Steps:**
1. Implement class schedule constants
2. Update cooldown card UI
3. Update cancelled card UI
4. Fix Android notifications
5. Test complete flow

