# 🎨 Visual Flow Diagrams

## 1. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    BEACON ATTENDANCE SYSTEM                      │
│                      (Enhanced Version)                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. BEACON DETECTION (beacon_service.dart)                      │
│     Raw RSSI: -72, -68, -80, -70, -73                          │
│                      │                                           │
│                      ▼                                           │
│  2. RSSI SMOOTHING (Moving Average)                             │
│     Smoothed RSSI: -72.6 ✅ (noise reduced)                    │
│                      │                                           │
│                      ▼                                           │
│  3. THRESHOLD CHECK (Dual System)                               │
│     Entry:   -75 dBm (strict)                                   │
│     Staying: -82 dBm (lenient)                                  │
│                      │                                           │
│                      ▼                                           │
│  4. EXIT HYSTERESIS (Grace Period)                              │
│     Weak signal? Wait 30s before cancelling                     │
│                      │                                           │
│                      ▼                                           │
│  5. CONFIRMATION (attendance_confirmation_service.dart)         │
│     Wait 60s → Verify proximity → Confirm                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. RSSI Smoothing Flow

```
┌──────────────┐
│ Raw RSSI #1  │ -72 dBm
│   (t=0s)     │
└──────┬───────┘
       │
       ▼
┌──────────────┐  Buffer: [-72]
│ Raw RSSI #2  │ -68 dBm  → Average: -70
│   (t=1s)     │
└──────┬───────┘
       │
       ▼
┌──────────────┐  Buffer: [-72, -68, -80]
│ Raw RSSI #3  │ -80 dBm  → Average: -73
│   (t=2s)     │
└──────┬───────┘
       │
       ▼
┌──────────────┐  Buffer: [-72, -68, -80, -70, -73]
│ Raw RSSI #5  │ -73 dBm  → Average: -72.6 ✅ STABLE
│   (t=4s)     │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ Smoothed RSSI: -72.6 │ Used for decisions
└──────────────────────┘
```

**Key:** 5-sample moving average eliminates noise spikes

---

## 3. Exit Hysteresis State Machine

```
┌─────────────────┐
│  NORMAL STATE   │  RSSI strong (-70 dBm)
│  Attendance OK  │  Student sitting in class
└────────┬────────┘
         │
         │ 📱 Student rotates phone in pocket
         ▼
┌─────────────────┐
│  WEAK SIGNAL    │  RSSI drops to -90 dBm
│   (t=0s)        │  Beacon not detected
└────────┬────────┘
         │
         │ Start 30s grace timer ⏱️
         ▼
┌─────────────────────────────────────────┐
│        GRACE PERIOD (0-30s)             │
│  ⏳ Don't cancel yet - might be body    │
│     movement or temporary interference  │
└────────┬───────────────────┬────────────┘
         │                   │
         │ Signal returns    │ 30s elapsed
         │ within 30s        │ no signal
         ▼                   ▼
┌─────────────────┐   ┌──────────────────┐
│  NORMAL STATE   │   │  CANCEL          │
│  (Restored) ✅  │   │  ATTENDANCE ❌   │
│                 │   │                  │
│  "Was just body │   │  "Student left   │
│   movement"     │   │   classroom"     │
└─────────────────┘   └──────────────────┘
```

---

## 4. Dual-Threshold System

```
┌─────────────────────────────────────────────────────────┐
│                    CLASSROOM LAYOUT                      │
│                                                          │
│   Doorway         Middle        Front                   │
│     🚪             👤           🔵 Beacon                │
│    (5m)          (3m)          (1m)                     │
│                                                          │
│   RSSI: -78      RSSI: -72     RSSI: -65               │
└─────────────────────────────────────────────────────────┘

Entry Threshold: -75 dBm (CHECK-IN)
─────────────────────────────────────────────────
  -78 dBm ❌    -72 dBm ✅    -65 dBm ✅
  Too weak      CAN check in  CAN check in
  (doorway)     (middle)      (front)

Confirmation Threshold: -82 dBm (STAYING)
─────────────────────────────────────────────────
  -78 dBm ✅    -72 dBm ✅    -65 dBm ✅
  Can stay      Can stay      Can stay
  (if already   (normal)      (close)
   checked in)
```

**Key Insight:**
- Must be CLOSE to check in (-75 dBm)
- Can be FARTHER to stay (-82 dBm)
- Prevents doorway gaming
- Allows classroom movement

---

## 5. Complete Attendance Flow (Happy Path)

