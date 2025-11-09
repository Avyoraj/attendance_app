import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/services/beacon_service.dart';

/// Quick test to verify refactored BeaconService works
void main() {
  group('Refactored BeaconService Tests', () {
    late BeaconService beaconService;

    setUp(() {
      beaconService = BeaconService();
    });

    test('Service initializes without errors', () {
      expect(beaconService, isNotNull);
    });

    test('Can feed RSSI samples', () {
      beaconService.feedRssiSample(-55);
      beaconService.feedRssiSample(-57);
      beaconService.feedRssiSample(-53);

      // Should not throw
      expect(true, true);
    });

    test('Can get RSSI data', () {
      beaconService.feedRssiSample(-55);

      final rawData = beaconService.getRawRssiData();

      expect(rawData, isA<Map<String, dynamic>>());
      expect(rawData.containsKey('rssi'), true);
      expect(rawData.containsKey('isInGracePeriod'), true);
    });

    test('Cooldown info returns null when no cooldown', () {
      final cooldownInfo = beaconService.getCooldownInfo();
      expect(cooldownInfo, isNull);
    });

    test('Can clear cooldown', () {
      beaconService.clearCooldown();
      // Should not throw
      expect(true, true);
    });

    test('Can set state change callback', () {
      var callbackCalled = false;
      beaconService.setOnAttendanceStateChanged((state, studentId, classId) {
        callbackCalled = true;
      });

      // Callback should be set
      expect(callbackCalled, false); // Not called yet
    });
  });
}
