import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';

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
      // The AuthCheck widget will show the correct page based on login status
      home: const AuthCheck(),
    );
  }
}

// --- AUTHENTICATION CHECKER WIDGET ---
// This widget checks if a student ID is saved on the device.
// If it is, it shows the HomePage. If not, it shows the LoginPage.
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
          // Show a loading circle while checking for saved data
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData && snapshot.data != null) {
          // If a student ID is found, go to the HomePage
          return HomePage(studentId: snapshot.data!);
        } else {
          // Otherwise, show the LoginPage
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

  // Saves the student ID and navigates to the HomePage
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

// --- HOME PAGE WIDGET (Handles Beacon Scanning) ---
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
    // Start the beacon scanner as soon as the page loads
    _initializeBeaconScanner();
  }

  // This function sets up and starts the beacon scanning
  Future<void> _initializeBeaconScanner() async {
    try {
      // Check permissions and initialize the scanner
      await flutterBeacon.initializeAndCheckScanning;

      // Define the region to scan for (must match your ESP32's UUID)
      final regions = <Region>[
        Region(
          identifier: 'MySchool',
          proximityUUID: '215d0698-0b3d-34a6-a844-5ce2b2447f1a',
        ),
      ];

      // Start listening for beacons
      _streamRanging =
          flutterBeacon.ranging(regions).listen((RangingResult result) {
        if (!mounted) return; // Check if the widget is still on screen

        if (result.beacons.isNotEmpty) {
          final beacon = result.beacons.first;
          final classId = beacon.minor.toString();

          // Check if the beacon is close enough
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
          // Update status if no beacons are found
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

  // Sends the check-in data to your backend server
  Future<void> _checkIn(String studentId, String classId) async {
    // Prevents sending multiple requests at once
    if (_isCheckingIn) return;
    
    setState(() { _isCheckingIn = true; });

    try {
      // IMPORTANT: Use your computer's local IP address here
     // final url = Uri.parse('http://192.168.1.114:3000/api/check-in'); // Old
      final url = Uri.parse('https://attendance-backend-omega.vercel.app/api/check-in'); // New

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'studentId': studentId, 'classId': classId}),
      );

      if (response.statusCode == 201) {
        setState(() {
          _beaconStatus = 'Check-in successful for Class $classId!';
        });
        // Stop scanning after a successful check-in to save battery
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
      // Allow for another check-in attempt after 30 seconds
      Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() { _isCheckingIn = false; });
      });
    }
  }
  
  // Clears student ID and returns to the LoginPage
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_id');
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // Clean up the beacon stream when the widget is removed
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