import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Service to track and update user's location to Firebase in real-time
class UserLocationTracker {
  static final UserLocationTracker _instance = UserLocationTracker._internal();
  factory UserLocationTracker() => _instance;
  UserLocationTracker._internal();

  StreamSubscription<Position>? _locationSubscription;
  Timer? _batterySyncTimer;
  bool _isTracking = false;
  final Battery _battery = Battery();
  static const int _lowBatteryThreshold = 15;
  static const int _criticalBatteryThreshold = 5;
  DateTime? _lastCriticalBatterySosAt;

  /// Start tracking user location and update to Firebase
  Future<void> startTracking() async {
    if (_isTracking) {
      print('📍 Location tracking already active');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No authenticated user for location tracking');
      return;
    }

    try {
      // Check location permissions
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location service is disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied forever');
        return;
      }

      // Start position stream
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) async {
              await _updateLocationToFirebase(position);
            },
            onError: (error) {
              print('❌ Location stream error: $error');
            },
          );

      _isTracking = true;
      await _syncBatteryAndCriticalSos();
      _batterySyncTimer?.cancel();
      _batterySyncTimer = Timer.periodic(const Duration(seconds: 30), (
        _,
      ) async {
        await _syncBatteryAndCriticalSos();
      });
      print('✅ User location tracking started for UID: ${user.uid}');
    } catch (e) {
      print('❌ Error starting location tracking: $e');
    }
  }

  Future<int?> _readBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level < 0 || level > 100) return null;
      return level;
    } catch (e) {
      print('⚠️ Unable to read battery level: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _buildDeviceStatusData() async {
    final batteryLevel = await _readBatteryLevel();
    if (batteryLevel == null) return null;

    return {
      'batteryLevel': batteryLevel,
      'isLowBattery': batteryLevel <= _lowBatteryThreshold,
      'lowBatteryThreshold': _lowBatteryThreshold,
      'isCriticalBattery': batteryLevel <= _criticalBatteryThreshold,
      'criticalBatteryThreshold': _criticalBatteryThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update location to Firestore
  Future<void> _updateLocationToFirebase(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final deviceStatus = await _buildDeviceStatusData();
    final updatePayload = {
      'currentLocation': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'lastSeen': FieldValue.serverTimestamp(),
      if (deviceStatus != null) 'deviceStatus': deviceStatus,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updatePayload);

      print('📍 Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error updating location to Firebase: $e');

      // If document doesn't exist, create it with location
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(updatePayload, SetOptions(merge: true));
      } catch (e2) {
        print('❌ Error creating location document: $e2');
      }
    }
  }

  Future<void> _updateBatteryOnlyToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final deviceStatus = await _buildDeviceStatusData();
    if (deviceStatus == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'deviceStatus': deviceStatus,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error syncing battery status: $e');
    }
  }

  Future<void> _syncBatteryAndCriticalSos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batteryLevel = await _readBatteryLevel();
    if (batteryLevel == null) return;

    final deviceStatus = {
      'batteryLevel': batteryLevel,
      'isLowBattery': batteryLevel <= _lowBatteryThreshold,
      'lowBatteryThreshold': _lowBatteryThreshold,
      'isCriticalBattery': batteryLevel <= _criticalBatteryThreshold,
      'criticalBatteryThreshold': _criticalBatteryThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'deviceStatus': deviceStatus,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error syncing battery status: $e');
      return;
    }

    if (batteryLevel <= _criticalBatteryThreshold) {
      await _sendCriticalBatterySos(user.uid, batteryLevel);
    }
  }

  Future<void> _sendCriticalBatterySos(String uid, int batteryLevel) async {
    final now = DateTime.now();
    final isRateLimited =
        _lastCriticalBatterySosAt != null &&
        now.difference(_lastCriticalBatterySosAt!) <
            const Duration(minutes: 10);
    if (isRateLimited) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final existingSos = userDoc.data()?['sosAlert'] as Map<String, dynamic>?;
      final hasActiveSos = existingSos?['active'] == true;
      final currentLocation =
          userDoc.data()?['currentLocation'] as Map<String, dynamic>?;
      final lat = currentLocation?['latitude'];
      final lng = currentLocation?['longitude'];

      Map<String, dynamic>? lastKnownLocation;
      if (lat is num && lng is num) {
        lastKnownLocation = {
          'latitude': lat.toDouble(),
          'longitude': lng.toDouble(),
        };
      }

      // Keep current active SOS if it already exists (e.g., fall alert).
      if (hasActiveSos) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'sosAlert': {
          'active': true,
          'type': 'battery_critical',
          'message':
              'Battery is critically low ($batteryLevel%). Device may shut down soon.',
          'acknowledged': false,
          'batteryLevel': batteryLevel,
          if (lastKnownLocation != null) 'lastKnownLocation': lastKnownLocation,
          'clientTriggeredAt': now.toIso8601String(),
          'triggeredAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      _lastCriticalBatterySosAt = now;
    } catch (e) {
      print('❌ Error sending critical battery SOS: $e');
    }
  }

  /// Stop tracking user location
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _batterySyncTimer?.cancel();
    _batterySyncTimer = null;
    _isTracking = false;
    print('🛑 User location tracking stopped');
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Update single location without streaming (for initial setup)
  Future<void> updateCurrentLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _updateLocationToFirebase(position);
      await _syncBatteryAndCriticalSos();
    } catch (e) {
      print('❌ Error updating single location: $e');
    }
  }
}
