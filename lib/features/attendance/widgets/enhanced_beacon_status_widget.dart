import 'package:flutter/material.dart';
import 'package:attendance_app/features/attendance/screens/home_screen/home_screen_state.dart';

/// Material 3 Beacon Status Widget
/// Follows Material 3 design principles with proper elevation,
/// color tokens, and component styling
class Material3BeaconStatusWidget extends StatefulWidget {
  final String statusMessage;
  final BeaconStatusType statusType;
  final bool isCheckingIn;
  final String studentId;
  final int? remainingSeconds;
  final bool isAwaitingConfirmation;
  final Map<String, dynamic>? cooldownInfo;
  final String? currentClassId;

  const Material3BeaconStatusWidget({
    super.key,
    required this.statusMessage,
    required this.statusType,
    required this.isCheckingIn,
    required this.studentId,
    this.remainingSeconds,
    this.isAwaitingConfirmation = false,
    this.cooldownInfo,
    this.currentClassId,
  });

  @override
  State<Material3BeaconStatusWidget> createState() =>
      _Material3BeaconStatusWidgetState();
}

class _Material3BeaconStatusWidgetState
    extends State<Material3BeaconStatusWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();

    if (widget.isCheckingIn || widget.isAwaitingConfirmation) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Material3BeaconStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCheckingIn || widget.isAwaitingConfirmation) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Material 3 Status Icon
                _buildMaterial3StatusIcon(colorScheme),
                const SizedBox(height: 32),

                // Material 3 Status Card
                _buildMaterial3StatusCard(colorScheme),
                const SizedBox(height: 24),

                // Material 3 Student Info Card
                _buildMaterial3StudentCard(colorScheme),
                const SizedBox(height: 24),

                // Material 3 Instructions Card
                _buildMaterial3InstructionsCard(colorScheme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterial3StatusIcon(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(colorScheme),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(colorScheme).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              _getStatusIcon(),
              size: 60,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaterial3StatusCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status Title
            Text(
              _getStatusTitle(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _getStatusColor(colorScheme),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Primary status message from state
            Text(
              widget.statusMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),

            // Optional supporting description
            if (_getStatusSupportText() != null) ...[
              const SizedBox(height: 12),
              Text(
                _getStatusSupportText()!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),

            // Timer or Additional Info
            if (widget.remainingSeconds != null && widget.remainingSeconds! > 0)
              _buildMaterial3TimerWidget(colorScheme),

            if (widget.cooldownInfo != null)
              _buildMaterial3CooldownWidget(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterial3StudentCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.person,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student ID',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.studentId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterial3InstructionsCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getInstructionsText(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterial3TimerWidget(ColorScheme colorScheme) {
    final formatted = _formatDuration(widget.remainingSeconds!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: colorScheme.onSecondaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Confirmation window: $formatted',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterial3CooldownWidget(ColorScheme colorScheme) {
    final cooldownInfo = widget.cooldownInfo!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Cooldown: ${cooldownInfo['remainingTime'] ?? 'Active'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // Helper methods for status-based styling
  Color _getStatusColor(ColorScheme colorScheme) {
    switch (widget.statusType) {
      case BeaconStatusType.scanning:
        return colorScheme.primary;
      case BeaconStatusType.provisional:
        return colorScheme.tertiary;
      case BeaconStatusType.confirming:
        return colorScheme.secondary;
      case BeaconStatusType.confirmed:
      case BeaconStatusType.success:
        return colorScheme.primary;
      case BeaconStatusType.cancelled:
      case BeaconStatusType.failed:
      case BeaconStatusType.deviceLocked:
        return colorScheme.error;
      case BeaconStatusType.cooldown:
        return colorScheme.outline;
      case BeaconStatusType.info:
        return colorScheme.primary;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.statusType) {
      case BeaconStatusType.scanning:
        return Icons.radar;
      case BeaconStatusType.provisional:
        return Icons.hourglass_bottom;
      case BeaconStatusType.confirming:
        return Icons.task_alt;
      case BeaconStatusType.confirmed:
      case BeaconStatusType.success:
        return Icons.check_circle;
      case BeaconStatusType.cancelled:
        return Icons.cancel_outlined;
      case BeaconStatusType.failed:
        return Icons.error_outline;
      case BeaconStatusType.cooldown:
        return Icons.schedule;
      case BeaconStatusType.deviceLocked:
        return Icons.lock_outline;
      case BeaconStatusType.info:
        return Icons.bluetooth_searching;
    }
  }

  String _getStatusTitle() {
    switch (widget.statusType) {
      case BeaconStatusType.scanning:
        return 'Scanning for Beacons';
      case BeaconStatusType.provisional:
        return 'Stay Nearby to Confirm';
      case BeaconStatusType.confirming:
        return 'Finalizing Your Check-in';
      case BeaconStatusType.confirmed:
        return 'Attendance Confirmed';
      case BeaconStatusType.success:
        return 'Attendance Recorded';
      case BeaconStatusType.cancelled:
        return 'Attendance Cancelled';
      case BeaconStatusType.failed:
        return 'Check-in Failed';
      case BeaconStatusType.cooldown:
        return 'Already Checked In';
      case BeaconStatusType.deviceLocked:
        return 'Device Locked';
      case BeaconStatusType.info:
        return 'Attendance Status';
    }
  }

  String? _getStatusSupportText() {
    switch (widget.statusType) {
      case BeaconStatusType.scanning:
        return 'Keep Bluetooth on and stay near your classroom beacon.';
      case BeaconStatusType.provisional:
        return 'You are in a provisional window. Remaining near the beacon confirms attendance automatically.';
      case BeaconStatusType.confirming:
        return 'We are double-checking your final signal strength before recording attendance.';
      case BeaconStatusType.confirmed:
        return 'Feel free to continue with your class. You can revisit the app anytime.';
      case BeaconStatusType.success:
        return 'Attendance has been logged successfully.';
      case BeaconStatusType.cancelled:
        return 'You can retry once you are back in range of the classroom beacon.';
      case BeaconStatusType.failed:
        return 'Move closer to the classroom beacon and try again.';
      case BeaconStatusType.cooldown:
        return 'The next automatic check-in becomes available once the cooldown completes.';
      case BeaconStatusType.deviceLocked:
        return 'If this is unexpected, contact your administrator to relink your device.';
      case BeaconStatusType.info:
        return null;
    }
  }

  String _getInstructionsText() {
    switch (widget.statusType) {
      case BeaconStatusType.provisional:
        return 'Stay within the classroom for the duration of the countdown so we can finalize your attendance.';
      case BeaconStatusType.confirming:
        return 'Hold on for a moment—your presence is being verified before the timer ends.';
      case BeaconStatusType.confirmed:
      case BeaconStatusType.success:
        return 'You are marked present. If you leave early, the cooldown ensures duplicate check-ins are prevented.';
      case BeaconStatusType.cancelled:
      case BeaconStatusType.failed:
        return 'Head back near the classroom beacon and the app will attempt the check-in again automatically.';
      case BeaconStatusType.cooldown:
        return 'Relax—you are already checked in. We will let you know when the next attendance window opens.';
      case BeaconStatusType.deviceLocked:
        return 'This account is linked to another device. Please reach out to support if this is a mistake.';
      case BeaconStatusType.scanning:
        return 'Keep Bluetooth enabled and hold your device near the classroom entry. We will start the check-in once the beacon is detected.';
      case BeaconStatusType.info:
        return 'Keep your phone with you and ensure Bluetooth stays on for uninterrupted attendance tracking.';
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }
}
