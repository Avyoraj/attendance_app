# ✅ Testing Checklist - Enhanced Beacon System

## 🚀 Before You Start Testing

- [ ] **Hot restart the Flutter app** (press 'R' in terminal)
- [ ] **Enable verbose logging** (logs will show smoothing + grace period)
- [ ] **Beacon is placed** 3m+ from doorway, chest height
- [ ] **Phone bluetooth enabled** and permissions granted
- [ ] **Backend server running** (for provisional/confirm API calls)

---

## 📋 Test 1: Normal Attendance (Should CONFIRM ✅)

**Scenario:** Student sits normally, phone in pocket, natural movement

### Steps:
1. [ ] Stand 1-2m from beacon (front/middle of classroom)
2. [ ] Open app and check in
3. [ ] Verify "Provisional Attendance" message shows
4. [ ] Sit down, put phone in pocket
5. [ ] **Rotate phone 2-3 times** (simulate natural movement)
6. [ ] **Lean forward to write** (body blocks signal briefly)
7. [ ] Wait full 60 seconds without leaving room
8. [ ] Check final status

### Expected Results:
```
✅ Check-in succeeds (RSSI > -75)
✅ Status: "Provisional Attendance"
✅ Logs show: "📊 RSSI Smoothing: Raw=-88, Smoothed=-76"
✅ Logs show: "⏳ Grace period active: 20s remaining" (if signal drops)
✅ Logs show: "✅ Beacon signal restored" (when signal returns)
✅ At t=60s: "🎉 Attendance confirmed successfully!"
✅ Final status: "Attendance Confirmed ✅"
```

### If This Fails:
- ❌ Attendance cancelled → Increase `exitGracePeriod` to 45s
- ❌ Can't check in → Beacon too far, move closer
- ❌ Logs show errors → Check backend server

---

## 📋 Test 2: Student Leaves Early (Should CANCEL ❌)

**Scenario:** Student checks in but leaves before 60s timer

### Steps:
1. [ ] Stand 1-2m from beacon
2. [ ] Check in successfully (provisional)
3. [ ] At t=20s, **walk out of classroom** (5m+ away)
4. [ ] Stay outside for 40+ seconds
5. [ ] Check status at t=60s

### Expected Results:
```
✅ Check-in succeeds initially
✅ At t=20s: Walk out → RSSI drops to null
✅ At t=25s: Logs show "⚠️ Beacon weak for 15s - Starting 30s grace period"
✅ At t=35s: Logs show "⏳ Grace period active: 20s remaining"
✅ At t=50s: Logs show "❌ Beacon lost for 35s (grace period: 30s)"
✅ At t=50s: Status changes to "Attendance Cancelled ❌"
✅ At t=60s: Backend confirmation fails (provisional deleted)
```

