import 'package:flutter/material.dart';
import '../../../core/services/http_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

/// One-time profile setup screen for new students
/// Shows after first login when profile is incomplete
class ProfileSetupScreen extends StatefulWidget {
  final String studentId;
  final VoidCallback onComplete;

  const ProfileSetupScreen({
    super.key,
    required this.studentId,
    required this.onComplete,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  
  String _selectedYear = '1';
  String _selectedSection = 'A';
  bool _isLoading = false;
  String? _error;

  final List<String> _years = ['1', '2', '3', '4'];
  final List<String> _sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await HttpService().post(
        url: '${ApiConstants.apiBase}/students/${widget.studentId}/profile',
        body: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().isEmpty 
              ? null 
              : _emailController.text.trim(),
          'year': _selectedYear,
          'section': _selectedSection,
          'department': _departmentController.text.trim().isEmpty 
              ? null 
              : _departmentController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        // Save profile completion status locally
        final storage = await StorageService.getInstance();
        await storage.setBool('profile_complete', true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onComplete();
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['message'] ?? data['error'] ?? 'Failed to save profile';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      Icons.person_add,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Center(
                  child: Text(
                    'Complete Your Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                Center(
                  child: Text(
                    'Student ID: ${widget.studentId}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '⚠️ This can only be set once',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Error message
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Name field (required)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email field (optional)
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (Optional)',
                    hintText: 'your.email@example.com',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Year and Section row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          prefixIcon: Icon(Icons.school),
                          border: OutlineInputBorder(),
                        ),
                        items: _years.map((year) => DropdownMenuItem(
                          value: year,
                          child: Text('Year $year'),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          prefixIcon: Icon(Icons.group),
                          border: OutlineInputBorder(),
                        ),
                        items: _sections.map((section) => DropdownMenuItem(
                          value: section,
                          child: Text('Section $section'),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSection = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Department field (optional)
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department (Optional)',
                    hintText: 'e.g., Computer Science',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Info text
                Center(
                  child: Text(
                    'Your profile information helps teachers identify you.\nContact your teacher if you need to make changes later.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