```
┌──────────────────────────────────────────────────────────────┐
│                     Student Journey                           │
└──────────────────────────────────────────────────────────────┘

t=0s: Student enters classroom 🚶
      └─> Beacon detected: -68 dBm (strong)
      └─> Smoothed RSSI: -68 dBm
      └─> Check threshold: -68 > -75 ✅
      └─> Status: PROVISIONAL 🟡

t=10s: Student sits down, puts phone in pocket 📱
       └─> Raw RSSI: -75 dBm (slightly weaker)
       └─> Smoothed RSSI: -71 dBm (still good)
       └─> Status: PROVISIONAL 🟡

t=20s: Student leans forward to write ✍️
       └─> Raw RSSI: -88 dBm (body blocking!)
       └─> Smoothed RSSI: -76 dBm (helped by smoothing)
       └─> Grace period: NOT needed (smoothed still OK)
       └─> Status: PROVISIONAL 🟡

t=30s: Phone rotates in pocket 🔄
       └─> Raw RSSI: -95 dBm (very weak!)
       └─> Smoothed RSSI: -85 dBm (smoothing helps)
       └─> Beacon "lost" for 16s
       └─> Grace period: ACTIVE ⏱️ (0/30s)
       └─> Status: PROVISIONAL 🟡 (not cancelled)

t=40s: Student adjusts position 🪑
       └─> Raw RSSI: -72 dBm (back to normal)
       └─> Smoothed RSSI: -78 dBm
       └─> Grace period: RESET ✅ (signal restored)
       └─> Status: PROVISIONAL 🟡

t=60s: CONFIRMATION CHECK ⏰
       └─> Smoothed RSSI: -74 dBm
       └─> Check threshold: -74 > -82 ✅ (lenient)
       └─> Backend confirms attendance
       └─> Status: CONFIRMED 🟢

Result: Attendance CONFIRMED despite body movement! ✅
```

---

## 6. Complete Attendance Flow (Student Leaves Early)

```
t=0s: Student enters classroom 🚶
      └─> Status: PROVISIONAL 🟡

t=25s: Student walks out (emergency) 🚪
       └─> Raw RSSI: -90 dBm (weak)
       └─> Smoothed RSSI: -85 dBm
       └─> Grace period: ACTIVE ⏱️ (0/30s)
       └─> Status: PROVISIONAL 🟡

t=35s: Still outside (10s)
       └─> Raw RSSI: null (no beacon)
       └─> Grace period: ACTIVE ⏱️ (10/30s)
       └─> Status: PROVISIONAL 🟡

t=45s: Still outside (20s)
       └─> Raw RSSI: null (no beacon)
       └─> Grace period: ACTIVE ⏱️ (20/30s)
       └─> Status: PROVISIONAL 🟡

t=55s: Still outside (30s) - GRACE EXPIRED ❌
       └─> Raw RSSI: null (no beacon)
       └─> Grace period: EXPIRED (30/30s)
       └─> Trigger: Confirmation failure
       └─> Status: CANCELLED 🔴

t=60s: CONFIRMATION CHECK ⏰
       └─> Backend tries to confirm
       └─> Provisional entry: ALREADY DELETED
       └─> Result: Confirmation FAILED ❌

Result: Attendance NOT CONFIRMED (student left) ❌
```

---

## 7. Doorway Gaming Prevention

```
┌─────────────────────────────────────────────────────┐
│                CLASSROOM LAYOUT                      │
│                                                      │
│  Outside      Doorway      Inside      Front        │
│               🚪──────────────────────🔵 Beacon     │
│                                                      │
│  Hallway      Threshold    Desk       Teacher       │
└─────────────────────────────────────────────────────┘

Scenario 1: Student at doorway (BLOCKED ✅)
────────────────────────────────────────────
Location: Doorway (5m from beacon)
Raw RSSI: -78 dBm
Smoothed: -78 dBm
Entry Threshold: -75 dBm
Result: -78 < -75 ❌ CANNOT CHECK IN
Message: "Move closer to beacon"

Scenario 2: Student properly inside (ALLOWED ✅)
────────────────────────────────────────────
Location: Inside classroom (2m from beacon)
Raw RSSI: -68 dBm
Smoothed: -69 dBm
Entry Threshold: -75 dBm
Result: -69 > -75 ✅ CAN CHECK IN
Status: PROVISIONAL → CONFIRMED

Scenario 3: Student checked in, moved to back (ALLOWED ✅)
────────────────────────────────────────────
Location: Back of class (6m from beacon)
Raw RSSI: -80 dBm
Smoothed: -80 dBm
Confirmation Threshold: -82 dBm (lenient!)
Result: -80 > -82 ✅ STAYS CONFIRMED
Note: Would NOT be allowed to CHECK IN from here (-80 < -75)
```

**Key:** Two thresholds prevent gaming while allowing movement!

---

## 8. Parameter Tuning Decision Tree

