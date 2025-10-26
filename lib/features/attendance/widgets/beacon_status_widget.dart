import 'package:flutter/material.dart';
import 'beacon_status/beacon_status_icon.dart';
import 'beacon_status/beacon_status_main_card.dart';
import 'beacon_status/beacon_status_student_card.dart';
import 'beacon_status/beacon_status_instructions.dart';

/// Main BeaconStatusWidget - Refactored with modular architecture
/// Orchestrates all status display modules
/// 
/// Reduced from 594 lines to ~100 lines by delegating to specialized modules:
/// - beacon_status_icon.dart: Status icon with 8+ states
/// - beacon_status_main_card.dart: Main card orchestrator
/// - beacon_status_timer.dart: Countdown timer (via main_card)
/// - beacon_status_badges.dart: Confirmed/cancelled badges (via main_card)
/// - beacon_status_cooldown.dart: Schedule-aware cooldown (via main_card)
/// - beacon_status_student_card.dart: Student ID card
/// - beacon_status_instructions.dart: Bluetooth instructions
/// - beacon_status_helpers.dart: Utility functions
class BeaconStatusWidget extends StatelessWidget {
  final String status;
  final bool isCheckingIn;
  final String studentId;
  final int? remainingSeconds;
  final bool isAwaitingConfirmation;
  final Map<String, dynamic>? cooldownInfo;
  final String? currentClassId;

  const BeaconStatusWidget({
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
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Icon
              BeaconStatusIcon(
                status: status,
                isCheckingIn: isCheckingIn,
              ),
              const SizedBox(height: 24),

              // Main Status Card (orchestrates timer, badges, cooldown)
              BeaconStatusMainCard(
                status: status,
                isCheckingIn: isCheckingIn,
                remainingSeconds: remainingSeconds,
                isAwaitingConfirmation: isAwaitingConfirmation,
                cooldownInfo: cooldownInfo,
                currentClassId: currentClassId,
              ),
              const SizedBox(height: 20),

              // Student Info Card
              BeaconStatusStudentCard(studentId: studentId),
              const SizedBox(height: 20),

              // Instructions
              const BeaconStatusInstructions(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
