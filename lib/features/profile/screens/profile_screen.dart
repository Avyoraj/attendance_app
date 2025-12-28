import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/profile_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/http_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../models/user_profile.dart';
import '../widgets/profile_stats_card.dart';

/// Material 3 Profile Screen
/// Follows Material 3 design principles with proper card layout,
/// user information display, and action buttons
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;
  bool _isProfileLocked = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get actual studentId from storage
      final storage = await StorageService.getInstance();
      final studentId = await storage.getStudentId();
      
      if (studentId == null || studentId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'No student is currently logged in.';
          _isLoading = false;
        });
        return;
      }

      // Fetch profile and check if locked
      final response = await HttpService().get(
        url: '${ApiConstants.apiBase}/students/$studentId/profile',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = await ProfileService().getUserProfile(studentId);
        
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _isProfileLocked = data['isProfileComplete'] == true;
          _isLoading = false;
        });
      } else {
        final profile = await ProfileService().getUserProfile(studentId);
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _isProfileLocked = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return _buildLoadingState(colorScheme);
    }

    if (_error != null) {
      return _buildErrorState(colorScheme);
    }

    if (_profile == null) {
      return _buildEmptyState(colorScheme);
    }

    return _buildProfileContent(colorScheme);
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An error occurred while loading your profile',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.person_outline,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No profile found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load your profile information.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: CustomScrollView(
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildProfileHeader(colorScheme),
            ),
          ),

          // Stats Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProfileStatsCard(
                totalDays: _profile!.totalClasses,
                presentDays: _profile!.confirmedClasses,
                absentDays: _profile!.totalClasses - _profile!.confirmedClasses,
                streak: _profile!.attendancePercentage,
              ),
            ),
          ),

          // Action Buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildActionButtons(colorScheme),
            ),
          ),

          // Additional Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAdditionalInfo(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: colorScheme.outline,
                  width: 2,
                ),
              ),
              child: _profile!.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(38),
                      child: Image.network(
                        _profile!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 40,
                            color: colorScheme.onPrimaryContainer,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              _profile!.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Student ID
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Student ID: ${_profile!.studentId}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        // Profile locked indicator
        if (_isProfileLocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profile is locked. Contact your teacher to make changes.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Settings Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate to settings tab
              DefaultTabController.of(context).animateTo(3);
            },
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo(ColorScheme colorScheme) {
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
                  'Profile Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Additional profile fields
            _buildInfoRow(
                'Email', _profile!.email ?? 'Not provided', Icons.email),
            _buildInfoRow(
                'Phone', _profile!.phone ?? 'Not provided', Icons.phone),
            _buildInfoRow('Department', _profile!.department ?? 'Not provided',
                Icons.business),
            _buildInfoRow(
                'Year', _profile!.year ?? 'Not provided', Icons.calendar_today),
            _buildInfoRow(
                'Section', _profile!.section ?? 'Not provided', Icons.group),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.onSurfaceVariant,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
