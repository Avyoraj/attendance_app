# 🎓 Frictionless Attendance App

A truly frictionless attendance tracking system using BLE beacons and ESP32. Works automatically in the background - just like WhatsApp!

## ✨ Features

### 🔄 **Background Attendance Logging**
- Works even when app is closed or phone is locked
- Automatic detection using ESP32 BLE beacons
- Periodic scanning every 15 minutes
- No manual interaction required

### 📵 **Offline Support**
- Saves attendance locally when internet unavailable
- Automatic sync when connection restores
- Queue system for pending records
- Smart retry mechanism

### 🔔 **Smart Alerts**
- Sound notifications for Bluetooth/Internet issues
- Visual notifications with clear messages
- Success confirmations
- Alert cooldown to avoid spam

### 📝 **Professional Logging**
- Color-coded console output
- Different log levels (debug, info, warning, error)
- Stack traces for debugging
- Emoji indicators for easy scanning

### 🔐 **Privacy & Security**
- Local-first architecture
- Encrypted data transmission
- Minimal data collection
- Clear data retention policy

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (^3.5.3)
- Android Studio / Xcode
- ESP32 with BLE capability
- Backend API (Vercel deployment)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Avyoraj/attendance_app.git
   cd attendance_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure ESP32 Beacon:**
   - Upload BLE beacon code to ESP32
   - Set UUID: `215d0698-0b3d-34a6-a844-5ce2b2447f1a`
   - Set Major: Class number (e.g., 101 for CS101)
   - Set Minor: Section number

4. **Run the app:**
   ```bash
   flutter run
   ```

## 📱 Usage

### For Students:

1. **First Time Setup:**
   - Open app and login with Student ID
   - Grant Bluetooth and Location permissions
   - Enable "Background Tracking" in Settings
   - Done! The app will now work automatically

2. **Daily Use:**
   - Just carry your phone
   - Attendance logged automatically when near classroom beacon
   - Receive notifications confirming attendance
   - No need to open the app!

### For Administrators:

- View attendance logs on backend dashboard
- Export reports
- Monitor system status
- Manage beacon configurations

## 🏗️ Architecture

```
lib/
├── main.dart                   # App entry point
├── app/                        # App configuration
├── core/                       # Core services
│   ├── services/
│   │   ├── background_attendance_service.dart
│   │   ├── beacon_service.dart
│   │   ├── connectivity_service.dart
│   │   ├── local_database_service.dart
│   │   ├── sync_service.dart
│   │   ├── alert_service.dart
│   │   └── logger_service.dart
│   ├── constants/
│   └── utils/
├── features/                   # Feature modules
│   ├── auth/
│   ├── attendance/
│   ├── history/
│   ├── profile/
│   └── settings/
└── models/                     # Data models
```

## 🔧 Configuration

### API Endpoint
Update in `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'https://your-backend.vercel.app';
```

### Beacon Settings
Update in `lib/core/constants/app_constants.dart`:
```dart
static const String proximityUUID = 'YOUR-UUID-HERE';
static const int rssiThreshold = -75;  // Adjust detection range
```

## 📊 Technical Details

### Dependencies

- **workmanager** - Background task execution
- **connectivity_plus** - Network monitoring
- **sqflite** - Local database for offline storage
- **logger** - Professional logging system
- **audioplayers** - Alert sounds
- **flutter_beacon** - BLE beacon detection
- **provider** - State management

### Platforms

- ✅ Android 8.0+ (API 26+)
- ✅ iOS 13.0+

### Permissions

**Android:**
- Bluetooth
- Location (Fine & Coarse)
- Foreground Service
- Internet

**iOS:**
- Bluetooth (Always)
- Location (Always & When In Use)
- Background Modes

## 🧪 Testing

### Run Tests:
```bash
flutter test
```

### Build Release:
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

### Test Background Service:
1. Install on real device
2. Enable background tracking
3. Close app completely
4. Lock phone
5. Wait 15+ minutes near beacon
6. Check if attendance was logged

## 📚 Documentation

- [Frictionless Features Guide](FRICTIONLESS_FEATURES.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)
- [Refactoring Summary](REFACTORING_SUMMARY.md)

## 🐛 Troubleshooting

### Background service not working?
- Disable battery optimization for the app
- Check all permissions are granted
- Verify "Background Tracking" is enabled in settings

### Beacon not detected?
- Ensure ESP32 is broadcasting
- Verify UUID matches exactly
- Check Bluetooth is enabled
- Move closer to beacon

### Offline sync not working?
- Check internet connection
- Verify backend URL is correct
- Check local database for pending records

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Harsh (Avyoraj)**
- GitHub: [@Avyoraj](https://github.com/Avyoraj)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- ESP32 community for BLE beacon tutorials
- Open source contributors

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Check documentation files
- Review troubleshooting guide

---

**Made with ❤️ for frictionless attendance tracking**
