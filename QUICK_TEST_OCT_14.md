# 🧪 Quick Testing Guide - October 14, 2025

## 🚀 Quick Start
```bash
cd attendance_app
flutter run
```

## 📝 What to Look For in Logs

### ✅ **Confirmation Working:**
```
🔍 TIMER DEBUG: Started - remaining=30, awaiting=true
⏱️ Timer tick: 29 seconds remaining (awaiting: true)
⏱️ Timer tick: 28 seconds remaining (awaiting: true)
...
⏱️ Timer tick: 1 seconds remaining (awaiting: true)
✅ Executing confirmation for 36
🎉 Attendance confirmed successfully!
```

### ✅ **Cooldown Working:**
```
✅ Cooldown check passed - proceeding with check-in at 2025-10-14 14:30:00
[After 2nd attempt within 15 min]
⏳ Cooldown active: 14 minutes remaining for 36 in 101
⏳ Last check-in was at: 2025-10-14 14:30:00
```

### ✅ **Status Stability:**
```
🔒 Ranging blocked: Awaiting confirmation (25 seconds remaining)
🔒 Ranging blocked: Awaiting confirmation (24 seconds remaining)
🔒 Status locked: ⏳ Check-in recorded for Class 101!
```

### ✅ **Device Locking:**
```
🔐 LOGIN ATTEMPT:
   Attempting: 99
   Current Device: abc123xyz
   Stored Student: 36
   Stored Device: abc123xyz
❌ BLOCKED: Device locked to student ID: 36
```

## 🎯 5-Minute Test Sequence

### **Minute 1-2: Normal Check-in**
1. Login as Student "36"
2. Approach beacon
3. ✅ See: "⏳ Check-in recorded"
4. ✅ Logs: Timer countdown 30...29...28

### **Minute 2-3: Status Stability**
1. Walk around classroom
2. Move closer/farther
3. ✅ Status stays: "Check-in recorded" (no flickering)
4. ✅ Logs: "🔒 Ranging blocked"

### **Minute 3: Confirmation**
1. Wait for timer to reach 0
2. ✅ Logs: "🎉 Attendance confirmed successfully!"
3. ✅ Backend: Check database for status='confirmed'

### **Minute 4: Duplicate Prevention**
1. Move away and return
2. Try to trigger new check-in
3. ✅ Logs: "⏳ Cooldown active: X minutes remaining"
4. ✅ No new record in database

### **Minute 5: Device Lock**
1. Logout
2. Try login as different student (e.g., "99")
3. ✅ See: "🔒 Login failed. Device locked..."
4. ✅ Logs: "❌ BLOCKED: Device locked to student ID: 36"

## 🔧 Manual Cooldown Clear (for testing)

If you need to clear cooldown to test multiple check-ins quickly:

### Option 1: Add temporary button in UI
```dart
// In home_screen.dart, add a FloatingActionButton
FloatingActionButton(
  onPressed: () {
    _beaconService.clearCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cooldown cleared!')),
    );
  },
  child: Icon(Icons.refresh),
)
```

### Option 2: Wait 15 minutes between tests

## ❌ Common Issues & Quick Fixes

### Issue: Timer logs show but UI doesn't
**Fix:** Check if `BeaconStatusWidget` is receiving updates
**Look for:** Widget rebuild in logs

### Issue: Multiple check-ins still happening
**Fix:** Verify cooldown logs show "Cooldown active"
**Check:** Database for duplicate timestamps

### Issue: Confirmation not reaching backend
**Fix:** Check backend logs for 404 errors
**Verify:** Endpoint is `/api/attendance/confirm`

### Issue: Device lock not working
**Fix:** Clear app data and re-test
**Check:** Stored device ID in SharedPreferences

## 📊 Backend Verification

### Check Provisional Status:
```javascript
// In MongoDB or backend console
db.attendances.find({ studentId: "36", status: "provisional" })
```

### Check Confirmed Status (after 30 sec):
```javascript
db.attendances.find({ studentId: "36", status: "confirmed" })
```

### Count Records (should be 1 per check-in):
```javascript
db.attendances.countDocuments({ 
  studentId: "36", 
  classId: "101",
  sessionDate: { $gte: new Date().setHours(0,0,0,0) }
})
```

## 🎯 Success Criteria

✅ **Confirmation Working:**
- Timer counts down in logs
- After 30 sec, confirmation API called
- Backend updates status to 'confirmed'
- Only 1 record per check-in

✅ **Status Stable:**
- No "Check-in failed" during countdown
- No flickering between statuses
- Logs show "Ranging blocked"

✅ **Cooldown Active:**
- 2nd attempt within 15 min blocked
- Logs show minutes remaining
- No duplicate records created

✅ **Device Locked:**
- Different student can't login
- Clear error message shown
- Logs show detailed block reason

## 📞 Report Issues With:
1. Full log output (copy from terminal)
2. Screenshots of UI
3. Database state (attendance records)
4. Device ID from logs
5. Exact steps to reproduce

---

**Ready to test? Start with the 5-minute test sequence above!** 🚀
