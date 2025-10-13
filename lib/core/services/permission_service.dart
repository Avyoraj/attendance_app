import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Future<Map<Permission, PermissionStatus>> requestBeaconPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // Log the permission statuses for debugging
    print('Location status: ${statuses[Permission.location]}');
    print('Bluetooth Scan status: ${statuses[Permission.bluetoothScan]}');
    print('Bluetooth Connect status: ${statuses[Permission.bluetoothConnect]}');

    return statuses;
  }

  Future<bool> areBeaconPermissionsGranted() async {
    final statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values.every((status) => status == PermissionStatus.granted);
  }

  Future<PermissionStatus> getLocationPermissionStatus() async {
    return await Permission.location.status;
  }

  Future<PermissionStatus> getBluetoothScanPermissionStatus() async {
    return await Permission.bluetoothScan.status;
  }

  Future<PermissionStatus> getBluetoothConnectPermissionStatus() async {
    return await Permission.bluetoothConnect.status;
  }

  /// Request notification permission for Android 13+ (API 33+)
  /// Returns true if permission is granted
  Future<bool> requestNotificationPermission() async {
    if (await Permission.notification.isGranted) {
      print('Notification permission already granted');
      return true;
    }

    final status = await Permission.notification.request();
    print('Notification permission status: $status');

    if (status.isDenied) {
      print('Notification permission denied by user');
      return false;
    }

    if (status.isPermanentlyDenied) {
      print('Notification permission permanently denied. Opening app settings...');
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }

  /// Check if notification permission is granted
  Future<bool> isNotificationPermissionGranted() async {
    return await Permission.notification.isGranted;
  }
}