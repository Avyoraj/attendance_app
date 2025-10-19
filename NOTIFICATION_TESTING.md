# 🧪 Notification Testing Checklist

## Quick Test Guide for Lock Screen Notifications

### 📋 Pre-Test Setup
- [ ] **Build app**: `flutter build apk --release`
- [ ] **Install**: Transfer APK to Android device
- [ ] **Permissions**: Grant notification permission when prompted
- [ ] **Battery**: Disable battery optimization for app
  - Settings → Apps → Attendance App → Battery → Unrestricted

---

## ✅ Test 1: Success Notification (Lock Screen + Sound)

### Steps
1. Open app and log in
2. Walk near beacon (enter classroom)
3. Wait for "Checking In..." message
4. **Stay in range** for 30 seconds
5. **Immediately lock your phone** when you see "✅ Attendance CONFIRMED!"

### Expected Results
- [ ] **Lock screen shows**:
  ```
  ✅ Attendance Confirmed!
  🎓 Class [ClassID]
  Logged at [Time]
  ```
- [ ] **Sound plays** (notification tone)
- [ ] **Vibration**: Pattern (vibrate 500ms, pause 250ms, vibrate 500ms)
- [ ] **Color**: Green accent
- [ ] **Dismissible**: Yes (swipe away to dismiss)

### Pass Criteria
✅ Notification visible on locked screen  
✅ Sound + vibration triggered  
✅ Shows correct class ID and time  

---

## ⏳ Test 2: Cooldown Notification (Live Updates)

### Steps
1. Continue from Test 1 (after attendance confirmed)
2. **Keep phone locked** for testing
3. Pull down notification panel (with phone locked)
4. Wait 1 minute
5. Check notification again

### Expected Results (Initial - 0 minutes)
- [ ] **Notification shows**:
  ```
  ⏳ Cooldown Active
  🎓 Class [ClassID]
  ⏱️ 15 minutes remaining
  📚 Next class: [Time]
  ```
- [ ] **Can't dismiss**: Swipe does nothing (ongoing notification)
- [ ] **No sound/vibration**: Silent update
- [ ] **Color**: Blue accent

### Expected Results (After 1 Minute)
- [ ] **Notification updates to**:
  ```
  ⏳ Cooldown Active
  🎓 Class [ClassID]
  ⏱️ 14 minutes remaining
  📚 Next class: [Time]
  ```

### Expected Results (After 5 Minutes)
- [ ] **Shows**: "10 minutes remaining"

### Expected Results (After 15 Minutes)
- [ ] **Notification disappears** automatically

### Pass Criteria
✅ Visible on lock screen  
✅ Can't be dismissed (ongoing)  
✅ Updates every minute  
✅ Auto-disappears after 15 minutes  

---

## ❌ Test 3: Cancelled Notification (Lock Screen + Vibration)

### Steps
1. Open app and start fresh check-in
2. Walk near beacon (enter classroom)
3. Wait for "Checking In..." message
4. **Walk away from beacon** during 30-second verification
5. **Lock phone** when you see "❌ Attendance Cancelled!"

### Expected Results
- [ ] **Lock screen shows**:
  ```
  ❌ Attendance Cancelled
  🎓 Class [ClassID]
  You left the classroom during verification
  📚 Next class: [Time]
  ```
- [ ] **Vibration**: Yes
- [ ] **Sound**: No (silent)
- [ ] **Color**: Red accent
- [ ] **Dismissible**: Yes

### Pass Criteria
✅ Notification visible on locked screen  
✅ Vibration triggered  
✅ Shows next class time  
✅ Can be dismissed  

---

## 🔄 Test 4: Notification Pane (While Unlocked)

### Steps
1. Keep phone **unlocked**
2. Mark attendance successfully
3. Pull down notification panel from top

### Expected Results
- [ ] **Both notifications visible**:
  1. ✅ Success notification (green)
  2. ⏳ Cooldown notification (blue, ongoing)
- [ ] Success is dismissible
- [ ] Cooldown is NOT dismissible (try swiping)

### Pass Criteria
✅ Both notifications in notification pane  
✅ Cooldown can't be dismissed  

---

## 📊 Test Matrix

