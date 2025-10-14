import 'dart:ui';
import 'package:flutter/material.dart';

class BeaconStatusWidget extends StatelessWidget {
  final String status;
  final bool isCheckingIn;
  final String studentId;
  final int? remainingSeconds;
  final bool isAwaitingConfirmation;

  const BeaconStatusWidget({
    super.key,
    required this.status,
    required this.isCheckingIn,
    required this.studentId,
    this.remainingSeconds,
    this.isAwaitingConfirmation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Icon
              _buildStatusIcon(),
              const SizedBox(height: 24),
              
              // Main Status Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        'Attendance Status',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Divider
                      Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      
                      // Status Message
                      Text(
                        status,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      // Loading Indicator
                      if (isCheckingIn) ...[
                        const SizedBox(height: 20),
                        const LinearProgressIndicator(),
                      ],
                      
                      // Timer Countdown (if confirming)
                      if (isAwaitingConfirmation && remainingSeconds != null && remainingSeconds! > 0) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timer_outlined, color: Colors.orange.shade700, size: 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    _formatTime(remainingSeconds!),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                      fontFeatures: [const FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Confirming attendance...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: remainingSeconds! / 30.0,
                                  minHeight: 6,
                                  backgroundColor: Colors.orange.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Confirmed Badge
                      if (status.contains('CONFIRMED') && !isAwaitingConfirmation) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Attendance Confirmed',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Student Info Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student ID',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            studentId,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Keep Bluetooth enabled and stay within beacon range',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    // Show loading spinner when checking in
    if (isCheckingIn) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          shape: BoxShape.circle,
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
        ),
      );
    }

    // Determine icon and color based on status
    IconData icon;
    Color color;

    if (status.contains('CONFIRMED')) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (status.contains('Check-in recorded') || status.contains('recorded')) {
      icon = Icons.pending;
      color = Colors.orange;
    } else if (status.contains('failed') || status.contains('Error') || status.contains('Device Locked')) {
      icon = Icons.error;
      color = Colors.red;
    } else if (status.contains('Scanning')) {
      icon = Icons.bluetooth_searching;
      color = Colors.blue;
    } else if (status.contains('Move closer')) {
      icon = Icons.my_location;
      color = Colors.amber;
    } else {
      icon = Icons.bluetooth;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 64,
        color: color,
      ),
    );
  }
  
  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}