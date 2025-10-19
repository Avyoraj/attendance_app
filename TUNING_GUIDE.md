# 🎛️ Quick Tuning Guide

## Current Configuration (app_constants.dart)

```dart
// Entry vs. Staying Thresholds
static const int checkInRssiThreshold = -75;        // Must be THIS close to check in
static const int confirmationRssiThreshold = -82;   // Can be THIS far to stay confirmed

// RSSI Smoothing (Noise Reduction)
static const int rssiSmoothingWindow = 5;           // Average last N samples
static const Duration rssiSampleMaxAge = Duration(seconds: 10);

// Exit Hysteresis (False Cancellation Prevention)
static const Duration exitGracePeriod = Duration(seconds: 30);  // Wait before cancelling
static const Duration beaconLostTimeout = Duration(seconds: 15); // When to start grace period

// Confirmation Timing
static const Duration secondCheckDelay = Duration(seconds: 60); // TESTING: 60s (use 10min in production)
```

---

## 🚨 Problem Solving Chart

### Problem: Too Many False Cancellations (Students sitting still getting cancelled)

**Symptoms:**
- Logs show: `❌ Beacon lost for 30s+ - Student left`
- Student claims they never moved
- Happens frequently (>5% of students)

**Solutions (try in order):**

1. **Increase grace period** (most common fix)
   ```dart
   static const Duration exitGracePeriod = Duration(seconds: 45); // Was 30
   ```

2. **Make confirmation threshold more lenient**
   ```dart
   static const int confirmationRssiThreshold = -85; // Was -82 (lower = more lenient)
   ```

3. **Increase smoothing window**
   ```dart
   static const int rssiSmoothingWindow = 7; // Was 5 (more samples = more stable)
   ```

4. **Increase beacon lost timeout**
   ```dart
   static const Duration beaconLostTimeout = Duration(seconds: 20); // Was 15
   ```

---

### Problem: Doorway Gaming (Students checking in from outside)

**Symptoms:**
- Students at doorway getting attendance
- Check-ins from too far away
- False positives at classroom entrance

**Solutions:**

1. **Make entry threshold stricter** (require closer proximity)
   ```dart
   static const int checkInRssiThreshold = -70; // Was -75 (higher = closer required)
   ```

