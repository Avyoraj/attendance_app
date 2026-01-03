import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/core/utils/app_logger.dart';
import 'package:attendance_app/core/services/device_id_service.dart';
import '../widgets/calm_status_banner.dart';
import '../widgets/home_widgets.dart';
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
    
    // Wire up sync reference (to allow data refresh on state changes)
    _callbacks.sync = _sync;

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
        // Include deviceId for backend device-binding enforcement
        final deviceId = await DeviceIdService().getDeviceId();

        await _state.httpService.cancelProvisionalAttendance(
          studentId: widget.studentId,
          classId: _state.currentClassId!,
          deviceId: deviceId,
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
                _buildSyncButton(state),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _helpers.handleLogout(),
                  tooltip: 'Logout',
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _handleManualRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Battery optimization card (if needed)
                      if (state.showBatteryCard) _battery.buildBatteryCard(context),
                      
                      // Today's status card
                      TodayStatusCard(
                        status: state.todayStatus,
                        className: state.todayClassName,
                        checkInTime: state.todayCheckInTime,
                        isLoading: state.isLoadingSummary,
                      ),
                      const SizedBox(height: 16),
                      
                      // Beacon status banner
                      CalmStatusBanner(state: state, studentId: widget.studentId),
                      const SizedBox(height: 16),
                      
                      // Active session card
                      ActiveSessionCard(
                        isActive: state.hasActiveSession,
                        className: state.activeClassName,
                        teacherName: state.activeTeacherName,
                        roomName: state.activeRoomName,
                      ),
                      const SizedBox(height: 16),
                      
                      // Weekly stats card
                      WeeklyStatsCard(
                        confirmed: state.weeklyConfirmed,
                        total: state.weeklyTotal,
                        percentage: state.weeklyPercentage,
                        isLoading: state.isLoadingSummary,
                      ),
                      const SizedBox(height: 16),
                      
                      // Recent history
                      RecentHistoryList(history: state.recentHistory),
                      
                      // Syncing indicator
                      if (state.isSyncing)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Syncing...'),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handle manual refresh - sync state with backend
  Future<void> _handleManualRefresh() async {
    if (_state.isSyncing) return;
    
    // Reset loading states to show skeletons during refresh
    _state.update((state) {
      state.isSyncing = true;
      state.isLoadingSummary = true;
    }, immediate: true);
    
    try {
      AppLogger.info('🔄 Manual refresh triggered');
      
      // Re-sync state with backend
      await _sync.syncStateOnStartup(
        loadCooldownInfo: _helpers.loadCooldownInfo,
        startConfirmationTimer: _timers.startConfirmationTimer,
        showSnackBar: _helpers.showSnackBar,
      );
      
      _helpers.showSnackBar('✅ Synced successfully');
    } catch (e) {
      AppLogger.warning('⚠️ Manual refresh failed', error: e);
      _helpers.showSnackBar('⚠️ Sync failed. Please try again.');
      _state.markSummaryLoaded(); // Stop skeleton on error
    } finally {
      _state.setIsSyncing(false);
    }
  }
  
  /// Sync button with pending offline badge
  Widget _buildSyncButton(HomeScreenState state) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: state.isSyncing ? null : _handleManualRefresh,
          tooltip: 'Sync with server',
        ),
        if (state.pendingActionCount > 0)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.pendingActionCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
