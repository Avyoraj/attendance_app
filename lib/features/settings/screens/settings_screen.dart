import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';

/// Material 3 Settings Screen
/// Follows Material 3 design principles with proper list design,
/// switches, and section organization
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final settings = settingsProvider.settings;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: CustomScrollView(
        slivers: [
          // Auto-Attendance Info Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildAutoAttendanceCard(context, colorScheme),
            ),
          ),

          // Appearance Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionHeader(context, 'Appearance', colorScheme),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAppearanceSettings(context, settingsProvider, colorScheme),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Notifications Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionHeader(context, 'Notifications', colorScheme),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildNotificationSettings(context, settingsProvider, colorScheme),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // About Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionHeader(context, 'About', colorScheme),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAboutSettings(context, colorScheme),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAutoAttendanceCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.radar,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Attendance',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Background tracking enabled',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your attendance is automatically logged when you\'re near a classroom beacon. This feature runs continuously in the background.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAppearanceSettings(BuildContext context, SettingsProvider settingsProvider, ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          _buildSwitchTile(
            context: context,
            title: 'Dark Mode',
            subtitle: 'Switch between light and dark themes',
            icon: Icons.dark_mode_outlined,
            value: settingsProvider.settings.darkMode,
            onChanged: (value) => settingsProvider.toggleDarkMode(value),
            colorScheme: colorScheme,
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            context: context,
            title: 'System Theme',
            subtitle: 'Follow system theme settings',
            icon: Icons.settings_brightness_outlined,
            value: settingsProvider.settings.systemTheme,
            onChanged: (value) => settingsProvider.toggleSystemTheme(value),
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings(BuildContext context, SettingsProvider settingsProvider, ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          _buildSwitchTile(
            context: context,
            title: 'Notifications',
            subtitle: 'Show attendance and alert notifications',
            icon: Icons.notifications_outlined,
            value: settingsProvider.settings.notificationEnabled,
            onChanged: (value) => settingsProvider.toggleNotificationEnabled(value),
            colorScheme: colorScheme,
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            context: context,
            title: 'Sound Notifications',
            subtitle: 'Play sounds for notifications',
            icon: Icons.volume_up_outlined,
            value: settingsProvider.settings.soundEnabled,
            onChanged: (value) => settingsProvider.toggleSoundEnabled(value),
            colorScheme: colorScheme,
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            context: context,
            title: 'Vibration',
            subtitle: 'Vibrate for notifications',
            icon: Icons.vibration,
            value: settingsProvider.settings.vibrationEnabled,
            onChanged: (value) => settingsProvider.toggleVibrationEnabled(value),
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSettings(BuildContext context, ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          _buildListTile(
            context: context,
            title: 'App Version',
            subtitle: '1.0.0',
            icon: Icons.info_outline,
            onTap: () {},
            colorScheme: colorScheme,
          ),
          const Divider(height: 1),
          _buildListTile(
            context: context,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            icon: Icons.privacy_tip_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon!')),
              );
            },
            colorScheme: colorScheme,
          ),
          const Divider(height: 1),
          _buildListTile(
            context: context,
            title: 'Terms of Service',
            subtitle: 'View terms and conditions',
            icon: Icons.description_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of service coming soon!')),
              );
            },
            colorScheme: colorScheme,
          ),
          const Divider(height: 1),
          _buildListTile(
            context: context,
            title: 'Contact Support',
            subtitle: 'Get help and support',
            icon: Icons.support_agent_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support contact coming soon!')),
              );
            },
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colorScheme,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

