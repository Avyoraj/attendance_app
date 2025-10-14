/// INTEGRATION GUIDE: How to Use the New Attendance Features
/// 
/// This file shows you how to integrate Device ID Locking, Two-Step Attendance,
/// and RSSI Streaming into your existing app.

import 'package:flutter/material.dart';
import 'lib/core/services/beacon_service.dart';
import 'lib/core/services/device_id_service.dart';

/// Example 1: Display Device Information on Login Screen
class DeviceInfoWidget extends StatefulWidget {
  @override
  _DeviceInfoWidgetState createState() => _DeviceInfoWidgetState();
}

class _DeviceInfoWidgetState extends State<DeviceInfoWidget> {
  String _deviceId = 'Loading...';
  String _deviceName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final deviceIdService = DeviceIdService();
    final info = await deviceIdService.getDeviceInfo();
    
    setState(() {
      _deviceId = info['deviceId']!;
      _deviceName = info['deviceName']!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔒 Device Locked', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('Device: $_deviceName', style: TextStyle(fontSize: 14)),
            Text('ID: ${_deviceId.substring(0, 8)}...', 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 8),
            Text('This account is permanently linked to this device.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

/// Example 2: Handle Attendance State Changes
class AttendanceScreen extends StatefulWidget {
  final String studentId;

  AttendanceScreen({required this.studentId});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _attendanceState = 'Scanning for beacon...';
  Color _stateColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _setupBeaconService();
  }

  void _setupBeaconService() {
    final beaconService = BeaconService();
    
    // Listen for attendance state changes
    beaconService.setOnAttendanceStateChanged((state, studentId, classId) {
      setState(() {
        switch (state) {
          case 'provisional':
            _attendanceState = '⏳ Check-in recorded!\nStay in class for 10 min to confirm';
            _stateColor = Colors.orange;
            break;
          case 'confirmed':
            _attendanceState = '✅ Attendance Confirmed!\nYou may now leave';
            _stateColor = Colors.green;
            _showSuccessDialog();
            break;
          case 'device_mismatch':
            _attendanceState = '🔒 Device Mismatch!\nThis account is linked to another device';
            _stateColor = Colors.red;
            _showDeviceMismatchDialog();
            break;
          case 'failed':
            _attendanceState = '❌ Check-in Failed\nMove closer to the beacon';
            _stateColor = Colors.red;
            break;
          default:
            _attendanceState = 'Scanning for beacon...';
            _stateColor = Colors.blue;
        }
      });
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ Success'),
        content: Text('Your attendance has been confirmed!\n\n'
            '📡 RSSI data is being collected for security.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeviceMismatchDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 8),
            Text('Device Locked'),
          ],
        ),
        content: Text(
          'This account is permanently linked to another device.\n\n'
          'Contact your administrator if you believe this is an error.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Optionally navigate to login screen
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForState(),
              size: 80,
              color: _stateColor,
            ),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                _attendanceState,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: _stateColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForState() {
    if (_attendanceState.contains('✅')) return Icons.check_circle;
    if (_attendanceState.contains('⏳')) return Icons.hourglass_top;
    if (_attendanceState.contains('🔒')) return Icons.lock;
    if (_attendanceState.contains('❌')) return Icons.error;
    return Icons.bluetooth_searching;
  }
}

/// Example 3: Check Backend Connection
Future<void> testBackendConnection() async {
  final deviceIdService = DeviceIdService();
  final deviceId = await deviceIdService.getDeviceId();
  
  print('🔑 Device ID: $deviceId');
  print('📡 Sending test check-in to backend...');
  
  // The BeaconService will automatically handle this when beacon is detected
  // No manual API calls needed - it's all automatic!
}

/// USAGE INSTRUCTIONS:
/// 
/// 1. **Update your existing attendance screen:**
///    - Copy the _setupBeaconService() method
///    - Add state management for UI updates
///    - Show dialogs for device mismatch
/// 
/// 2. **Add device info to login/profile screen:**
///    - Use DeviceInfoWidget to show device lock status
///    - Users should see their device is registered
/// 
/// 3. **Test the flow:**
///    - Run the app on Device A
///    - Check in with student ID
///    - Should see "provisional" → "confirmed" states
///    - Uninstall and reinstall on Device B
///    - Try to check in with same student ID
///    - Should see device mismatch error
/// 
/// 4. **Monitor in dashboard:**
///    - Open http://localhost:3000
///    - See real-time status changes
///    - View RSSI data being collected
///    - Check device lock icons
/// 
/// All backend communication is handled automatically by BeaconService!