```
                    Start Testing
                         │
                         ▼
              ┌──────────────────────┐
              │ Run for 1 week       │
              │ Collect metrics      │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ False Cancellations? │
              │     (>5%)            │
              └──────┬───────┬───────┘
                     │       │
                  Yes│       │No
                     │       │
                     ▼       ▼
        ┌──────────────┐  ┌──────────────┐
        │ Increase:    │  │ Check for:   │
        │ - Grace      │  │ - Doorway    │
        │   period     │  │   gaming?    │
        │ - Confirm    │  │              │
        │   threshold  │  └──────┬───────┘
        │ - Smoothing  │         │
        │   window     │         │
        └──────┬───────┘         │
               │                 │
               │                 ▼
               │      ┌──────────────────┐
               │      │ Gaming detected? │
               │      │                  │
               │      └──────┬───────┬───┘
               │             │       │
               │          Yes│       │No
               │             │       │
               │             ▼       ▼
               │  ┌──────────────┐  ┌──────────────┐
               │  │ Increase:    │  │ System OK!   │
               │  │ - Entry      │  │ Document     │
               │  │   threshold  │  │ settings     │
               │  │ - Move       │  │ Deploy more  │
               │  │   beacon     │  └──────────────┘
               │  └──────┬───────┘
               │         │
               └─────────┴─────────────┐
                         │             │
                         ▼             │
              ┌──────────────────────┐ │
              │ Test again           │ │
              │ (24 hours)           │ │
              └──────────┬───────────┘ │
                         │             │
                         └─────────────┘
```

---

## 9. Comparison: Before vs After

```
┌─────────────────────────────────────────────────────────────┐
│                    BEFORE (Simple System)                    │
└─────────────────────────────────────────────────────────────┘

Raw RSSI → Threshold Check → Decision
  -72    →    -72 > -75     →   ✅ OK
  -68    →    -68 > -75     →   ✅ OK
  -88    →    -88 < -75     →   ❌ CANCEL (false negative!)
  -70    →    -70 > -75     →   ✅ OK (but too late)

Problem: One bad reading → Attendance cancelled ❌


┌─────────────────────────────────────────────────────────────┐
│              AFTER (Enhanced System)                         │
└─────────────────────────────────────────────────────────────┘

Raw RSSI → Smoothing → Dual Threshold → Hysteresis → Decision
  -72    →   -72     →   -72 > -75    →    -       →  ✅ OK
  -68    →   -70     →   -70 > -75    →    -       →  ✅ OK
  -88    →   -76     →   -76 > -82    →  Grace 0s  →  ⏳ WAIT
  -70    →   -74     →   -74 > -82    →  Reset     →  ✅ OK

Result: Bad readings absorbed → Attendance NOT cancelled ✅
```

---

## 10. Real-World Scenario Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│   Scenario         │ Before  │ After   │ Enhancement Used      │
├────────────────────┼─────────┼─────────┼─────────────────────────┤
│ Sitting still      │ ✅ OK   │ ✅ OK   │ N/A                    │
│ Phone in pocket    │ ❌ FAIL │ ✅ OK   │ Smoothing + Hysteresis │
│ Leaning forward    │ ❌ FAIL │ ✅ OK   │ Smoothing              │
│ Phone rotation     │ ❌ FAIL │ ✅ OK   │ Hysteresis (grace)     │
│ Walking in class   │ ⚠️ MAYBE│ ✅ OK   │ Dual threshold         │
│ At doorway         │ ❌ PASS │ ✅ FAIL │ Strict entry threshold │
│ Actually leaving   │ ⚠️ MAYBE│ ✅ FAIL │ Hysteresis detects it  │
│ Multiple beacons   │ ❌ FAIL │ ✅ OK   │ Smoothing              │
└─────────────────────────────────────────────────────────────────┘

Legend:
✅ OK   = Correct behavior
❌ FAIL = Incorrect behavior  
⚠️ MAYBE = Inconsistent/unreliable
```

---

## 11. System Health Dashboard (Conceptual)

```
┌─────────────────────────────────────────────────────────────┐
│              ATTENDANCE SYSTEM METRICS                       │
│                 (Monitor Weekly)                             │
└─────────────────────────────────────────────────────────────┘

False Cancellation Rate:  3.2% ✅ (Target: <5%)
██░░░░░░░░ 

Doorway False Positive:   1.1% ✅ (Target: <2%)
█░░░░░░░░░

Grace Period Triggers:    18% ✅ (Shows it's working!)
████░░░░░░

Confirmation Success:     96.8% ✅ (Target: >90%)
█████████░

Average RSSI at Confirm:  -72 dBm ✅ (Good signal)
                          (Target: -70±10)

┌─────────────────────────────────────────────────┐
│ Status: 🟢 SYSTEM HEALTHY                       │
│ Action: Monitor for 1 more week, then deploy   │
└─────────────────────────────────────────────────┘
```

---

**These diagrams should help visualize the system! 📊**
