import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 🔄 Circular Confirmation Timer Widget
///
/// Displays a circular progress indicator that fills up over the confirmation period.
/// Provides visual feedback to students about their attendance confirmation progress.
///
/// Features:
/// - Animated circular progress ring
/// - Countdown timer display
/// - Status text
/// - Pulsing animation when near completion
class CircularConfirmationTimer extends StatefulWidget {
  /// Total duration for confirmation (e.g., 180 seconds)
  final int totalSeconds;

  /// Remaining seconds until confirmation
  final int remainingSeconds;

  /// Whether the timer is active
  final bool isActive;

  /// Size of the widget
  final double size;

  /// Color scheme for the progress ring
  final Color? progressColor;
  final Color? backgroundColor;
  final Color? textColor;

  /// Optional callback when timer completes
  final VoidCallback? onComplete;

  const CircularConfirmationTimer({
    super.key,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isActive = true,
    this.size = 120,
    this.progressColor,
    this.backgroundColor,
    this.textColor,
    this.onComplete,
  });

  @override
  State<CircularConfirmationTimer> createState() =>
      _CircularConfirmationTimerState();
}

class _CircularConfirmationTimerState extends State<CircularConfirmationTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for when timer is near completion
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updatePulseState();
  }

  @override
  void didUpdateWidget(CircularConfirmationTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePulseState();
  }

  void _updatePulseState() {
    // Start pulsing when less than 30 seconds remaining
    if (widget.isActive && widget.remainingSeconds <= 30 && widget.remainingSeconds > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressColor = widget.progressColor ?? colorScheme.primary;
    final backgroundColor =
        widget.backgroundColor ?? colorScheme.surfaceContainerHighest;
    final textColor = widget.textColor ?? colorScheme.onSurface;

    // Calculate progress (0.0 to 1.0)
    final elapsed = widget.totalSeconds - widget.remainingSeconds;
    final progress = widget.totalSeconds > 0
        ? (elapsed / widget.totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    // Format time display
    final minutes = widget.remainingSeconds ~/ 60;
    final seconds = widget.remainingSeconds % 60;
    final timeDisplay = '${minutes}:${seconds.toString().padLeft(2, '0')}';

    // Determine status text
    String statusText;
    Color statusColor;
    if (!widget.isActive) {
      statusText = 'Waiting...';
      statusColor = colorScheme.outline;
    } else if (widget.remainingSeconds <= 0) {
      statusText = 'Confirming...';
      statusColor = colorScheme.tertiary;
    } else if (widget.remainingSeconds <= 30) {
      statusText = 'Almost there!';
      statusColor = colorScheme.tertiary;
    } else if (widget.remainingSeconds <= 60) {
      statusText = 'Stay in class';
      statusColor = progressColor;
    } else {
      statusText = 'Stay in class';
      statusColor = progressColor;
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.isActive && widget.remainingSeconds <= 30
            ? _pulseAnimation.value
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: backgroundColor,
                    valueColor: AlwaysStoppedAnimation(backgroundColor),
                  ),
                ),

                // Progress ring
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, animatedProgress, child) {
                      return CustomPaint(
                        painter: _CircularProgressPainter(
                          progress: animatedProgress,
                          progressColor: progressColor,
                          strokeWidth: 8,
                        ),
                      );
                    },
                  ),
                ),

                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer display
                    Text(
                      timeDisplay,
                      style: TextStyle(
                        fontSize: widget.size * 0.22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Status text
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: widget.size * 0.1,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the circular progress ring
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Create gradient for progress ring
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [
        progressColor.withOpacity(0.3),
        progressColor,
      ],
      stops: const [0.0, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw arc
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      paint,
    );

    // Draw end cap dot when progress > 0
    if (progress > 0.01) {
      final endAngle = -math.pi / 2 + sweepAngle;
      final endX = center.dx + radius * math.cos(endAngle);
      final endY = center.dy + radius * math.sin(endAngle);

      final dotPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(endX, endY), strokeWidth / 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}

/// Compact version for inline display (e.g., in status cards)
class CompactConfirmationTimer extends StatelessWidget {
  final int totalSeconds;
  final int remainingSeconds;
  final bool isActive;

  const CompactConfirmationTimer({
    super.key,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate progress
    final elapsed = totalSeconds - remainingSeconds;
    final progress =
        totalSeconds > 0 ? (elapsed / totalSeconds).clamp(0.0, 1.0) : 0.0;

    // Format time
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeDisplay = '${minutes}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini circular progress
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time display
          Text(
            timeDisplay,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