| Scenario | Lock Screen | Sound | Vibration | Live Update | Auto-Dismiss |
|----------|-------------|-------|-----------|-------------|--------------|
| ✅ Success | ✅ | ✅ | ✅ | ❌ | ✅ (Manual) |
| ⏳ Cooldown | ✅ | ❌ | ❌ | ✅ | ✅ (Auto 15m) |
| ❌ Cancelled | ✅ | ❌ | ✅ | ❌ | ✅ (Manual) |

---

## 🐛 Common Issues

### Issue: No notifications appearing
**Check**:
- [ ] Notification permission granted?
- [ ] App installed correctly?
- [ ] Check Settings → Apps → Attendance → Notifications → All enabled

### Issue: Cooldown not updating
**Check**:
- [ ] Battery optimization disabled for app?
- [ ] Wait full 60 seconds (updates every minute)
- [ ] Check app is still running in background

### Issue: Can dismiss cooldown notification
**Check**:
- [ ] Android version (some OEMs override ongoing behavior)
- [ ] Check notification channel settings

### Issue: No lock screen visibility
**Check**:
- [ ] Lock screen notification settings enabled?
- [ ] Settings → Lock Screen → Show all notification content

---

## 🎬 Quick Demo Flow (5 minutes)

1. **Open app** (0:00)
2. **Check in** - walk to beacon (0:30)
3. **Lock phone** immediately after confirmation (1:00)
4. **Check lock screen** - see success notification (1:05)
5. **Pull down** - see cooldown notification "15 min remaining" (1:10)
6. **Wait 1 minute** with phone locked (2:10)
7. **Pull down again** - see "14 min remaining" (2:15)
8. **Unlock** - pull down notification pane (2:20)
9. **Try to dismiss cooldown** - should not work (2:25)
10. **Start new check-in** (3:00)
11. **Walk away** during verification (3:30)
12. **Lock phone** - see cancelled notification (3:35)

---

## 📸 Screenshot Checklist

Capture these for documentation:
- [ ] Lock screen with success notification
- [ ] Lock screen with cooldown notification (showing countdown)
- [ ] Notification pane with both notifications
- [ ] Cooldown updating from 15 to 14 minutes
- [ ] Cancelled notification on lock screen
- [ ] Attempt to dismiss ongoing cooldown (show it stays)

---

## 🚀 Advanced Testing

### Test During Break (1:30 PM - 2:00 PM)
- [ ] Cooldown shows "Next class: 2:00 PM"
- [ ] Cancelled shows "Next class: 2:00 PM"

### Test After College Hours (After 5:30 PM)
- [ ] Cooldown shows "Next class: 10:30 AM" (tomorrow)
- [ ] Cancelled shows "Next class: 10:30 AM" (tomorrow)

### Test Rapid Check-ins
1. Mark attendance successfully
2. Wait 1 minute (cooldown shows 14 min)
3. Force another check-in (close to beacon again)
4. Check if old cooldown notification is replaced

---

## ✅ Test Sign-Off

### Tester Information
- **Date**: _______________
- **Device**: _______________
- **Android Version**: _______________
- **App Version**: _______________

### Test Results
- [ ] ✅ Success notification works
- [ ] ⏳ Cooldown live updates work
- [ ] ❌ Cancelled notification works
- [ ] 🔓 All visible on lock screen
- [ ] 📱 All visible in notification pane
- [ ] 🔄 Cooldown can't be dismissed
- [ ] 🎯 Auto-cleanup after 15 minutes works

### Notes
```
[Add any observations or issues here]
```

---

## 🎓 Tips for Best Results

1. **Use a real device** (not emulator) - lock screen behavior differs
2. **Test with phone locked** from the start
3. **Disable battery saver** during testing
4. **Keep screen on** for live update testing (to see changes)
5. **Use logcat** to see timer updates:
   ```bash
   adb logcat | grep -i "cooldown\|notification"
   ```

---

## 🔍 Debugging Commands

### Check Notification Channels
```bash
adb shell dumpsys notification
```

### Check Active Notifications
```bash
adb shell dumpsys notification | grep -A 20 "attendance"
```

### Force Stop Timer (Testing)
```bash
adb shell am force-stop com.yourapp.attendance
# Then restart app
```

---

**Status**: Ready for Testing ✅  
**Priority**: High 🔥  
**Estimated Test Time**: 20 minutes  
