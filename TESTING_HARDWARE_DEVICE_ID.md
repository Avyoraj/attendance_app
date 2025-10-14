# 🧪 Testing Hardware-Based Device ID Fix

## Critical Security Test: Uninstall Bypass Prevention

**Date:** October 14, 2025  
**Test Duration:** ~5 minutes  
**Severity:** CRITICAL

---

## 🎯 Test Objective

Verify that device locking **cannot be bypassed** by uninstalling and reinstalling the app.

---

## 📋 Prerequisites

Before testing:

1. ✅ **Run pub get:**
   ```bash
   cd attendance_app
   flutter pub get
   ```

2. ✅ **Clear existing device bindings:**
   ```bash
   cd attendance-backend
   node clear-device-bindings.js
   ```

3. ✅ **Backend server running:**
   ```bash
   node server.js
   ```

4. ✅ **Device connected:**
   ```bash
   flutter devices
   ```

---

## 🧪 Test Sequence

### **Phase 1: Initial Device Lock (Setup)**

**Steps:**
1. Build and install app:
   ```bash
   flutter run
   ```

2. Login as **Student 0080**
   - Enter: `0080`
   - Tap "Login"

3. **Expected Results:**
   ```
   ✅ LOGIN SUCCESS: Student 0080
   📱 Device ID: [hash of hardware ID]
   ✅ Home screen appears
   ```

4. **Backend Check:**
   ```bash
   node check-device-status.js
   ```
   
   Expected output:
   ```
   Students with Device Binding: 1
   Student 0080: a7f3b2c1d8e9f0a1... (64-char hash)
   ```

5. Logout from app

---

### **Phase 2: Verify Initial Blocking**

**Steps:**
1. Login as **Student 1**
   - Enter: `1`
   - Tap "Login"

2. **Expected Results:**
   ```
   🔐 Backend validation response: 403
   ❌ LOGIN BLOCKED BY BACKEND
   
   Dialog appears:
   🔒 Device Locked
   This device is already registered to Student ID: 0080
   ```

3. ✅ **Verify:** Student 1 NEVER sees home screen

4. Tap "OK" on dialog

---

### **Phase 3: CRITICAL TEST - Uninstall Bypass Attempt**

**Steps:**

