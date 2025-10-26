import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/continuous_beacon_service.dart';
import './home_screen_state.dart';

/// 🔋 HomeScreen Battery Module
/// 
/// Handles battery optimization checks and screen-off scanning setup.
/// Ensures the app can scan for beacons even when screen is off.
/// 
/// Features:
/// - One-time battery optimization check per session
/// - Cached state to avoid repeated checks
/// - Permission request handling
/// - User-dismissible battery card
class HomeScreenBattery {
  final HomeScreenState state;
  final Function(VoidCallback) setStateCallback;
  final Function showSnackBar;
  
  HomeScreenBattery({
    required this.state,
    required this.setStateCallback,
    required this.showSnackBar,
  });
  
  /// Check battery optimization status once per app session
  /// 
  /// Uses cached state to avoid repeated checks. If the card was
  /// dismissed or battery optimization is already disabled, won't show again.
  Future<void> checkBatteryOptimizationOnce() async {
    // If we've already checked once this app session, use cached state
    if (HomeScreenState.hasCheckedBatteryOnce && 
        HomeScreenState.cachedBatteryCardState != null) {
      setStateCallback(() {
        state.showBatteryCard = HomeScreenState.cachedBatteryCardState!;
      });
      return;
    }
    
    // Prevent multiple simultaneous checks
    if (state.isCheckingBatteryOptimization) return;
    state.isCheckingBatteryOptimization = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user has dismissed the card permanently
      final hasCardBeenDismissed = prefs.getBool('battery_card_dismissed') ?? false;
      if (hasCardBeenDismissed) {
        HomeScreenState.cachedBatteryCardState = false;
        HomeScreenState.hasCheckedBatteryOnce = true;
        setStateCallback(() {
          state.showBatteryCard = false;
        });
        return;
      }
      
      // Check actual battery optimization status
      final continuousService = ContinuousBeaconService();
      final isIgnoring = await continuousService.checkBatteryOptimization();
      
      HomeScreenState.cachedBatteryCardState = !isIgnoring;
      HomeScreenState.hasCheckedBatteryOnce = true;
      
      setStateCallback(() {
        state.isBatteryOptimizationDisabled = isIgnoring;
        state.showBatteryCard = !isIgnoring; // Only show if not already disabled
      });
      
      // If already disabled, remember that so we don't show card again
      if (isIgnoring) {
        await prefs.setBool('battery_card_dismissed', true);
      }
    } finally {
      state.isCheckingBatteryOptimization = false;
    }
  }
  
  /// Request to disable battery optimization for screen-off scanning
  /// 
  /// Opens system settings and polls for up to 10 seconds to check if enabled.
  Future<void> enableScreenOffScanning() async {
    final continuousService = ContinuousBeaconService();
    await continuousService.requestDisableBatteryOptimization();
    
    // Keep checking every 500ms for up to 10 seconds until enabled
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final isIgnoring = await continuousService.checkBatteryOptimization();
      
      if (isIgnoring) {
        // Successfully enabled!
        // Save to preferences so card doesn't show again
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('battery_card_dismissed', true);
        HomeScreenState.cachedBatteryCardState = false;
        
        setStateCallback(() {
          state.isBatteryOptimizationDisabled = true;
          state.showBatteryCard = false;
        });
        
        showSnackBar('✅ Screen-off scanning enabled!');
        return;
      }
    }
    
    // If we reach here, user may have denied or dismissed the dialog
    // Just leave the card visible so they can try again later
  }
  
  /// Dismiss the battery optimization card permanently
  Future<void> dismissBatteryCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('battery_card_dismissed', true);
    HomeScreenState.cachedBatteryCardState = false;
    
    setStateCallback(() {
      state.showBatteryCard = false;
    });
    
    state.logger.info('🔋 Battery card dismissed by user');
  }
  
  /// Check if battery optimization is currently disabled
  Future<bool> isBatteryOptimizationDisabled() async {
    final continuousService = ContinuousBeaconService();
    return await continuousService.checkBatteryOptimization();
  }
  
  /// Build the battery optimization card widget
  Widget buildBatteryCard(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enable Screen-Off Scanning',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => dismissBatteryCard(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Allow the app to scan for beacons even when your screen is completely off. This helps log attendance automatically.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => enableScreenOffScanning(),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Enable Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