2. **Keep confirmation threshold as-is** (don't make stricter - will cause false cancellations)
   ```dart
   static const int confirmationRssiThreshold = -82; // Keep this lenient
   ```

3. **Physical solution:** Move beacon away from doorway (3m+ inside classroom)

---

### Problem: System Too Sensitive (Cancels when student moves slightly)

**Symptoms:**
- Logs show: `⚠️ Beacon weak for 5s - Starting grace period`
- Happens when student leans forward/backward
- Grace period triggering too often

**Solutions:**

1. **Increase smoothing window** (average more samples)
   ```dart
   static const int rssiSmoothingWindow = 8; // Was 5
   ```

2. **Increase beacon lost timeout** (tolerate longer signal drops)
   ```dart
   static const Duration beaconLostTimeout = Duration(seconds: 20); // Was 15
   ```

---

### Problem: System Too Lenient (Students leaving early still confirmed)

**Symptoms:**
- Students walk out at 5min mark but still get confirmed at 10min
- Exit not detected quickly enough

**Solutions:**

1. **Decrease grace period** (catch exits faster)
   ```dart
   static const Duration exitGracePeriod = Duration(seconds: 20); // Was 30
   ```

2. **Make confirmation threshold stricter** (require closer proximity)
   ```dart
   static const int confirmationRssiThreshold = -78; // Was -82 (higher = stricter)
   ```
   ⚠️ **Warning:** This may increase false cancellations!

---

## 📏 RSSI Distance Reference

Approximate RSSI values at different distances (varies by beacon model):

```
Distance  | Typical RSSI | Status
----------|--------------|--------
0.5m      | -50 to -60   | Very strong (right next to beacon)
1-2m      | -60 to -70   | Strong (front row of classroom)
3-5m      | -70 to -80   | Medium (middle/back of classroom)
5-8m      | -80 to -90   | Weak (doorway/outside)
8m+       | -90 to -100  | Very weak (hallway)
```

**Current Thresholds:**
- ✅ Check-in requires: -75 dBm (approx 2-3m)
- ✅ Confirmation allows: -82 dBm (approx 5-6m)

---

## 🧪 Testing Parameters for Different Classroom Sizes

### Small Classroom (5m x 5m, 20 students)
```dart
static const int checkInRssiThreshold = -70;        // Stricter (closer)
static const int confirmationRssiThreshold = -80;   // Can be medium distance
static const Duration exitGracePeriod = Duration(seconds: 25); // Shorter
```

### Medium Classroom (8m x 8m, 40 students)
```dart
// 👈 USE CURRENT VALUES (default)
static const int checkInRssiThreshold = -75;
static const int confirmationRssiThreshold = -82;
static const Duration exitGracePeriod = Duration(seconds: 30);
```

### Large Classroom/Auditorium (15m x 15m, 100+ students)
```dart
static const int checkInRssiThreshold = -78;        // More lenient (farther)
static const int confirmationRssiThreshold = -85;   // Allow back rows
static const Duration exitGracePeriod = Duration(seconds: 40); // Longer grace
static const int rssiSmoothingWindow = 7;           // More smoothing
```

---

## 🎓 Tuning Process

### Step 1: Deploy with Default Settings
Use current values for first week, monitor closely.

### Step 2: Collect Data
Watch for these log patterns:
```
✅ Good: "✅ Beacon signal restored (was weak for 8s)"
❌ Bad:  "❌ Beacon lost for 35s - Student left" (but student was present)
❌ Bad:  Students at doorway getting attendance
```

### Step 3: Adjust Based on Majority Pattern

**If >10% false cancellations:** System too strict
→ Increase grace period
→ Make confirmation threshold more lenient

**If doorway check-ins occur:** System too lenient
→ Make entry threshold stricter
→ Move beacon physically

**If both problems:** Need better beacon placement first!

### Step 4: Fine-Tune Smoothing

**If signal very noisy (logs show RSSI jumping ±10 dBm):**
→ Increase smoothing window to 7-8 samples

**If signal stable (RSSI only varies ±3 dBm):**
→ Keep smoothing window at 5 samples

---

## 🚀 Production Checklist

Before deploying to production:

- [ ] Change timer to 10 minutes:
  ```dart
  static const Duration secondCheckDelay = Duration(minutes: 10);
  ```

- [ ] Test in real classroom with 5+ students for full class period

- [ ] Verify beacon placement (3m+ from doorway, mounted at chest height)

- [ ] Check false cancellation rate (<5% acceptable)

- [ ] Verify no doorway gaming possible

- [ ] Test grace period with phone rotation/pocket movement

- [ ] Document final parameter values for this classroom

---

## 📊 Monitoring Metrics

Track these metrics weekly:

```
Metric                          | Target  | Action if Outside Target
--------------------------------|---------|-------------------------
False Cancellation Rate         | <5%     | Increase grace period
Doorway False Positive Rate     | <2%     | Stricter entry threshold
Grace Period Trigger Rate       | 10-30%  | Normal (shows it's working)
Successful Confirmation Rate    | >90%    | Check beacon placement
Average Confirmation RSSI       | -70±10  | Verify beacon range
```

---

## 🔧 Emergency Overrides

### If System Completely Broken (>30% false cancellations):

**Quick Fix - Make VERY lenient:**
```dart
static const int confirmationRssiThreshold = -90;   // Almost always passes
static const Duration exitGracePeriod = Duration(seconds: 60); // Full minute grace
```
⚠️ This sacrifices accuracy for stability - tune properly ASAP!

---

### If Doorway Gaming Rampant:

**Quick Fix - Make VERY strict:**
```dart
static const int checkInRssiThreshold = -65;   // Must be very close
```
⚠️ May exclude back row students - relocate beacon ASAP!

---

## 📞 Decision Tree

```
Problem?
  │
  ├─ False Cancellations? → Increase exitGracePeriod (+10s at a time)
  │                       → Make confirmationRssiThreshold more lenient (-3 dBm at a time)
  │
  ├─ Doorway Gaming? → Make checkInRssiThreshold stricter (+3 dBm at a time)
  │                  → Move beacon away from door
  │
  ├─ Noisy Signal? → Increase rssiSmoothingWindow (+2 samples at a time)
  │
  └─ System Working? → Document current settings as "baseline"
                     → Deploy to more classrooms
```

---

## 💡 Pro Tips

1. **Always change ONE parameter at a time** (scientific method!)
2. **Test for full class period** (10-60 min) before declaring success
3. **Document what you changed** and why (future you will thank you)
4. **Different classrooms may need different settings** (that's okay!)
5. **Physical beacon placement > parameter tuning** (fix hardware first)

---

**Remember:** These are guidelines, not rules. Your classroom environment is unique!

**Last Updated:** October 16, 2025  
**Status:** ✅ Ready for Field Testing
