# 🧪 Device Locking at Login - Quick Testing Guide

## ⚡ Quick Start (5 Minutes)

### 1. Start Backend
```powershell
cd attendance-backend
node server.js
```

**Wait for:**
```
✅ Connected to MongoDB
✅ Device uniqueness index ensured
✅ Listening on port 3000
```

### 2. Clear Database (Fresh Start)
```powershell
node clear-device-bindings.js
```

### 3. Start Flutter App
```powershell
cd ..\attendance_app
flutter run
```

---

## 📋 Test Sequence (Must Pass All)

### ✅ Test 1: First Student Login (Should SUCCEED)

**Steps:**
1. On login screen, enter: `0080`
2. Tap "Login"

**Expected Result:**
```
✅ Login succeeds
✅ Loading spinner shows
✅ Navigates to home screen
✅ Beacon scanning starts
```

**Backend Logs:**
```
🔐 VALIDATING LOGIN: Student 0080 on device 71420d18...
✅ LOGIN ALLOWED: New device for student 0080
```

**Flutter Logs:**
```
🔐 Backend validation response: 200
✅ LOGIN SUCCESS: Student 0080 on device 71420d18...
```

---

### ❌ Test 2: Second Student Login (Should FAIL)

**Steps:**
1. Logout from app
2. On login screen, enter: `2`
3. Tap "Login"

**Expected Result:**
```
❌ Login fails
❌ Error dialog appears:
   "🔒 Device Locked
   
   This device is already registered to Student ID: 0080
   
   Each device can only be used by one student.
   
   To use this device:
   1. Contact your administrator
   2. Ask them to reset device bindings
   3. Or use a different device
   
   [OK]"

❌ Stays on login screen (NO navigation to home)
```

**Backend Logs:**
```
🔐 VALIDATING LOGIN: Student 2 on device 71420d18...
❌ LOGIN BLOCKED: Device locked to student 0080
```

**Flutter Logs:**
```
🔐 Backend validation response: 403
❌ LOGIN BLOCKED BY BACKEND: This device is already linked to student ID: 0080
```

---

### ❌ Test 3: Third Student Login (Should FAIL)

**Steps:**
1. Tap "OK" on error dialog
2. Enter: `3`
3. Tap "Login"

**Expected Result:**
```
❌ Same error dialog appears
❌ References Student ID: 0080 (not Student 2)
❌ Stays on login screen
```

---

### ❌ Test 4: Fourth Student Login (Should FAIL)

**Steps:**
1. Enter: `4`
2. Tap "Login"

**Expected Result:**
```
❌ Same error dialog appears
❌ References Student ID: 0080
❌ Stays on login screen
```

---

### ✅ Test 5: Original Student Re-login (Should SUCCEED)

**Steps:**
1. Enter: `0080` (original owner)
2. Tap "Login"

**Expected Result:**
```
✅ Login succeeds
✅ Navigates to home screen
✅ Can check-in successfully
```

**Backend Logs:**
```
🔐 VALIDATING LOGIN: Student 0080 on device 71420d18...
✅ LOGIN ALLOWED: Device verified for student 0080
```

---

## 🎯 Success Criteria

**Must Pass ALL:**
- [ ] Test 1: Student 0080 login succeeds
- [ ] Test 2: Student 2 login BLOCKED with error dialog
- [ ] Test 3: Student 3 login BLOCKED with error dialog
- [ ] Test 4: Student 4 login BLOCKED with error dialog
- [ ] Test 5: Student 0080 can re-login successfully
- [ ] Error dialog shows correct locked student ID (0080)
- [ ] No blocked student ever sees home screen
- [ ] Backend logs show validation messages

---

## 🐛 Troubleshooting

### ❌ Problem: All logins fail

**Cause:** Backend not running

**Fix:**
```powershell
cd attendance-backend
node server.js
```

### ❌ Problem: All logins succeed (even Student 2)

**Cause:** Old version of backend

**Fix:**
```powershell
# Make sure you have latest server.js with /api/validate-device endpoint
# Restart backend
node server.js
```

### ❌ Problem: Error dialog doesn't show locked student

**Cause:** Flutter app using old code

**Fix:**
```powershell
flutter clean
flutter pub get
flutter run
```

### ❌ Problem: Network error during login

**Cause:** Backend URL mismatch

**Fix:**
Check `lib/features/auth/services/auth_service.dart`:
```dart
static const String _baseUrl = 'https://attendance-backend-omega.vercel.app/api';
// OR for local testing:
// static const String _baseUrl = 'http://192.168.1.121:3000/api';
```

---

## 📊 Test Results Table

| Test | Student ID | Expected | Result | Notes |
|------|-----------|----------|--------|-------|
| 1    | 0080      | ✅ Login succeeds | | First login |
| 2    | 2         | ❌ Login blocked | | Shows error dialog |
| 3    | 3         | ❌ Login blocked | | Shows error dialog |
| 4    | 4         | ❌ Login blocked | | Shows error dialog |
| 5    | 0080      | ✅ Login succeeds | | Re-login works |

---

## 🔍 Detailed Verification

### Check Backend Database:
```powershell
node check-device-status.js
```

**Expected After Test 1:**
```
Students with Device Bindings: 1
   Student 0080: 71420d18-8cf8-4c77-9288-5f3fa07d75d7
   
✅ No duplicate device IDs found
✅ Device uniqueness index exists
```

### Check Flutter Secure Storage:
```dart
// After successful login (Test 1)
Stored Student: 0080
Stored Device: 71420d18-8cf8-4c77-9288-5f3fa07d75d7

// After blocked login (Test 2)
Stored Student: 0080 (unchanged)
Stored Device: 71420d18-8cf8-4c77-9288-5f3fa07d75d7 (unchanged)
```

---

## 📸 Screenshot Checklist

**Take screenshots of:**
1. ✅ Student 0080 login success + home screen
2. ❌ Student 2 error dialog showing "locked to 0080"
3. ✅ Backend terminal showing validation logs
4. ✅ Flutter terminal showing login logs

---

## ⏱️ Time Estimate

- Setup: 2 minutes
- Test execution: 3 minutes
- Verification: 1 minute
- **Total: 6 minutes**

---

**Last Updated:** October 14, 2025  
**Feature:** Device Locking at Login  
**Priority:** 🔴 Critical (Security + UX)
