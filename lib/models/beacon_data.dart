class BeaconData {
  final String identifier;
  final String proximityUUID;
  final int major;
  final int minor;
  final int rssi;
  final double accuracy;
  final String proximity; // 'immediate', 'near', 'far', 'unknown'

  const BeaconData({
    required this.identifier,
    required this.proximityUUID,
    required this.major,
    required this.minor,
    required this.rssi,
    required this.accuracy,
    required this.proximity,
  });

  factory BeaconData.fromFlutterBeacon(dynamic beacon) {
    return BeaconData(
      identifier: beacon.proximityUUID ?? '',
      proximityUUID: beacon.proximityUUID ?? '',
      major: beacon.major ?? 0,
      minor: beacon.minor ?? 0,
      rssi: beacon.rssi ?? -100,
      accuracy: beacon.accuracy ?? 0.0,
      proximity: beacon.proximity?.toString().split('.').last ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'proximityUUID': proximityUUID,
      'major': major,
      'minor': minor,
      'rssi': rssi,
      'accuracy': accuracy,
      'proximity': proximity,
    };
  }

  String get classId => minor.toString();

  bool get isInRange => rssi > -90; // You can adjust this threshold

  @override
  String toString() {
    return 'BeaconData{proximityUUID: $proximityUUID, major: $major, minor: $minor, rssi: $rssi, proximity: $proximity}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeaconData &&
        other.proximityUUID == proximityUUID &&
        other.major == major &&
        other.minor == minor;
  }

  @override
  int get hashCode => Object.hash(proximityUUID, major, minor);
}
