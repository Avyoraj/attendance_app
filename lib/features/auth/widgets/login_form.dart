import 'package:flutter/material.dart';

/// Material 3 Login Form
/// Follows Material 3 design principles with proper form styling,
/// color tokens, and component design
class LoginForm extends StatefulWidget {
  final Function(String) onLogin;
  final bool isLoading;

  const LoginForm({
    super.key,
    required this.onLogin,
    required this.isLoading,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _studentIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onLogin(_studentIdController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Material 3 Welcome Card
              _buildWelcomeCard(colorScheme),
              const SizedBox(height: 32),

              // Material 3 Login Form Card
              _buildLoginFormCard(colorScheme),
              const SizedBox(height: 24),

              // Material 3 Login Button
              _buildLoginButton(colorScheme),
              const SizedBox(height: 16),

              // Material 3 Help Text
              _buildHelpText(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // App Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.school,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),

            // Welcome Text
            Text(
              'Welcome to Attendance App',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              'Frictionless attendance tracking with beacon technology',
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

  Widget _buildLoginFormCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Title
            Row(
              children: [
                Icon(
                  Icons.login,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Student Login',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Student ID Input
            TextFormField(
              controller: _studentIdController,
              enabled: !widget.isLoading,
              decoration: InputDecoration(
                labelText: 'Student ID',
                hintText: 'Enter your student ID',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _studentIdController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          _studentIdController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your Student ID';
                }
                if (value.trim().length < 3) {
                  return 'Student ID must be at least 3 characters';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleSubmit(),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(ColorScheme colorScheme) {
    return FilledButton(
      onPressed: widget.isLoading ? null : _handleSubmit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
      child: widget.isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.onPrimary,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.login,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
    );
  }

  Widget _buildHelpText(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: colorScheme.onSurfaceVariant,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Make sure you\'re connected to the school network',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
