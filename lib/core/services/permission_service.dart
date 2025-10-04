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
}