import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigateUserScreen extends StatefulWidget {
  const NavigateUserScreen({super.key});

  @override
  State<NavigateUserScreen> createState() => _NavigateUserScreenState();
}

class _NavigateUserScreenState extends State<NavigateUserScreen> {
  static const Color darkBlue = Color(0xFF1B2E58);
  static const Color brandYellow = Color(0xFFFFBF55);

  GoogleMapController? _mapController;
  LatLng? _userLocation;
  LatLng? _guardianLocation;
  StreamSubscription<DocumentSnapshot>? _userLocationSubscription;
  StreamSubscription<Position>? _guardianPositionSubscription;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  double _distanceInMeters = 0.0;
  String _estimatedTime = '';
  bool _isLoading = true;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _userLocationSubscription?.cancel();
    _guardianPositionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      // Get guardian's current location
      await _getGuardianLocation();

      // Start listening to user's location from Firebase
      await _listenToUserLocation();
    } catch (e) {
      print('❌ Error initializing tracking: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getGuardianLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _guardianLocation = LatLng(position.latitude, position.longitude);
      });

      // Track guardian's real-time position
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _guardianPositionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((position) {
            setState(() {
              _guardianLocation = LatLng(position.latitude, position.longitude);
            });
            _updateMarkersAndDistance();
          });

      print('✅ Guardian location tracking started');
    } catch (e) {
      print('❌ Error getting guardian location: $e');
    }
  }

  Future<void> _listenToUserLocation() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user');
        return;
      }

      // Get guardian's email
      final guardianDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!guardianDoc.exists) {
        print('❌ Guardian document not found');
        setState(() => _isLoading = false);
        return;
      }

      final guardianEmail = guardianDoc.data()?['email'] as String?;
      if (guardianEmail == null) {
        print('❌ Guardian email not found');
        setState(() => _isLoading = false);
        return;
      }

      // Find user who has linked this guardian's email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('guardianEmail', isEqualTo: guardianEmail)
          .where('isLinked', isEqualTo: true)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('❌ No linked user found');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No linked user found')));
        }
        return;
      }

      final userDoc = userQuery.docs.first;
      final linkedUserId = userDoc.id;

      setState(() {
        _userName = userDoc.data()['fullName'] ?? 'User';
      });

      print('✅ Found linked user: $_userName (ID: $linkedUserId)');

      // Listen to user's location updates
      _userLocationSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(linkedUserId)
          .snapshots()
          .listen((snapshot) {
            if (!snapshot.exists) return;

            final data = snapshot.data();
            final locationData =
                data?['currentLocation'] as Map<String, dynamic>?;

            if (locationData != null) {
              final lat = locationData['latitude'] as double?;
              final lng = locationData['longitude'] as double?;

              if (lat != null && lng != null) {
                setState(() {
                  _userLocation = LatLng(lat, lng);
                  _isLoading = false;
                });
                _updateMarkersAndDistance();
                _animateCameraToFitBoth();
              }
            }
          });

      print('✅ Listening to user location');
    } catch (e) {
      print('❌ Error listening to user location: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateMarkersAndDistance() {
    if (_userLocation == null || _guardianLocation == null) return;

    // Update markers
    _markers.clear();

    _markers.add(
      Marker(
        markerId: const MarkerId('user'),
        position: _userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: _userName),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('guardian'),
        position: _guardianLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'You (Guardian)'),
      ),
    );

    // Calculate distance
    final distance = Geolocator.distanceBetween(
      _guardianLocation!.latitude,
      _guardianLocation!.longitude,
      _userLocation!.latitude,
      _userLocation!.longitude,
    );

    setState(() {
      _distanceInMeters = distance;
      // Estimate time (assuming average walking speed of 5 km/h)
      final hours = (distance / 1000) / 5;
      final minutes = (hours * 60).round();
      _estimatedTime = minutes > 60
          ? '${(minutes / 60).toStringAsFixed(1)} hrs'
          : '$minutes mins';
    });

    // Draw polyline
    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('guardian_to_user'),
        color: darkBlue,
        width: 4,
        points: [_guardianLocation!, _userLocation!],
      ),
    );

    setState(() {});
  }

  void _animateCameraToFitBoth() {
    if (_mapController == null ||
        _userLocation == null ||
        _guardianLocation == null) {
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        _userLocation!.latitude < _guardianLocation!.latitude
            ? _userLocation!.latitude
            : _guardianLocation!.latitude,
        _userLocation!.longitude < _guardianLocation!.longitude
            ? _userLocation!.longitude
            : _guardianLocation!.longitude,
      ),
      northeast: LatLng(
        _userLocation!.latitude > _guardianLocation!.latitude
            ? _userLocation!.latitude
            : _guardianLocation!.latitude,
        _userLocation!.longitude > _guardianLocation!.longitude
            ? _userLocation!.longitude
            : _guardianLocation!.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _openInGoogleMaps() async {
    if (_userLocation == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_userLocation!.latitude},${_userLocation!.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkBlue,
        title: Text(
          "TRACK USER",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userLocation == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'User location not available',
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waiting for user to share location...',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userLocation ?? const LatLng(31.5204, 74.3587),
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _animateCameraToFitBoth();
                  },
                ),

                // Distance Info Overlay
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_walk,
                          color: darkBlue,
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Distance from $_userName",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _distanceInMeters >= 1000
                                    ? '${(_distanceInMeters / 1000).toStringAsFixed(1)} km ($_estimatedTime away)'
                                    : '${_distanceInMeters.toStringAsFixed(0)} m ($_estimatedTime away)',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Button
                Positioned(
                  bottom: 30,
                  left: 30,
                  right: 30,
                  child: ElevatedButton.icon(
                    onPressed: _openInGoogleMaps,
                    icon: const Icon(Icons.navigation, color: Colors.black),
                    label: const Text("START NAVIGATION"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
