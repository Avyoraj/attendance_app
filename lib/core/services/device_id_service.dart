import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for managing unique device identification
/// Uses HARDWARE-BASED device ID that survives app uninstall
/// Ensures one device per student account (prevents sharing)
class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  final _deviceInfo = DeviceInfoPlugin();

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// Get HARDWARE-BASED device ID (survives app uninstall)
  /// Android: Uses Android ID (persistent until factory reset)
  /// iOS: Uses identifierForVendor (persistent until all apps from vendor removed)
  Future<String> getDeviceId() async {
    // Return cached if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    String hardwareId;

    try {
      if (Platform.isAndroid) {
        // ✅ ANDROID: Use Android ID (survives app uninstall)
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        hardwareId = androidInfo.id; // This is Android ID
        
        print('📱 Android Device ID: ${hardwareId.substring(0, 8)}...');
        print('✅ Hardware-based ID (survives uninstall)');
        
      } else if (Platform.isIOS) {
        // ✅ iOS: Use identifierForVendor (survives app uninstall)
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        hardwareId = iosInfo.identifierForVendor ?? 'unknown-ios';
        
        print('📱 iOS Device ID: ${hardwareId.substring(0, 8)}...');
        print('✅ Hardware-based ID (survives uninstall)');
        
      } else {
        // Fallback for other platforms
        hardwareId = 'unknown-platform';
      }

      // Hash the hardware ID for additional security
      // This ensures backend never stores raw hardware IDs
      final bytes = utf8.encode(hardwareId);
      final hash = sha256.convert(bytes);
      final hashedId = hash.toString();

      _cachedDeviceId = hashedId;
      return hashedId;
      
    } catch (e) {
      print('❌ Error getting hardware device ID: $e');
      // Fallback: Use a consistent but non-hardware ID
      _cachedDeviceId = 'error-device-id';
      return _cachedDeviceId!;
    }
  }

  /// Get device name/model for display purposes
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        _cachedDeviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        _cachedDeviceName = '${iosInfo.name} (${iosInfo.model})';
      } else {
        _cachedDeviceName = 'Unknown Device';
      }
    } catch (e) {
      _cachedDeviceName = 'Unknown Device';
    }

    return _cachedDeviceName!;
  }

  /// Get full device information
  Future<Map<String, String>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
    };
  }

  /// Clear cached device ID (for testing/debugging only)
  /// Note: Cannot clear hardware-based ID, only cache
  void clearCache() {
    _cachedDeviceId = null;
    _cachedDeviceName = null;
    print('🗑️ Device ID cache cleared');
  }
}
