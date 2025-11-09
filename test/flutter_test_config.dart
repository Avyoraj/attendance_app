import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This file runs before any tests and sets up a mock environment for
// SharedPreferences so plugin channels aren't required during unit tests.
Future<void> _globalTestSetup() async {
  // Ensure the test binding is initialized for widget-related services.
  TestWidgetsFlutterBinding.ensureInitialized();
  // Provide an in-memory store for SharedPreferences to avoid MissingPluginException.
  SharedPreferences.setMockInitialValues(<String, Object>{});
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await _globalTestSetup();
  await testMain();
}
