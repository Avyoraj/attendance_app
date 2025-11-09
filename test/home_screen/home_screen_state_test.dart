import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/features/attendance/screens/home_screen/home_screen_state.dart';

/// Test suite for HomeScreenState module
///
/// Validates:
/// - State initialization
/// - State updates
/// - Status locking logic
/// - Timer references
/// - Service instances
void main() {
  group('HomeScreenState Tests', () {
    late HomeScreenState state;

    setUp(() {
      state = HomeScreenState();
    });

    tearDown(() {
      state.dispose();
    });

    test('State initializes with correct default values', () {
      expect(state.beaconStatus, 'Initializing...');
      expect(state.beaconStatusType, BeaconStatusType.info);
      expect(state.isCheckingIn, false);
      expect(state.showBatteryCard, false);
      expect(state.isAwaitingConfirmation, false);
      expect(state.remainingSeconds, 0);
      expect(state.currentClassId, null);
      expect(state.cooldownInfo, null);
    });

    test('Service instances are initialized', () {
      expect(state.beaconService, isNotNull);
      expect(state.attendanceService, isNotNull);
      expect(state.authService, isNotNull);
      expect(state.logger, isNotNull);
      expect(state.httpService, isNotNull);
    });

    test('resetToScanning() resets state correctly', () {
      // Setup state with values
      state.beaconStatus = 'Some status';
      state.beaconStatusType = BeaconStatusType.info;
      state.isCheckingIn = true;
      state.isAwaitingConfirmation = true;
      state.remainingSeconds = 100;

      // Reset
      state.resetToScanning();

      // Verify reset
      expect(state.beaconStatus, '📡 Scanning for classroom beacon...');
      expect(state.beaconStatusType, BeaconStatusType.scanning);
      expect(state.isCheckingIn, false);
      expect(state.isAwaitingConfirmation, false);
      expect(state.remainingSeconds, 0);
    });

    test('updateBeaconStatus() updates status', () {
      state.updateBeaconStatus('Test status',
          type: BeaconStatusType.confirming);
      expect(state.beaconStatus, 'Test status');
      expect(state.beaconStatusType, BeaconStatusType.confirming);
    });

    test('isStatusLocked() returns true for locked states', () {
      final lockedTypes = <BeaconStatusType>{
        BeaconStatusType.provisional,
        BeaconStatusType.confirming,
        BeaconStatusType.confirmed,
        BeaconStatusType.success,
        BeaconStatusType.cancelled,
        BeaconStatusType.cooldown,
      };

      for (var type in lockedTypes) {
        state.beaconStatusType = type;
        expect(state.isStatusLocked(), true,
            reason: 'Status "$type" should be locked');
      }
    });

    test('isStatusLocked() returns false for unlocked states', () {
      final unlockedTypes = <BeaconStatusType>{
        BeaconStatusType.scanning,
        BeaconStatusType.failed,
        BeaconStatusType.deviceLocked,
        BeaconStatusType.info,
      };

      for (var type in unlockedTypes) {
        state.beaconStatusType = type;
        expect(state.isStatusLocked(), false,
            reason: 'Status "$type" should not be locked');
      }
    });

    test('isInProvisionalState() returns correct value', () {
      // Not in provisional state
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      expect(state.isInProvisionalState(), false);

      // In provisional state
      state.isAwaitingConfirmation = true;
      state.remainingSeconds = 100;
      expect(state.isInProvisionalState(), true);

      // Awaiting but no time remaining
      state.isAwaitingConfirmation = true;
      state.remainingSeconds = 0;
      expect(state.isInProvisionalState(), false);
    });

    test('getFormattedRemainingTime() formats time correctly', () {
      state.remainingSeconds = 125; // 2:05
      expect(state.getFormattedRemainingTime(), '2:05');

      state.remainingSeconds = 60; // 1:00
      expect(state.getFormattedRemainingTime(), '1:00');

      state.remainingSeconds = 9; // 0:09
      expect(state.getFormattedRemainingTime(), '0:09');

      state.remainingSeconds = 0; // 0:00
      expect(state.getFormattedRemainingTime(), '0:00');
    });

    test('Static battery check flags work correctly', () {
      // Initial state
      expect(HomeScreenState.hasCheckedBatteryOnce, false);
      expect(HomeScreenState.cachedBatteryCardState, null);

      // Set values
      HomeScreenState.hasCheckedBatteryOnce = true;
      HomeScreenState.cachedBatteryCardState = false;

      expect(HomeScreenState.hasCheckedBatteryOnce, true);
      expect(HomeScreenState.cachedBatteryCardState, false);

      // Reset for other tests
      HomeScreenState.hasCheckedBatteryOnce = false;
      HomeScreenState.cachedBatteryCardState = null;
    });

    test('dispose() cleans up resources', () {
      // Use a fresh instance so tearDown can still dispose the shared state
      final tempState = HomeScreenState();
      expect(() => tempState.dispose(), returnsNormally);
    });
  });
}
