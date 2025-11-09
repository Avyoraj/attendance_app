import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/services/beacon_service/beacon_state_manager.dart';

void main() {
  group('BeaconStateManager lockout', () {
    test('isInLockout is true during lockout window and false after expiry',
        () async {
      final manager = BeaconStateManager();

      // Initially no lockout
      expect(manager.isInLockout, isFalse);

      // Activate a short lockout
      manager.setPostConfirmationLockout(const Duration(milliseconds: 800));
      expect(manager.isInLockout, isTrue);

      // Still within window
      await Future.delayed(const Duration(milliseconds: 500));
      expect(manager.isInLockout, isTrue);

      // After expiry it should auto-clear
      await Future.delayed(const Duration(milliseconds: 400));
      expect(manager.isInLockout, isFalse);

      // Subsequent checks remain false
      expect(manager.isInLockout, isFalse);
    });
  });
}
