import 'package:flutter/material.dart';

/// Material 3 Beacon Status Widget
/// Follows Material 3 design principles with proper elevation,
/// color tokens, and component styling
class Material3BeaconStatusWidget extends StatefulWidget {
  final String status;
  final bool isCheckingIn;
  final String studentId;
  final int? remainingSeconds;
  final bool isAwaitingConfirmation;
  final Map<String, dynamic>? cooldownInfo;
  final String? currentClassId;

  const Material3BeaconStatusWidget({
    super.key,
    required this.status,
    required this.isCheckingIn,
    required this.studentId,
    this.remainingSeconds,
    this.isAwaitingConfirmation = false,
    this.cooldownInfo,
    this.currentClassId,
  });

  @override
  State<Material3BeaconStatusWidget> createState() => _Material3BeaconStatusWidgetState();
}

class _Material3BeaconStatusWidgetState extends State<Material3BeaconStatusWidget>
    with TickerProviderStateMixin {
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

            // Status Description
            Text(
              _getStatusDescription(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.remainingSeconds}s remaining',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
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
    switch (widget.status.toLowerCase()) {
      case 'scanning':
        return colorScheme.primary;
      case 'provisional_check_in':
        return colorScheme.tertiary;
      case 'confirming':
        return colorScheme.secondary;
      case 'confirmed':
      case 'attendance_success':
        return colorScheme.primary;
      case 'cancelled':
      case 'check_in_failed':
        return colorScheme.error;
      case 'cooldown':
        return colorScheme.outline;
      case 'device_locked':
        return colorScheme.error;
      default:
        return colorScheme.primary;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status.toLowerCase()) {
      case 'scanning':
        return Icons.radar;
      case 'provisional_check_in':
        return Icons.hourglass_empty;
      case 'confirming':
        return Icons.timer;
      case 'confirmed':
      case 'attendance_success':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'check_in_failed':
        return Icons.error;
      case 'cooldown':
        return Icons.schedule;
      case 'device_locked':
        return Icons.lock;
      default:
        return Icons.bluetooth_searching;
    }
  }

  String _getStatusTitle() {
    switch (widget.status.toLowerCase()) {
      case 'scanning':
        return 'Scanning for Beacons';
      case 'provisional_check_in':
        return 'Check-in Initiated';
      case 'confirming':
        return 'Confirming Attendance';
      case 'confirmed':
        return 'Attendance Confirmed';
      case 'attendance_success':
        return 'Success!';
      case 'cancelled':
        return 'Check-in Cancelled';
      case 'check_in_failed':
        return 'Check-in Failed';
      case 'cooldown':
        return 'Cooldown Active';
      case 'device_locked':
        return 'Device Locked';
      default:
        return widget.status;
    }
  }

  String _getStatusDescription() {
    switch (widget.status.toLowerCase()) {
      case 'scanning':
        return 'Looking for nearby classroom beacons...';
      case 'provisional_check_in':
        return 'Please stay in the classroom for confirmation';
      case 'confirming':
        return 'Verifying your presence in the classroom';
      case 'confirmed':
        return 'Your attendance has been successfully recorded';
      case 'attendance_success':
        return 'Great! You\'re all set for today';
      case 'cancelled':
        return 'Check-in was cancelled. You may try again';
      case 'check_in_failed':
        return 'Unable to complete check-in. Please try again';
      case 'cooldown':
        return 'You\'ve already checked in for this class';
      case 'device_locked':
        return 'This device is registered to another student';
      default:
        return 'Please wait...';
    }
  }

  String _getInstructionsText() {
    if (widget.isCheckingIn || widget.isAwaitingConfirmation) {
      return 'Please keep your phone with you and stay in the classroom until attendance is confirmed.';
    } else if (widget.status.toLowerCase() == 'scanning') {
      return 'Make sure Bluetooth is enabled and you\'re near a classroom beacon. The app will automatically detect your presence.';
    } else if (widget.status.toLowerCase() == 'cooldown') {
      return 'You\'ve already checked in for this class. The cooldown will reset when the class ends or for the next scheduled class.';
    } else {
      return 'Keep your phone with you and ensure Bluetooth is enabled for automatic attendance tracking.';
    }
  }
}
