import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart'; // ✅ Import for constants

class BeaconStatusWidget extends StatelessWidget {
  final String status;
  final bool isCheckingIn;
  final String studentId;
  final int? remainingSeconds;
  final bool isAwaitingConfirmation;
  final Map<String, dynamic>? cooldownInfo; // 🎯 NEW: Cooldown information
  final String? currentClassId; // 🎯 NEW: Current class ID

  const BeaconStatusWidget({
    super.key,
    required this.status,
    required this.isCheckingIn,
    required this.studentId,
    this.remainingSeconds,
    this.isAwaitingConfirmation = false,
    this.cooldownInfo, // 🎯 NEW: Optional cooldown info
    this.currentClassId, // 🎯 NEW: Optional class ID
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
                                  value: remainingSeconds! / AppConstants.secondCheckDelay.inSeconds, // ✅ Use constant
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
                      // 🔒 FIX: Show badge for both "CONFIRMED" and "Already Checked In"
                      if ((status.contains('CONFIRMED') || status.contains('Already Checked In')) && 
                          !isAwaitingConfirmation) ...[
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
                      
                      // 🎯 ENHANCED: Schedule-Aware Cooldown Information
                      // 🔒 FIX: Only show cooldown card if NOT in cancelled state
                      if (cooldownInfo != null && 
                          cooldownInfo!['inCooldown'] == true && 
                          !status.contains('Cancelled') && 
                          !status.contains('cancelled')) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade50, Colors.blue.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade300, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              // Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule, color: Colors.blue.shade700, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cooldown Active',
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              
                              if (currentClassId != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Class: $currentClassId',
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 12),
                              Divider(color: Colors.blue.shade300, height: 1),
                              const SizedBox(height: 12),
                              
                              // 🎓 Class End Time (Schedule-aware)
                              if (cooldownInfo!.containsKey('classEndTimeFormatted') && 
                                  cooldownInfo!['classEnded'] == false) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.access_time, color: Colors.blue.shade600, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Class ends at ',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      cooldownInfo!['classEndTimeFormatted'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                if (cooldownInfo!.containsKey('classTimeLeftFormatted')) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '(${cooldownInfo!['classTimeLeftFormatted']})',
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                              ],
                              
                              // 🔒 FIX: Removed "Next check-in available" - not needed
                              // User can attend class normally, no need for another check-in
                              
                              // Schedule message (if available)
                              if (cooldownInfo!.containsKey('message') && 
                                  cooldownInfo!['message'] != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cooldownInfo!['message'],
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      
                      // 🎯 ENHANCED: Schedule-Aware Cancelled Badge
                      if (status.contains('Cancelled') || status.contains('cancelled')) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.shade50, Colors.red.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              // Header with icon
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cancel, color: Colors.red.shade700, size: 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Attendance Cancelled',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              
                              // 🎓 Enhanced: Show class schedule info if available in cooldownInfo
                              if (cooldownInfo != null) ...[
                                const SizedBox(height: 12),
                                Divider(color: Colors.red.shade300, height: 1),
                                const SizedBox(height: 12),
                                
                                // Current class end time
                                if (cooldownInfo!.containsKey('classEndTimeFormatted') &&
                                    cooldownInfo!.containsKey('classEnded') &&
                                    cooldownInfo!['classEnded'] == false) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.access_time, color: Colors.red.shade600, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Current class ends at ',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        cooldownInfo!['classEndTimeFormatted'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (cooldownInfo!.containsKey('classTimeLeftFormatted')) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '(${cooldownInfo!['classTimeLeftFormatted']})',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],
                                
                                // Next class time
                                if (cooldownInfo!.containsKey('nextClassTimeFormatted')) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Try again in next class:',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.class_, color: Colors.red.shade800, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              cooldownInfo!['nextClassTimeFormatted'],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (cooldownInfo!.containsKey('timeUntilNextFormatted')) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '(${cooldownInfo!['timeUntilNextFormatted']})',
                                            style: TextStyle(
                                              color: Colors.red.shade600,
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                                
                                // Full message (if available)
                                if (cooldownInfo!.containsKey('message') &&
                                    cooldownInfo!['message'] != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    cooldownInfo!['message'],
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ] else ...[
                                // Fallback if no schedule info available
                                const SizedBox(height: 8),
                                Text(
                                  'Please try again in the next class',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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