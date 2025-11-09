import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/features/attendance/screens/home_screen/home_screen_state.dart';
import 'package:attendance_app/features/attendance/screens/home_screen/home_screen_timers.dart';
import 'package:attendance_app/features/attendance/screens/home_screen/home_screen_sync.dart';

/// Integration test for HomeScreen modules
///
/// Tests that all modules work together correctly:
/// - State module
/// - Timers module
/// - Sync module
/// - Module dependencies
void main() {
  group('HomeScreen Module Integration Tests', () {
    late HomeScreenState state;
    late HomeScreenSync sync;
    late HomeScreenTimers timers;
    const testStudentId = 'TEST123';

    setUp(() {
      state = HomeScreenState();
      sync = HomeScreenSync(
        state: state,
        studentId: testStudentId,
      );
      timers = HomeScreenTimers(
        state: state,
        sync: sync,
      );
    });

    tearDown(() {
      state.dispose();
    });

    test('All modules initialize successfully', () {
      expect(state, isNotNull);
      expect(sync, isNotNull);
      expect(timers, isNotNull);
    });

    test('State module works independently', () {
      // Test state operations
      state.updateBeaconStatus('Test status');
      expect(state.beaconStatus, 'Test status');
      expect(state.beaconStatusType, BeaconStatusType.info);

      state.resetToScanning();
      expect(state.beaconStatus, '📡 Scanning for classroom beacon...');
      expect(state.beaconStatusType, BeaconStatusType.scanning);
      expect(state.isCheckingIn, false);
    });

    test('Timers module has access to state', () {
      // Verify timers can access state
      expect(timers.isConfirmationTimerActive(), false);
      expect(timers.isCooldownRefreshTimerActive(), false);
    });

    test('Sync module has access to state and studentId', () {
      // Verify sync has correct studentId
      expect(sync.studentId, testStudentId);
      expect(sync.state, state);
    });

    test('Formatted time works correctly', () {
      state.remainingSeconds = 180; // 3 minutes
      expect(timers.getFormattedTimeRemaining(), '3:00');

      state.remainingSeconds = 125; // 2:05
      expect(timers.getFormattedTimeRemaining(), '2:05');
    });

    test('Status locking works across modules', () {
      // Set a locked status
      state.beaconStatusType = BeaconStatusType.provisional;
      expect(state.isStatusLocked(), true);

      // Verify state reflects this
      expect(state.isInProvisionalState(), false);
    });

    test('Provisional state is correctly tracked', () {
      // Set provisional state
      state.isAwaitingConfirmation = true;
      state.remainingSeconds = 180;

      expect(state.isInProvisionalState(), true);
      expect(state.isAwaitingConfirmation, true);
    });

    test('Timer state management', () {
      // Cancel all timers (should not throw)
      expect(() => timers.cancelAllTimers(), returnsNormally);

      expect(timers.isConfirmationTimerActive(), false);
      expect(timers.isCooldownRefreshTimerActive(), false);
    });

    test('Multiple state updates work correctly', () {
      // Simulate a check-in flow
      state.beaconStatusType = BeaconStatusType.scanning;
      expect(state.isStatusLocked(), false);

      state.beaconStatusType = BeaconStatusType.provisional;
      expect(state.isStatusLocked(), true);

      state.isAwaitingConfirmation = true;
      state.remainingSeconds = 180;
      expect(state.isInProvisionalState(), true);

      state.remainingSeconds = 0;
      expect(state.isInProvisionalState(), false);
    });

    test('State reset clears all relevant flags', () {
      // Set up a complex state
      state.beaconStatus = 'Check-in recorded';
      state.isCheckingIn = true;
      state.isAwaitingConfirmation = true;
      state.remainingSeconds = 100;
      state.currentClassId = 'CS101';
      state.cooldownInfo = {'test': 'data'};

      // Reset
      state.resetToScanning();

      // Verify critical flags are reset
      expect(state.isCheckingIn, false);
      expect(state.isAwaitingConfirmation, false);
      expect(state.remainingSeconds, 0);
      // Note: cooldownInfo and currentClassId persist through reset
    });

    test('Services are accessible from state', () {
      expect(state.beaconService, isNotNull);
      expect(state.attendanceService, isNotNull);
      expect(state.httpService, isNotNull);
      expect(state.logger, isNotNull);
      expect(state.authService, isNotNull);
    });
  });

  group('HomeScreen Module Isolation Tests', () {
    test('State module can be used independently', () {
      final state = HomeScreenState();

      state.updateBeaconStatus('Independent test');
      expect(state.beaconStatus, 'Independent test');

      state.dispose();
    });

    test('Sync module requires state and studentId', () {
      final state = HomeScreenState();
      final sync = HomeScreenSync(
        state: state,
        studentId: 'STUDENT456',
      );

      expect(sync.state, state);
      expect(sync.studentId, 'STUDENT456');

      state.dispose();
    });

    test('Timers module requires state and sync', () {
      final state = HomeScreenState();
      final sync = HomeScreenSync(
        state: state,
        studentId: 'STUDENT789',
      );
      final timers = HomeScreenTimers(
        state: state,
        sync: sync,
      );

      expect(timers.state, state);
      expect(timers.sync, sync);

      state.dispose();
    });
  });
}