### If This Fails:
- ❌ Still confirmed despite leaving → Decrease `exitGracePeriod` to 20s
- ❌ Cancelled too quickly → Check beacon placement (shouldn't reach hallway)

---

## 📋 Test 3: Doorway Gaming (Should FAIL Check-In ❌)

**Scenario:** Student tries to check in from doorway/hallway

### Steps:
1. [ ] Stand at classroom doorway (5m+ from beacon)
2. [ ] Try to check in
3. [ ] Verify check-in is rejected

### Expected Results:
```
❌ Check-in fails
❌ Logs show: "⚠️ Smoothed RSSI (-78) below threshold (-75)"
❌ Logs show: "Signal not stable yet" or "Student appears to be outside"
❌ Status remains: "Scanning for beacon..."
❌ No provisional attendance created
```

### If This Fails:
- ❌ Check-in succeeds from doorway → Increase `checkInRssiThreshold` to -70
- ❌ Need to move beacon farther from door

---

## 📋 Test 4: Movement Inside Classroom (Should CONFIRM ✅)

**Scenario:** Student checks in at front, walks to back of class

### Steps:
1. [ ] Check in at front of classroom (1m from beacon)
2. [ ] Verify provisional status
3. [ ] Walk to **back of classroom** (5-6m from beacon)
4. [ ] Stay at back for remaining time (40+ seconds)
5. [ ] Check status at t=60s

### Expected Results:
```
✅ Check-in succeeds at front (RSSI ~ -65)
✅ Walk to back → RSSI drops to -80
✅ Smoothed RSSI: -76 (smoothing helps)
✅ Confirmation threshold: -82 (lenient - allows back of class)
✅ At t=60s: "🎉 Attendance confirmed successfully!"
✅ Final status: "Attendance Confirmed ✅"
```

### If This Fails:
- ❌ Cancelled when at back → Decrease `confirmationRssiThreshold` to -85
- ❌ Beacon range too small → Need stronger beacon or better placement

---

## 📋 Test 5: Extended Grace Period Test (Should CONFIRM ✅)

**Scenario:** Signal drops for 25s (within grace) then returns

### Steps:
1. [ ] Check in successfully
2. [ ] At t=20s, **cover beacon with hand** or **put phone deep in backpack**
3. [ ] Hold for 25 seconds (within 30s grace period)
4. [ ] At t=45s, **uncover beacon** or **take phone out**
5. [ ] Check status at t=60s

### Expected Results:
```
✅ Check-in succeeds
✅ At t=20s: Signal drops → Logs show "⚠️ Starting 30s grace period"
✅ At t=30s: Logs show "⏳ Grace period active: 10s remaining"
✅ At t=45s: Signal returns → Logs show "✅ Beacon signal restored (was weak for 25s)"
✅ At t=60s: "🎉 Attendance confirmed successfully!"
✅ Grace period prevented false cancellation ✅
```

### If This Fails:
- ❌ Cancelled despite signal return → Check smoothing is working
- ❌ Grace period not triggered → Increase `beaconLostTimeout`

---

## 📋 Test 6: Multiple Students (Stress Test)

**Scenario:** 5+ students checking in simultaneously

### Steps:
1. [ ] Have 5+ students with app installed
2. [ ] All stand near beacon (1-3m)
3. [ ] All check in within 10 seconds of each other
4. [ ] All remain in classroom for 60s
5. [ ] Verify all confirmations succeed

### Expected Results:
```
✅ All students check in successfully
✅ No interference between devices
✅ Smoothing works independently per device
✅ All confirmations succeed at t=60s
✅ No false cancellations
```

### If This Fails:
- ❌ Some cancelled → Increase grace period + smoothing window
- ❌ Backend issues → Check server capacity

---

## 🔍 What to Look for in Logs

### Good Signs (System Working) ✅
```
📊 RSSI Smoothing: Raw=-88, Smoothed=-76 (avg of 5 samples)
⏳ Grace period active: 15s remaining
✅ Beacon signal restored (was weak for 18s)
🎉 Attendance confirmed successfully!
```

### Warning Signs (Needs Tuning) ⚠️
```
❌ Beacon lost for 35s - Student has left (but student was present!)
⚠️ Smoothed RSSI (-83) below threshold (-82) (too strict!)
❌ Attendance confirmation failed (false cancellation!)
```

### Error Signs (System Broken) 🚨
```
ERROR: No RSSI data available (beacon not detected at all)
ERROR: Backend confirmation failed (server issue)
EXCEPTION: Null safety error (code bug)
```

---

## 📊 Success Metrics

After 20+ test runs, calculate:

| Metric | Target | Calculation |
|--------|--------|-------------|
| **False Cancellation Rate** | <5% | (Cancelled when shouldn't) / Total tests |
| **Doorway Block Rate** | 100% | (Rejected from doorway) / Doorway attempts |
| **Movement Tolerance** | 100% | (Confirmed despite movement) / Movement tests |
| **Exit Detection Rate** | >95% | (Cancelled when left) / Exit tests |

---

## 🎯 Pass/Fail Criteria

### ✅ PASS (Deploy to Production)
- [ ] Test 1 passes (normal attendance) with 0 false cancellations
- [ ] Test 2 passes (early exit) with 100% detection
- [ ] Test 3 passes (doorway block) with 100% rejection
- [ ] Test 4 passes (classroom movement) with 0 false cancellations
- [ ] Test 5 passes (grace period) with signal recovery working
- [ ] Logs show smoothing and grace period working correctly
- [ ] False cancellation rate < 5% across all tests

### ❌ FAIL (Needs Tuning)
- [ ] Multiple false cancellations in Test 1 (>20% failure rate)
- [ ] Doorway check-ins succeed in Test 3
- [ ] Back of classroom cancels in Test 4
- [ ] Grace period not preventing cancellations in Test 5
- [ ] Logs show no smoothing or grace period activity

---

## 🔧 Quick Fixes Reference

### If Tests Fail, Try These:

**Too many false cancellations:**
```dart
// app_constants.dart
static const Duration exitGracePeriod = Duration(seconds: 45); // Was 30
static const int confirmationRssiThreshold = -85; // Was -82
static const int rssiSmoothingWindow = 7; // Was 5
```

**Doorway gaming works:**
```dart
static const int checkInRssiThreshold = -70; // Was -75 (stricter)
```

**Back of classroom cancelled:**
```dart
static const int confirmationRssiThreshold = -88; // Was -82 (more lenient)
```

---

## 📝 Testing Log Template

Copy this for each test run:

```
Test Date: __________
Tester: __________
Beacon Location: __________

Test 1 (Normal): ☐ PASS ☐ FAIL - Notes: _____________
Test 2 (Exit):   ☐ PASS ☐ FAIL - Notes: _____________
Test 3 (Door):   ☐ PASS ☐ FAIL - Notes: _____________
Test 4 (Move):   ☐ PASS ☐ FAIL - Notes: _____________
Test 5 (Grace):  ☐ PASS ☐ FAIL - Notes: _____________
Test 6 (Multi):  ☐ PASS ☐ FAIL - Notes: _____________

False Cancellation Rate: _____%
Overall Status: ☐ PASS ☐ NEEDS TUNING ☐ FAIL

Parameters Used:
- exitGracePeriod: _____s
- checkInRssiThreshold: _____dBm
- confirmationRssiThreshold: _____dBm
- rssiSmoothingWindow: _____ samples

Recommended Changes: _______________________________
```

---

## 🚀 After Testing Passes

1. [ ] **Document final parameters** that worked
2. [ ] **Change timer to 10 minutes:**
   ```dart
   static const Duration secondCheckDelay = Duration(minutes: 10);
   ```
3. [ ] **Deploy to production** with 1 classroom pilot
4. [ ] **Monitor for 1 week** with real students
5. [ ] **Fine-tune if needed** based on real usage
6. [ ] **Roll out to all classrooms**

---

**Good luck with testing! 🎯**

**Remember:** If anything fails, check `TUNING_GUIDE.md` for parameter adjustments!
