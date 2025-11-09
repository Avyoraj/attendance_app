/// Centralized environment configuration for build-time flags.
///
/// Usage:
/// - Pass `--dart-define=API_URL=https://prod.example.com/api` at build/run time.
/// - If not provided, defaults to the current production API base.
class Environment {
  /// Full API base URL including trailing `/api` segment.
  /// Example: https://your-backend.example.com/api
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://attendance-backend-omega.vercel.app/api',
  );
}
