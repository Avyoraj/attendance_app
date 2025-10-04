import 'package:flutter/material.dart';

class BeaconStatusWidget extends StatelessWidget {
  final String status;
  final bool isCheckingIn;
  final String studentId;

  const BeaconStatusWidget({
    super.key,
    required this.status,
    required this.isCheckingIn,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status Icon
          _buildStatusIcon(),
          const SizedBox(height: 24),
          
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Attendance Status',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    status,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  if (isCheckingIn) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Student Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Text(
                    'Student ID: $studentId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.info, color: Colors.blue.shade600),
                const SizedBox(height: 8),
                Text(
                  'Make sure Bluetooth is enabled and you are within range of the classroom beacon.',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (isCheckingIn) {
      return const CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
      );
    }

    if (status.contains('successful')) {
      return const Icon(
        Icons.check_circle,
        size: 64,
        color: Colors.green,
      );
    } else if (status.contains('failed') || status.contains('Error')) {
      return const Icon(
        Icons.error,
        size: 64,
        color: Colors.red,
      );
    } else if (status.contains('Provisional')) {
      return const Icon(
        Icons.hourglass_top,
        size: 64,
        color: Colors.orange,
      );
    } else if (status.contains('Analyzing signal')) {
      return const Icon(
        Icons.analytics,
        size: 64,
        color: Colors.blue,
      );
    } else if (status.contains('detected') && status.contains('Checking in')) {
      return const Icon(
        Icons.bluetooth_connected,
        size: 64,
        color: Colors.orange,
      );
    } else if (status.contains('Scanning')) {
      return const Icon(
        Icons.bluetooth_searching,
        size: 64,
        color: Colors.blue,
      );
    } else {
      return const Icon(
        Icons.bluetooth,
        size: 64,
        color: Colors.grey,
      );
    }
  }
}