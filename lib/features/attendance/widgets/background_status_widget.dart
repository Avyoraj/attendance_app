import 'package:flutter/material.dart';
import '../../../core/services/simple_notification_service.dart';

class BackgroundStatusWidget extends StatefulWidget {
  const BackgroundStatusWidget({super.key});

  @override
  State<BackgroundStatusWidget> createState() => _BackgroundStatusWidgetState();
}

class _BackgroundStatusWidgetState extends State<BackgroundStatusWidget> {
  bool _isTracking = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isTracking ? Icons.notifications_active : Icons.notifications_off,
                  color: _isTracking ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Background Tracking',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _isTracking,
                  onChanged: _toggleTracking,
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isTracking 
                ? '✅ Active • Monitoring beacon distance in background'
                : '⏸️ Inactive • Enable for hands-free attendance',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (_isTracking) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Check your notification panel for distance updates',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleTracking(bool value) async {
    setState(() {
      _isTracking = value;
    });

    if (value) {
      await SimpleNotificationService.startBackgroundTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔍 Background tracking started • Check notifications'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      await SimpleNotificationService.stopBackgroundTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏸️ Background tracking stopped'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}