1. **Close the app** (but don't uninstall yet)

2. **Check current device binding:**
   ```bash
   cd attendance-backend
   node check-device-status.js
   ```
   
   **Note down the device ID hash** (example):
   ```
   Student 0080: a7f3b2c1d8e9f0a1b2c3d4e5f6a7b8c9...
   ```

3. **Uninstall app completely:**
   
   **Method 1 (via ADB):**
   ```bash
   adb uninstall com.example.attendance_app
   ```
   
   **Method 2 (via Device):**
   - Long press app icon
   - Tap "Uninstall"
   - Confirm uninstall

4. **Verify uninstall:**
   ```bash
   adb shell pm list packages | grep attendance
   ```
   Should return: **(nothing)** - app is gone

5. **Reinstall app:**
   ```bash
   flutter run
   ```

6. **Check hardware ID in logs:**
   Look for:
   ```
   📱 Android Device ID: 9774d56d... (first 8 chars)
   ✅ Hardware-based ID (survives uninstall)
   ```

7. **Login as Student 1:**
   - Enter: `1`
   - Tap "Login"

8. **CRITICAL EXPECTED RESULT:**
   ```
   🔐 Backend validation response: 403
   ❌ LOGIN BLOCKED BY BACKEND
   
   Dialog appears:
   🔒 Device Locked
   This device is already registered to Student ID: 0080
   ```

9. ✅ **SUCCESS CRITERIA:**
   - Student 1 is STILL blocked
   - Error dialog appears
   - NEVER sees home screen
   - Device ID hash is THE SAME as before uninstall

10. **Verify device ID didn't change:**
    ```bash
    node check-device-status.js
    ```
    
    Expected:
    ```
    Student 0080: a7f3b2c1d8e9f0a1b2c3d4e5f6a7b8c9...
    ```
    
    **The hash should be IDENTICAL to Step 2!**

---

### **Phase 4: Verify Owner Can Re-login**

**Steps:**

1. **Login as Student 0080:**
   - Enter: `0080`
   - Tap "Login"

2. **Expected Results:**
   ```
   🔐 Backend validation response: 200
   ✅ LOGIN SUCCESS: Student 0080
   ✅ Welcome back!
   ```

3. ✅ **Verify:** Student 0080 can still login after uninstall

---

## 📊 Test Results Table

Fill this in during testing:

| Test | Action | Student ID | Expected | Actual | Status |
|------|--------|-----------|----------|--------|--------|
| 1    | First login | 0080 | ✅ Success | | |
| 2    | Blocked login | 1 | ❌ 403 Error | | |
| 3    | Note device hash | - | Record hash | | |
| 4    | Uninstall app | - | App removed | | |
| 5    | Reinstall app | - | App installed | | |
| 6    | Login after reinstall | 1 | ❌ STILL BLOCKED | | |
| 7    | Verify hash unchanged | - | Same hash | | |
| 8    | Owner re-login | 0080 | ✅ Success | | |

---

## ✅ Success Criteria

**ALL of the following MUST be true:**

- [ ] **Test 1:** Student 0080 initial login succeeds
- [ ] **Test 2:** Student 1 login blocked BEFORE uninstall
- [ ] **Test 3:** Device hash recorded (64-char hex string)
- [ ] **Test 4:** App uninstalled successfully
- [ ] **Test 5:** App reinstalled successfully
- [ ] **Test 6:** Student 1 login STILL blocked AFTER reinstall
- [ ] **Test 7:** Device hash is IDENTICAL before and after uninstall
- [ ] **Test 8:** Student 0080 can re-login after reinstall

**Critical Check:**
```
Device Hash Before Uninstall: a7f3b2c1d8e9f0a1...
Device Hash After Reinstall:  a7f3b2c1d8e9f0a1...
                              ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑
                              MUST BE IDENTICAL!
```

---

## 🐛 Troubleshooting

### **Issue 1: Different Hash After Reinstall**

**Symptoms:**
```
Before:  a7f3b2c1d8e9f0a1...
After:   d3e4f5a6b7c8d9e0...  ❌ DIFFERENT
```

**Diagnosis:** Hardware ID is not being used correctly

**Fix:**
1. Check logs for:
   ```
   📱 Android Device ID: [should be same number]
   ```

2. Verify `device_id_service.dart` uses:
   ```dart
   AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
   String hardwareId = androidInfo.id; // Must be .id not .uuid
   ```

---

### **Issue 2: Student 1 Can Login After Reinstall**

**Symptoms:**
```
Login as Student 1 → ✅ SUCCESS (BAD!)
```

**Diagnosis:** Backend not recognizing device

**Fix:**
1. Check backend logs:
   ```
   🔐 VALIDATING LOGIN: Student 1 on device [hash]
   ```

2. Compare hash with database:
   ```bash
   node check-device-status.js
   ```

3. Verify hash is same as Student 0080's device

---

### **Issue 3: "Unknown Device" Error**

**Symptoms:**
```
📱 Device ID: unknown-platform
```

**Diagnosis:** Platform detection failing

**Fix:**
1. Ensure app is running on Android or iOS (not web/desktop)
2. Check device info plugin is working:
   ```dart
   DeviceInfoPlugin().androidInfo // Should not throw
   ```

---

## 📝 Test Logs to Collect

During testing, collect these logs:

### **Flutter App Logs:**
```bash
flutter run > test_logs_flutter.txt 2>&1
```

Look for:
```
📱 Android Device ID: 9774d56d...
✅ Hardware-based ID (survives uninstall)
🔐 Backend validation response: 403
❌ LOGIN BLOCKED BY BACKEND
```

### **Backend Logs:**
```bash
node server.js > test_logs_backend.txt 2>&1
```

Look for:
```
🔐 VALIDATING LOGIN: Student 1 on device a7f3b2c1...
❌ LOGIN BLOCKED: Device locked to student 0080
```

### **Device Status:**
```bash
node check-device-status.js > test_device_status.txt
```

Run this:
- Before uninstall
- After reinstall
- Compare the hashes

---

## 🎯 Expected Timeline

| Phase | Duration | Critical Step |
|-------|----------|---------------|
| Setup | 2 min | Install app, login 0080 |
| Verification | 1 min | Try login as student 1 |
| Uninstall Test | 2 min | Uninstall → Reinstall → Test |
| Re-login Test | 30 sec | Verify 0080 works |
| **Total** | **~5 min** | Complete security test |

---

## 🔒 Security Validation

After passing all tests, you can confirm:

✅ **Device locking is unbreakable** (except factory reset)  
✅ **Uninstall bypass is prevented**  
✅ **Device ID is hardware-based**  
✅ **Hash remains consistent**  
✅ **Legitimate user can still access**  

**Status:** Production-ready security ✅

---

## 📸 Evidence Collection

Take screenshots of:

1. ✅ Student 0080 login success
2. ❌ Student 1 blocked error dialog (before uninstall)
3. 📱 App uninstall confirmation
4. 📲 App reinstall completion
5. ❌ Student 1 STILL blocked error dialog (after reinstall)
6. ✅ Student 0080 re-login success
7. 🔐 Device status showing same hash

---

## ✅ Final Verification

Run this command after all tests:

```bash
cd attendance-backend
node check-device-status.js
```

Expected output:
```
📊 Current State:
   Total Students: 23
   Students with Device Binding: 1

🔒 Students with Device Bindings:
   Student 0080: a7f3b2c1d8e9f0a1b2c3d4e5f6a7b8c9...
      Registered: 14/10/2025, [time]

✅ Device binding persisted through uninstall/reinstall!
```

**If hash is same before and after uninstall:** ✅ **TEST PASSED!**
