import 'package:permission_handler/permission_handler.dart';
import 'package:attendance_app/core/utils/app_logger.dart';

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
    AppLogger.debug('Location status: ${statuses[Permission.location]}');
    AppLogger.debug(
        'Bluetooth Scan status: ${statuses[Permission.bluetoothScan]}');
    AppLogger.debug(
        'Bluetooth Connect status: ${statuses[Permission.bluetoothConnect]}');

    return statuses;
  }

  Future<bool> areBeaconPermissionsGranted() async {
    final statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values
        .every((status) => status == PermissionStatus.granted);
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
      AppLogger.debug('Notification permission already granted');
      return true;
    }

    final status = await Permission.notification.request();
    AppLogger.debug('Notification permission status: $status');

    if (status.isDenied) {
      AppLogger.warning('Notification permission denied by user');
      return false;
    }

    if (status.isPermanentlyDenied) {
      AppLogger.warning(
          'Notification permission permanently denied. Opening app settings...');
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
