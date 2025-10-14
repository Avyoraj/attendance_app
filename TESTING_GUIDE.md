# 🧪 TESTING GUIDE: Flutter App with New Features

## ✅ **Phase 1: Test Device ID Service**

### Test 1.1: Device ID Generation
```bash
# Run the app
flutter run
```

Add this code to your `main.dart` or test file:

```dart
import 'package:logger/logger.dart';
import 'core/services/device_id_service.dart';

Future<void> testDeviceId() async {
  final logger = Logger();
  final deviceIdService = DeviceIdService();
  
  // Test 1: Get device ID
  final deviceId = await deviceIdService.getDeviceId();
  logger.i('Device ID: $deviceId');
  
  // Test 2: Get device name
  final deviceName = await deviceIdService.getDeviceName();
  logger.i('Device Name: $deviceName');
  
  // Test 3: Check if device is registered
  final hasDevice = await deviceIdService.hasDeviceId();
  logger.i('Device Registered: $hasDevice');
  
  // Test 4: Get full info
  final info = await deviceIdService.getDeviceInfo();
  logger.i('Full Info: $info');
}
```

**Expected Results:**
- ✅ First run: Generates new UUID (e.g., `a1b2c3d4-e5f6-...`)
- ✅ Subsequent runs: Returns SAME UUID (proves persistence)
- ✅ Device name shows manufacturer and model
- ✅ `hasDeviceId()` returns `true` after first run

---

## ✅ **Phase 2: Test Backend Connection**

### Test 2.1: Update API Base URL

**File:** `lib/core/services/http_service.dart` (line 13)

```dart
// For testing locally:
static const String _baseUrl = 'http://localhost:3000/api';

// OR for Android emulator:
static const String _baseUrl = 'http://10.0.2.2:3000/api';

// OR for physical device (replace with your computer's IP):
static const String _baseUrl = 'http://192.168.1.xxx:3000/api';
```

### Test 2.2: Check Backend Health

Add this to your test:

```dart
import 'core/services/http_service.dart';

Future<void> testBackendConnection() async {
  final httpService = HttpService();
  final logger = Logger();
  
  try {
    final response = await httpService.get(
      url: 'http://localhost:3000/api/health',
    );
    
    logger.i('Backend Status: ${response.statusCode}');
    logger.i('Response: ${response.body}');
  } catch (e) {
    logger.e('Connection Failed: $e');
  }
}
```

**Expected Results:**
- ✅ Status code: `200`
- ✅ Response: `{"status":"ok","database":"connected"}`
- ❌ If fails: Check backend is running (`npm run dev`)

---

## ✅ **Phase 3: Test Check-In Flow**

### Test 3.1: Manual Check-In Test

```dart
import 'core/services/device_id_service.dart';
import 'core/services/http_service.dart';

Future<void> testCheckIn() async {
  final deviceIdService = DeviceIdService();
  final httpService = HttpService();
  final logger = Logger();
  
  // Step 1: Get device ID
  final deviceId = await deviceIdService.getDeviceId();
  logger.i('Using Device ID: $deviceId');
  
  // Step 2: Submit check-in
  final result = await httpService.checkIn(
    studentId: 'TEST_FLUTTER_001',
    classId: 'CS101',
    deviceId: deviceId,
    rssi: -65,
  );
  
  // Step 3: Check result
  if (result['success'] == true) {
    logger.i('✅ Check-in Success!');
    logger.i('Attendance ID: ${result['attendanceId']}');
    logger.i('Status: ${result['status']}');
  } else {
    logger.e('❌ Check-in Failed: ${result['message']}');
  }
}
```

**Expected Results:**
- ✅ First check-in: Success with `status: provisional`
- ✅ Backend dashboard shows new record
- ✅ Device ID is saved to student record
- ✅ RSSI value recorded

**Then check dashboard:**
```
http://localhost:3000
```

You should see:
- Student: `TEST_FLUTTER_001`
- Class: `CS101`
- Status: `PROVISIONAL` (orange badge)
- Device: 🔒 (locked icon)
- RSSI: -65 dBm (green/yellow/red indicator)

---

## ✅ **Phase 4: Test Device Locking**

### Test 4.1: Device Mismatch Detection

```dart
Future<void> testDeviceMismatch() async {
  final httpService = HttpService();
  final logger = Logger();
  
  // Try to check in with DIFFERENT device ID
  final result = await httpService.checkIn(
    studentId: 'TEST_FLUTTER_001', // SAME student
    classId: 'CS102',
    deviceId: 'fake-device-id-12345', // DIFFERENT device
    rssi: -70,
  );
  
  if (result['error'] == 'DEVICE_MISMATCH') {
    logger.i('✅ Device mismatch detected correctly!');
    logger.i('Message: ${result['message']}');
  } else {
    logger.e('❌ Device mismatch NOT detected!');
  }
}
```

**Expected Results:**
- ✅ Should return error: `DEVICE_MISMATCH`
- ✅ Message: "This account is linked to a different device"
- ✅ HTTP status: `403 Forbidden`

---

## ✅ **Phase 5: Test Two-Step Confirmation**

### Test 5.1: Auto-Confirmation

1. **Check in:**
   ```dart
   await testCheckIn(); // Creates provisional attendance
   ```

2. **Wait 10 minutes** (or modify `app_constants.dart` to 1 minute for testing):
   ```dart
   static const Duration secondCheckDelay = Duration(minutes: 1); // FOR TESTING
   ```

3. **Check dashboard after 10 min:**
   - Status should change from `PROVISIONAL` → `CONFIRMED`
   - Green badge should appear
   - `confirmedAt` timestamp should be set

