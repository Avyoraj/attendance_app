import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart'; // Import the new package

// --- APP INITIALIZATION ---
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthCheck(),
    );
  }
}

// --- AUTHENTICATION CHECKER WIDGET ---
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  Future<String?> _getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('student_id');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getStudentId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData && snapshot.data != null) {
          return HomePage(studentId: snapshot.data!);
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// --- LOGIN PAGE WIDGET ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _studentIdController = TextEditingController();

  Future<void> _login() async {
    if (_studentIdController.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_id', _studentIdController.text);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage(studentId: _studentIdController.text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _studentIdController,
              decoration: const InputDecoration(
                labelText: 'Enter Your Student ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HOME PAGE WIDGET (Handles Permissions and Beacon Scanning) ---
class HomePage extends StatefulWidget {
  final String studentId;
  const HomePage({super.key, required this.studentId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<RangingResult>? _streamRanging;
  String _beaconStatus = 'Initializing...';
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _initializeBeaconScanner();
  }

  // --- NEW PERMISSION REQUEST FUNCTION ---
  Future<void> _requestPermissions() async {
    // Request multiple permissions at once
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // You can check individual statuses if needed
    print('Location status: ${statuses[Permission.location]}');
    print('Bluetooth Scan status: ${statuses[Permission.bluetoothScan]}');
  }

  Future<void> _initializeBeaconScanner() async {
    // Call the new permission request function first
    await _requestPermissions();

    try {
      await flutterBeacon.initializeAndCheckScanning;

      final regions = <Region>[
        Region(
          identifier: 'MySchool',
          proximityUUID: '215d0698-0b3d-34a6-a844-5ce2b2447f1a',
        ),
      ];

      _streamRanging =
          flutterBeacon.ranging(regions).listen((RangingResult result) {
        if (!mounted) return;

        if (result.beacons.isNotEmpty) {
          final beacon = result.beacons.first;
          final classId = beacon.minor.toString();

          if (beacon.proximity == Proximity.near ||
              beacon.proximity == Proximity.immediate) {
            setState(() {
              _beaconStatus = 'Classroom ${beacon.minor} detected! Checking in...';
            });
            _checkIn(widget.studentId, classId);
          } else {
            setState(() {
              _beaconStatus = 'Classroom ${beacon.minor} detected, but you are too far away.';
            });
          }
        } else {
          setState(() {
            _beaconStatus = 'Scanning for classroom beacon...';
          });
        }
      }, onError: (e) {
        print("ERROR from ranging stream: $e");
      });
    } catch (e) {
      print("FATAL ERROR initializing beacon scanner: $e");
      setState(() {
        _beaconStatus = 'Error: Beacon scanner failed to start.';
      });
    }
  }

  Future<void> _checkIn(String studentId, String classId) async {
    if (_isCheckingIn) return;
    
    setState(() { _isCheckingIn = true; });

    try {
      final url = Uri.parse('https://attendance-backend-omega.vercel.app/api/check-in');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'studentId': studentId, 'classId': classId}),
      );

      if (response.statusCode == 201) {
        setState(() {
          _beaconStatus = 'Check-in successful for Class $classId!';
        });
        _streamRanging?.pause();
      } else {
         setState(() {
          _beaconStatus = 'Check-in failed. Server responded.';
        });
      }
    } catch (e) {
      print("Error during check-in: $e");
      setState(() {
        _beaconStatus = 'Check-in failed. Cannot reach server.';
      });
    } finally {
      Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() { _isCheckingIn = false; });
      });
    }
  }
  
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_id');
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    _streamRanging?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.studentId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          )
        ],
      ),
      body: Center(
        child: Text(
          _beaconStatus,
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}