import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/core/utils/app_logger.dart';
// Removed HeroStatusCard in favor of a calmer, single status banner.
// import '../widgets/hero_status_card.dart';
import '../widgets/calm_status_banner.dart';
import '../../../core/constants/app_constants.dart';
import 'home_screen/home_screen_state.dart';
import 'home_screen/home_screen_callbacks.dart';
import 'home_screen/home_screen_timers.dart';
import 'home_screen/home_screen_sync.dart';
import 'home_screen/home_screen_battery.dart';
import 'home_screen/home_screen_helpers.dart';
import 'home_screen/home_screen_beacon.dart';

/// 🏠 HomeScreen - Refactored & Modularized
///
/// Main screen for attendance tracking using beacon technology.
/// This is the orchestrator that delegates to specialized modules.
///
/// Architecture:
/// - State management → HomeScreenState
/// - Beacon callbacks → HomeScreenCallbacks
/// - Timer management → HomeScreenTimers
/// - Backend sync → HomeScreenSync
/// - Battery optimization → HomeScreenBattery
/// - Helper functions → HomeScreenHelpers
/// - Beacon scanning → HomeScreenBeacon
///
/// Benefits:
/// - 83% smaller (1,153 lines → 200 lines)
/// - Clear separation of concerns
/// - Easy to test and maintain
/// - Backward compatible
class HomeScreen extends StatefulWidget {
  final String studentId;

  const HomeScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Core state module
  late final HomeScreenState _state;

  // Feature modules
  late final HomeScreenCallbacks _callbacks;
  late final HomeScreenTimers _timers;
  late final HomeScreenSync _sync;
  late final HomeScreenBattery _battery;
  late final HomeScreenHelpers _helpers;
  late final HomeScreenBeacon _beacon;

  @override
  void initState() {
    super.initState();
    _initializeModules();
    _startApp();
  }

  /// Initialize all feature modules
  void _initializeModules() {
    // Create state module first
    _state = HomeScreenState();

    // Helpers need context early for snackbars/navigation
    _helpers = HomeScreenHelpers(
      state: _state,
      context: context,
      studentId: widget.studentId,
    );

    // Create sync module (needed by timers)
    _sync = HomeScreenSync(
      state: _state,
      studentId: widget.studentId,
    );

    // Create timers module (needs sync for confirmation check)
    _timers = HomeScreenTimers(
      state: _state,
      sync: _sync,
    );

    // Create callbacks module (needs timers and helpers)
    _callbacks = HomeScreenCallbacks(
      state: _state,
      timers: _timers,
      helpers: _helpers,
    );

    // Create battery module (needs setState and showSnackBar)
    _battery = HomeScreenBattery(
      state: _state,
      showSnackBar: _helpers.showSnackBar,
    );

    // Create beacon module (needs check-in logic)
    _beacon = HomeScreenBeacon(
      state: _state,
      studentId: widget.studentId,
      cancelProvisionalAttendance: _cancelProvisionalAttendance,
    );
  }

  /// Start the app - initialize beacon scanner, check battery, sync state
  Future<void> _startApp() async {
    await _beacon.initializeBeaconScanner();
    _callbacks.setupBeaconStateCallback();
    await _battery.checkBatteryOptimizationOnce();
    await _sync.syncStateOnStartup(
      loadCooldownInfo: _helpers.loadCooldownInfo,
      startConfirmationTimer: _timers.startConfirmationTimer,
      showSnackBar: _helpers.showSnackBar,
    );
  }

  /// Cancel provisional attendance (called when beacon is lost)
  Future<void> _cancelProvisionalAttendance() async {
    if (_state.currentClassId != null) {
      try {
        await _state.httpService.cancelProvisionalAttendance(
          studentId: widget.studentId,
          classId: _state.currentClassId!,
        );
        AppLogger.info('✅ Backend cancelled provisional attendance');
      } catch (e) {
        AppLogger.warning('⚠️ Error cancelling on backend', error: e);
      }
    }
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeScreenState>.value(
      value: _state,
      child: Consumer<HomeScreenState>(
        builder: (context, state, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Welcome, ${widget.studentId}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _helpers.handleLogout(),
                  tooltip: 'Logout',
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                children: [
                  if (state.showBatteryCard) _battery.buildBatteryCard(context),
                  // Single calm banner (no animations) to reduce cognitive load.
                  CalmStatusBanner(state: state, studentId: widget.studentId),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