**To test faster:**
- Modify `app_constants.dart` line 21: `Duration(minutes: 1)`
- Restart app
- Check in
- Wait 1 minute
- Refresh dashboard

---

## ✅ **Phase 6: Test RSSI Streaming**

### Test 6.1: Verify RSSI Data Collection

After check-in, RSSI streaming starts automatically for 15 minutes.

**Check MongoDB:**
1. Open MongoDB Compass or Atlas
2. Navigate to `attendance_system` database
3. Open `rssistreams` collection
4. You should see documents like:

```json
{
  "_id": "...",
  "studentId": "TEST_FLUTTER_001",
  "classId": "CS101",
  "sessionDate": "2025-10-14",
  "rssiData": [
    {"timestamp": "2025-10-14T10:00:00Z", "rssi": -65, "distance": 2.5},
    {"timestamp": "2025-10-14T10:00:05Z", "rssi": -67, "distance": 2.8},
    ...
  ],
  "totalReadings": 180
}
```

**Expected:**
- ✅ New document created every check-in
- ✅ RSSI captured every 5 seconds
- ✅ Upload batches every minute (50 readings each)
- ✅ Streaming stops after 15 minutes
- ✅ Total readings: ~180 (15 min × 60 sec / 5 sec)

---

## ✅ **Phase 7: Integration with Beacon Scanner**

### Test 7.1: Connect to Real Beacon

Update your beacon ranging code to use the new integrated flow:

```dart
import 'core/services/beacon_service.dart';

void startBeaconScanning(String studentId) {
  final beaconService = BeaconService();
  
  // Set up state listener
  beaconService.setOnAttendanceStateChanged((state, sid, cid) {
    print('Attendance State: $state');
    // Update UI based on state
  });
  
  // Start ranging
  beaconService.startRanging().listen((result) {
    if (result.beacons.isNotEmpty) {
      for (var beacon in result.beacons) {
        final classId = beaconService.getClassIdFromBeacon(beacon);
        
        // This will automatically:
        // 1. Get device ID
        // 2. Submit check-in
        // 3. Schedule confirmation
        // 4. Start RSSI streaming
        final isConfirmed = beaconService.analyzeBeacon(
          beacon,
          studentId,
          classId,
        );
        
        if (isConfirmed) {
          print('✅ Attendance confirmed!');
        }
      }
    }
  });
}
```

---

## 🎯 **Complete Test Checklist**

### Backend Tests:
- [ ] Backend server running (`npm run dev`)
- [ ] MongoDB connected
- [ ] Health endpoint returns 200
- [ ] Dashboard accessible at localhost:3000

### Device ID Tests:
- [ ] Device ID generates on first run
- [ ] Device ID persists across app restarts
- [ ] Device name shows correctly
- [ ] Multiple app installs = different IDs

### Check-In Tests:
- [ ] First check-in creates provisional status
- [ ] Backend saves device ID
- [ ] Dashboard shows new record
- [ ] RSSI value recorded

### Device Lock Tests:
- [ ] Second device gets 403 error
- [ ] Error message: "linked to different device"
- [ ] UI shows device mismatch alert

### Confirmation Tests:
- [ ] Status changes to confirmed after 10 min
- [ ] `confirmedAt` timestamp set
- [ ] Dashboard badge turns green

### RSSI Streaming Tests:
- [ ] Streaming starts after check-in
- [ ] Data collected every 5 seconds
- [ ] Batches uploaded every minute
- [ ] MongoDB has rssistreams records
- [ ] Streaming stops after 15 minutes

### Beacon Integration Tests:
- [ ] Real ESP32 beacon detected
- [ ] Auto check-in on beacon detection
- [ ] State callbacks trigger UI updates
- [ ] All services work together

---

## 🐛 **Troubleshooting**

### Problem: "Connection refused"
**Solution:**
- Check backend is running
- Use correct IP address (not localhost on physical device)
- For Android emulator, use `10.0.2.2` instead of `localhost`

### Problem: "Device mismatch" on same device
**Solution:**
- Check device ID is consistent
- Clear app data if testing: `flutter clean && flutter run`
- To reset device ID: Call `DeviceIdService().clearDeviceId()`

### Problem: RSSI streaming not working
**Solution:**
- Check beacon is detected
- Verify `getCurrentRssi()` returns valid value
- Check MongoDB connection
- Look for upload errors in logs

### Problem: Confirmation not happening
**Solution:**
- Check timer duration in `app_constants.dart`
- Verify backend `/api/attendance/confirm` endpoint works
- Check confirmation service is initialized
- Look for errors in Flutter console

---

## 📱 **Testing on Different Platforms**

### Android Emulator:
```dart
static const String _baseUrl = 'http://10.0.2.2:3000/api';
```

### iOS Simulator:
```dart
static const String _baseUrl = 'http://localhost:3000/api';
```

### Physical Device (same WiFi):
```dart
// Find your computer's IP:
// Windows: ipconfig
// Mac/Linux: ifconfig
static const String _baseUrl = 'http://192.168.1.xxx:3000/api';
```

---

## ✅ **Success Criteria**

Your system is working perfectly when:

1. ✅ Device generates unique ID on first launch
2. ✅ Check-in creates provisional attendance
3. ✅ Device ID locks to student account
4. ✅ Different device gets rejected (403)
5. ✅ Attendance auto-confirms after 10 minutes
6. ✅ RSSI data streams to MongoDB
7. ✅ Dashboard shows all data in real-time
8. ✅ Beacon detection triggers automatic flow
9. ✅ All three features work together seamlessly

**When all checkboxes are checked, you're ready for production! 🚀**
