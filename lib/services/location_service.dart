import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Location permission check aur request karo
  static Future<bool> requestLocationPermission() async {
    try {
      print('🔐 Requesting location permission...');

      // پہلے check کریں کہ permission پہلے سے ہے یا نہیں
      PermissionStatus status = await Permission.location.status;
      print('📍 Current permission status: $status');

      if (!status.isGranted) {
        // اگر نہیں ہے تو request کریں
        status = await Permission.location.request();
        print('📍 Permission request result: $status');
      }

      return status.isGranted;
    } catch (e) {
      print('❌ Permission error: $e');
      return false;
    }
  }

  // Current location fetch karo
  static Future<Position?> getCurrentLocation() async {
    try {
      print('🔍 Fetching location...');

      // پہلے location service enable ہے یا نہیں check کریں
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location service disabled');
        // User کو enable کرنے کے لیے کہیں
        await Geolocator.openLocationSettings();
        return null;
      }

      // Permission request کریں
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('❌ Location permission denied');
        return null;
      }

      // اب position fetch کریں
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('✅ Location fetched: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }
}
