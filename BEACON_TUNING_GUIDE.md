# ⚙️ BEACON MONITORING TUNING GUIDE

## Date: October 14, 2025

---

## 🔧 **Current Settings (After Your Feedback)**

You said:
> "this one was too agresstive? i did not even moved from the beacon it automaticcly canced the attandance"

**I made it MORE TOLERANT!** ✅

---

## 📊 **Current Configuration**

### In `app_constants.dart`:

```dart
// How often to check if beacon is still present
static const Duration beaconMonitoringInterval = Duration(seconds: 10);

// How long without beacon before cancelling
static const Duration beaconLostTimeout = Duration(seconds: 15);
```

### What This Means:
- ✅ **Checks every 10 seconds** (was 5 seconds - too frequent)
- ✅ **Waits 15 seconds** before cancelling (was 5 seconds - too strict)
- ✅ **More tolerant** of brief signal drops

---

## 🎯 **Behavior Explained**

### OLD (Too Aggressive):
```
Check-in → Beacon monitoring starts
Every 5 seconds, check:
  - If beacon not seen for 5+ seconds → CANCEL!
  
Problem: Beacons have natural signal fluctuations!
Even standing still, signal can drop briefly.
```

### NEW (More Tolerant):
```
Check-in → Beacon monitoring starts
Every 10 seconds, check:
  - If beacon not seen for 15+ seconds → CANCEL!
  
Better: Allows for natural signal fluctuations.
Only cancels if you're truly gone for 15 seconds.
```

---

## 🧪 **Testing Scenarios**

### Test 1: Stand Still (Should NOT Cancel)
```
1. Check in near beacon
2. Stand completely still for 60 seconds
3. Expected: ✅ Attendance confirmed
4. Should NOT see: "Attendance Cancelled"
```

**If it still cancels randomly:**
- Increase `beaconLostTimeout` to `Duration(seconds: 20)` or `Duration(seconds: 30)`

---

### Test 2: Walk Away (Should Cancel)
```
1. Check in near beacon
2. Walk far away (outside classroom)
3. Wait 20 seconds
4. Expected: ❌ "Attendance Cancelled!"
```

**If it takes too long to cancel:**
- Decrease `beaconLostTimeout` to `Duration(seconds: 10)`
- Decrease `beaconMonitoringInterval` to `Duration(seconds: 8)`

---

### Test 3: Walk Nearby (Should NOT Cancel)
```
1. Check in near beacon
2. Walk around classroom (stay near beacon)
3. Expected: ✅ Attendance confirmed
4. Should NOT cancel if RSSI stays > -75 dBm
```

**If it cancels when walking nearby:**
- Increase `rssiThreshold` to `-80` (more lenient)
- Or increase `beaconLostTimeout` to `Duration(seconds: 20)`

---

## ⚙️ **How to Tune Settings**

### File: `lib/core/constants/app_constants.dart`

### Option 1: Make it MORE LENIENT (fewer false cancellations)
```dart
// Check less frequently
static const Duration beaconMonitoringInterval = Duration(seconds: 15);

// Wait longer before cancelling
static const Duration beaconLostTimeout = Duration(seconds: 20);

// More tolerant RSSI threshold
static const int rssiThreshold = -80; // Was -75
```

**Effect:**
- ✅ Won't cancel if you stand still
- ✅ More tolerant of signal drops
- ❌ Might not catch students leaving quickly

---

### Option 2: Make it MORE STRICT (catch cheaters)
```dart
// Check more frequently
static const Duration beaconMonitoringInterval = Duration(seconds: 7);

// Cancel faster
static const Duration beaconLostTimeout = Duration(seconds: 10);

// Stricter RSSI threshold
static const int rssiThreshold = -70; // Was -75
```

**Effect:**
- ✅ Catches students leaving faster
- ✅ Less chance to cheat
- ❌ Might cancel randomly if standing still

---

### Option 3: BALANCED (Recommended - Current Settings)
```dart
// Balanced checking
static const Duration beaconMonitoringInterval = Duration(seconds: 10);

// Reasonable timeout
static const Duration beaconLostTimeout = Duration(seconds: 15);

// Standard RSSI threshold
static const int rssiThreshold = -75;
```

**Effect:**
- ✅ Good balance between security and usability
- ✅ Tolerates signal fluctuations
- ✅ Catches real departures

---

## 📱 **How to Test Changes**

1. **Edit `app_constants.dart`:**
   ```dart
   static const Duration beaconLostTimeout = Duration(seconds: 20); // Your new value
   ```

2. **Hot Restart (IMPORTANT!):**
   - Press `R` (capital R) in terminal
   - Constants need full restart, not hot reload

3. **Test by standing still:**
   - Check in
   - Don't move for 60 seconds
   - Should confirm, not cancel

4. **Test by walking away:**
   - Check in
   - Walk far away
   - Should cancel within 15-25 seconds

---

## 🔍 **Understanding the Numbers**

### Beacon Lost Timeout:
```
Duration(seconds: 10)  → Very strict, might false-cancel
Duration(seconds: 15)  → Balanced (CURRENT)
Duration(seconds: 20)  → More lenient
Duration(seconds: 30)  → Very lenient, might miss departures
```

### Monitoring Interval:
```
Duration(seconds: 5)   → Check very often, battery drain
Duration(seconds: 10)  → Balanced (CURRENT)
Duration(seconds: 15)  → Check less often, saves battery
Duration(seconds: 20)  → Slow to detect departures
```

### RSSI Threshold:
```
-70 dBm  → Very strict, must be very close
-75 dBm  → Balanced (CURRENT)
-80 dBm  → More lenient, can be further away
-85 dBm  → Very lenient, might accept students outside
```

---

## 🎯 **Recommended Settings by Environment**

### Small Classroom (5-10 students):
```dart
static const Duration beaconMonitoringInterval = Duration(seconds: 10);
static const Duration beaconLostTimeout = Duration(seconds: 15);
static const int rssiThreshold = -75;
```

### Large Classroom (20+ students):
```dart
static const Duration beaconMonitoringInterval = Duration(seconds: 12);
static const Duration beaconLostTimeout = Duration(seconds: 20);
static const int rssiThreshold = -80; // Students might be further away
```

### Lab/Moving Around:
```dart
static const Duration beaconMonitoringInterval = Duration(seconds: 15);
static const Duration beaconLostTimeout = Duration(seconds: 25);
static const int rssiThreshold = -80; // Students moving around
```

---

## ⚠️ **Common Issues & Fixes**

### Issue 1: "Cancelled even though I didn't move"
**Fix:** Increase `beaconLostTimeout` to `Duration(seconds: 20)` or `25`

### Issue 2: "Takes too long to cancel when I leave"
**Fix:** Decrease `beaconLostTimeout` to `Duration(seconds: 10)`

### Issue 3: "Cancels when walking around classroom"
**Fix:** Increase `rssiThreshold` to `-80` or increase `beaconLostTimeout`

### Issue 4: "Never cancels, even when far away"
**Fix:** Decrease `beaconLostTimeout` to `Duration(seconds: 10)` or stricter `rssiThreshold` to `-70`

---

## 🚀 **Next Steps**

1. **Test current settings** (15s timeout, 10s interval)
2. **If still too aggressive:**
   - Change `beaconLostTimeout` to `Duration(seconds: 20)`
   - Hot restart and test again

3. **If not catching departures:**
   - Keep current settings
   - They should work well!

4. **Report back:**
   - Tell me if it's working better now
   - I can fine-tune more if needed

---

**Current Status:** ✅ Made MORE TOLERANT  
**Beacon Lost Timeout:** 15 seconds (was 5 seconds)  
**Monitoring Interval:** 10 seconds (was 5 seconds)  

**Try it now and let me know!** 🎯

