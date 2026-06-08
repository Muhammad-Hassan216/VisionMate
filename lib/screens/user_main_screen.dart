import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' show asin, atan, cos, sqrt, sin, tan, pi;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/object_detector.dart';
import '../services/offline_recognition_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/location_service.dart';
import '../services/user_location_tracker.dart';
import 'login_screen.dart';
import 'profile_info_screen.dart';
import 'favourite_destinations_screen.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  static const Color darkBlue = Color(0xFF1B2E58);
  static const Color brandYellow = Color(0xFFFFBF55);

  static const double _cameraVerticalFovDeg = 50.0;
  static const Set<String> _hardStopLabels = {'car', 'bus', 'truck'};
  static const Map<String, double> _referenceObjectWidthsMeters = {
    'car': 1.85,
    'bus': 2.50,
    'truck': 2.50,
    'person': 0.50,
    'bicycle': 0.60,
    'motorcycle': 0.80,
    'chair': 0.50,
    'tv': 0.90,
    'laptop': 0.35,
    'keyboard': 0.45,
    'cell phone': 0.08,
    'book': 0.15,
    'mouse': 0.07,
    'remote': 0.18,
  };
  static const Map<String, double> _referenceObjectHeightsMeters = {
    'person': 1.70,
    'car': 1.45,
    'bus': 3.00,
    'truck': 3.20,
    'bicycle': 1.00,
    'motorcycle': 1.10,
    'chair': 0.90,
    'tv': 0.55,
    'laptop': 0.24,
    'keyboard': 0.05,
    'cell phone': 0.15,
    'book': 0.23,
    'mouse': 0.04,
    'remote': 0.02,
  };
  static const Map<String, double> _distanceScaleByLabel = {
    'laptop': 0.70,
    'keyboard': 0.58,
    'cell phone': 0.55,
    'book': 0.62,
    'mouse': 0.60,
    'remote': 0.60,
    'bed': 0.90,
    'couch': 0.92,
    'dining table': 0.88,
  };

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  Size? _cameraSize; // Camera resolution track karne ke liye

  // Google Maps and navigation route tracking
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(31.5204, 74.3587);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _destinationPosition;
  List<LatLng> _routePoints = [];
  bool _isTrackingRoute = false;

  // Turn-by-turn navigation
  List<NavigationStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  final Set<int> _announcedSteps = {};

  // Object Detection
  final ObjectDetector _detector = ObjectDetector();
  List<Detection> _detections = [];
  bool _isDetecting = false;
  Timer? _detectionTimer; // Store timer reference for pause/resume
  Timer? _focusCheckTimer; // Timer to periodically check if screen is focused
  bool _isDetectionPaused = false; // Track if detection is paused
  bool _isScreenFocused = true; // Track if this screen is in focus

  // Face Recognition (Offline)
  final OfflineRecognitionService _offlineRecognition =
      OfflineRecognitionService();
  final FirebaseToSQLiteSync _syncService = FirebaseToSQLiteSync();
  final UserLocationTracker _locationTracker = UserLocationTracker();
  bool _isFaceServicesReady = false;
  bool _isFaceRecognizing = false;
  String _recognizedPerson = 'No face detected yet';
  double _recognizedSimilarity = 0.0;
  DateTime? _lastRecognitionTime;
  DateTime? _lastSpeechTime;
  String? _lastAnnouncedPerson;
  String? _currentInstruction;
  double _distanceToNextStep = 0.0;

  // Places Search
  final TextEditingController _searchController = TextEditingController();
  final String _placesApiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
  List<PlacePrediction> _searchPredictions = [];
  bool _isSearching = false;

  // Voice Navigation
  late final stt.SpeechToText _speech;
  bool _isVoiceNavActive = false;
  bool _isNavigating = false;
  bool _isSpeechInitialized = false;
  bool _isListeningForDestination = false;
  DateTime? _lastVoiceTriggerAt;
  Timer? _voiceListeningTimeoutTimer;
  bool _isNavigationActive = false; // Track if turn-by-turn is running
  double _lastVolume = 0.5;
  int _volumeButtonPressCount = 0;
  Timer? _volumeButtonTimer;
  DateTime? _lastBackPressedAt;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _fallCountdownTimer;
  DateTime? _lastFreeFallAt;
  DateTime? _lastFallTriggerAt;
  DateTime? _lastSosSentAt;
  bool _isFallPromptActive = false;
  int _fallCountdownSeconds = 0;
  void Function(VoidCallback fn)? _fallDialogSetState;
  int _fallReminderTick = 0;
  bool _isFrontBlockedByObstacle = false;
  final List<String> _safetyAlertQueue = [];
  DateTime? _lastSafetyAlertTime;
  String? _lastSafetyAlertMessage;
  bool _isAnnouncingSafety = false;
  bool _postSafetyResumeVoiceNav = false;
  DateTime? _lastObstacleAlertTime;
  String? _lastObstacleAlertMessage;
  String? _lastObstacleLabel;
  double? _smoothedObstacleDistanceMeters;
  DateTime? _lastPathClearAnnouncementTime;
  int _pathFlatStreak = 0;
  int _wallFlatStreak = 0;

  static const double _freeFallThreshold = 2.8;
  static const double _impactThreshold = 24.0;
  static const int _fallPromptSeconds = 10;

  // Text-to-Speech
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeApp();
    _initializeVoiceNavigation();
    // Start continuous focus checking (every 300ms)
    _startFocusChecking();
  }

  Future<bool> _onWillPop() async {
    try {
      await _tts.stop();
      await _tts.speak(
        'Do you want to exit the app? Say yes to confirm or no to stay here.',
      );

      final micReady = await _ensureMicrophonePermission();
      if (!micReady) {
        await _tts.speak(
          'Microphone permission is required to listen for yes.',
        );
        return false;
      }

      if (!_isSpeechInitialized) {
        final available = await _speech.initialize(
          onStatus: (status) {
            debugPrint('🎤 Exit STT status: $status');
          },
          onError: (error) {},
          debugLogging: false,
        );
        _isSpeechInitialized = available;
      }

      if (!_isSpeechInitialized) {
        return false;
      }

      String? spoken;
      bool gotFinal = false;
      final speechResult = Completer<String?>();

      _voiceListeningTimeoutTimer?.cancel();
      _voiceListeningTimeoutTimer = Timer(const Duration(seconds: 8), () async {
        if (!gotFinal) {
          try {
            await _speech.stop();
          } catch (_) {}
          if (!speechResult.isCompleted) {
            speechResult.complete(null);
          }
        }
      });

      try {
        await _speech.stop();
        await _speech.listen(
          localeId: 'en_US',
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 2),
          partialResults: false,
          onResult: (result) async {
            if (!result.finalResult) return;
            gotFinal = true;
            spoken = result.recognizedWords.trim().toLowerCase();
            _voiceListeningTimeoutTimer?.cancel();
            if (!speechResult.isCompleted) {
              speechResult.complete(spoken);
            }
            try {
              await _speech.stop();
            } catch (_) {}
          },
        );
      } catch (e) {
        print('❌ STT error on exit confirm: $e');
      }

      final heard = await speechResult.future;
      final text = _normalizeSpeechText(heard ?? spoken ?? '');

      if (_isExitConfirmationAccepted(text)) {
        await _tts.speak('Exiting app. Goodbye.');
        return true;
      }

      if (text.isNotEmpty) {
        await _tts.speak('Exit cancelled.');
      } else {
        await _tts.speak('No response heard. Staying on this screen.');
      }
      return false;
    } catch (e) {
      print('❌ Exit confirmation error: $e');
      return false;
    }
  }

  bool _isExitConfirmationAccepted(String text) {
    return RegExp(r'\b(yes|yep|yeah|haan|han|exit|quit)\b').hasMatch(text);
  }

  String _normalizeSpeechText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Find a favourite by name (case-insensitive substring match).
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findFavoriteByName(
    String query,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favourites')
          .get();

      final q = query.toLowerCase();
      for (var doc in snap.docs) {
        final name = (doc.data()['name'] ?? '').toString().toLowerCase();
        if (name.contains(q) || q.contains(name)) {
          return doc as DocumentSnapshot<Map<String, dynamic>>;
        }
      }
      return null;
    } catch (e) {
      print('❌ _findFavoriteByName error: $e');
      return null;
    }
  }

  /// Save current GPS location as a favourite for the signed-in user.
  Future<void> _saveCurrentLocationAsFavorite() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await _tts.speak('Please sign in to save favourite locations.');
        return;
      }

      // Ensure location permission
      final permission = await Permission.locationWhenInUse.status;
      if (!permission.isGranted) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          await _tts.speak('Location permission is required to save places.');
          return;
        }
      }

      await _tts.speak('Saving your current location');
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final name =
          'Saved Place ${DateTime.now().toLocal().toString().split('.')[0]}';

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favourites')
          .doc();

      await docRef.set({
        'name': name,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Haptic feedback and announce
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}

      await _tts.speak('Location saved as $name');
      print('✅ Saved favourite $name at ${pos.latitude},${pos.longitude}');

      // Prompt the user to optionally name the place using voice
      await _promptAndSaveName(docRef, pos);
    } catch (e) {
      print('❌ Save favourite error: $e');
      await _tts.speak('Failed to save location');
    }
  }

  Future<void> _promptAndSaveName(
    DocumentReference docRef,
    Position pos,
  ) async {
    const int listenSeconds = 10;
    const int confirmSeconds = 6;
    int attempts = 0;

    while (attempts < 2) {
      attempts++;

      await _tts.speak(
        'Do you want to name this place? Say the name now, say address to use the detected address, or say skip to keep the default.',
      );

      if (!_isSpeechInitialized) {
        final available = await _speech.initialize(
          onStatus: (status) {},
          onError: (error) {},
          debugLogging: false,
        );
        _isSpeechInitialized = available;
      }

      String? spoken;
      bool gotFinal = false;

      _voiceListeningTimeoutTimer?.cancel();
      _voiceListeningTimeoutTimer = Timer(
        Duration(seconds: listenSeconds),
        () async {
          if (!gotFinal) {
            try {
              await _speech.stop();
            } catch (_) {}
          }
        },
      );

      try {
        await _speech.stop();
        await _speech.listen(
          localeId: 'en_US',
          listenFor: Duration(seconds: listenSeconds),
          pauseFor: Duration(seconds: 2),
          partialResults: false,
          onResult: (result) async {
            if (!result.finalResult) return;
            gotFinal = true;
            spoken = result.recognizedWords.trim();
            _voiceListeningTimeoutTimer?.cancel();
            try {
              await _speech.stop();
            } catch (_) {}
          },
        );
      } catch (e) {
        print('❌ STT listen error during naming: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final text = (spoken ?? '').toLowerCase().trim();
      if (text.isEmpty) {
        await _tts.speak('No name detected. Keeping default name.');
        return;
      }

      if (text == 'skip' || text == 'no') {
        await _tts.speak('Keeping default name.');
        return;
      }

      if (text == 'address' || text == 'use address') {
        try {
          final url =
              'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_placesApiKey';
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['results'] != null && json['results'].isNotEmpty) {
              final addr = json['results'][0]['formatted_address'];
              await docRef.update({'name': addr});
              await _tts.speak('Saved with address $addr');
              return;
            }
          }
        } catch (e) {
          print('❌ Reverse geocode error: $e');
        }

        await _tts.speak('Unable to get address. Keeping default name.');
        return;
      }

      await _tts.speak(
        'You said: $spoken. Say yes to confirm or no to try again.',
      );

      String? confirmSpoken;
      bool confirmGot = false;
      _voiceListeningTimeoutTimer?.cancel();
      _voiceListeningTimeoutTimer = Timer(
        Duration(seconds: confirmSeconds),
        () async {
          if (!confirmGot) {
            try {
              await _speech.stop();
            } catch (_) {}
          }
        },
      );

      try {
        await _speech.stop();
        await _speech.listen(
          localeId: 'en_US',
          listenFor: Duration(seconds: confirmSeconds),
          pauseFor: Duration(seconds: 2),
          partialResults: false,
          onResult: (result) async {
            if (!result.finalResult) return;
            confirmGot = true;
            confirmSpoken = result.recognizedWords.trim().toLowerCase();
            _voiceListeningTimeoutTimer?.cancel();
            try {
              await _speech.stop();
            } catch (_) {}
          },
        );
      } catch (e) {
        print('❌ STT confirmation error: $e');
      }

      await Future.delayed(const Duration(milliseconds: 400));

      final conf = (confirmSpoken ?? '').toLowerCase();
      if (conf == 'yes' || conf == 'yeah' || conf == 'yup') {
        try {
          await docRef.update({'name': spoken});
          try {
            HapticFeedback.selectionClick();
          } catch (_) {}
          await _tts.speak('Saved as $spoken');
          return;
        } catch (e) {
          print('❌ Unable to update favourite name: $e');
          await _tts.speak('Failed to save name.');
          return;
        }
      } else {
        await _tts.speak('Okay, let\'s try again.');
        continue;
      }
    }

    await _tts.speak('Keeping default name.');
  }

  Future<void> _initializeApp() async {
    await _loadModel();
    await _initializeFacePipeline();
    await _initializeCamera();
    await _setupTts();
    // Location fetch ko map ready ہونے کے بعد کریں گے
    _startDetection();
    _startFallMonitoring();
    // Start tracking user location to Firebase for guardian
    await _locationTracker.startTracking();
  }

  void _startFallMonitoring() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen(
      _onAccelerometerData,
      onError: (error) {
        debugPrint('⚠️ Accelerometer error: $error');
      },
    );
  }

  void _onAccelerometerData(AccelerometerEvent event) {
    if (_isFallPromptActive) return;

    final now = DateTime.now();
    final magnitude = sqrt(
      (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
    );

    if (magnitude < _freeFallThreshold) {
      _lastFreeFallAt = now;
      return;
    }

    final hadRecentFreeFall =
        _lastFreeFallAt != null &&
        now.difference(_lastFreeFallAt!) <= const Duration(milliseconds: 1200);
    final isImpact = magnitude > _impactThreshold;
    final cooldownPassed =
        _lastFallTriggerAt == null ||
        now.difference(_lastFallTriggerAt!) > const Duration(seconds: 20);

    if (hadRecentFreeFall && isImpact && cooldownPassed) {
      _lastFallTriggerAt = now;
      _triggerFallPrompt();
    }
  }

  Future<void> _triggerFallPrompt() async {
    if (!mounted || _isFallPromptActive) return;

    _isFallPromptActive = true;
    _fallCountdownSeconds = _fallPromptSeconds;
    _fallReminderTick = 0;

    await _tts.stop();
    await _tts.speak(
      'Possible fall detected. Tap anywhere on the screen to confirm safety within $_fallPromptSeconds seconds.',
    );

    _startFallCountdown();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await _dismissFallPrompt(userConfirmedSafe: true);
          },
          child: Material(
            color: Colors.black54,
            child: Center(
              child: StatefulBuilder(
                builder: (context, dialogSetState) {
                  _fallDialogSetState = dialogSetState;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Emergency Safety Check',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Possible fall detected.\nTap anywhere on the screen to confirm you are safe.\n\nSOS in $_fallCountdownSeconds seconds.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    _fallDialogSetState = null;
  }

  void _startFallCountdown() {
    _fallCountdownTimer?.cancel();
    _fallCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!_isFallPromptActive || !mounted) {
        timer.cancel();
        return;
      }

      if (_fallCountdownSeconds > 0) {
        _fallCountdownSeconds -= 1;
        _fallReminderTick += 1;
        _fallDialogSetState?.call(() {});

        if (_fallReminderTick % 3 == 0 && _fallCountdownSeconds > 0) {
          await _tts.stop();
          await _tts.speak(
            'Tap anywhere on the screen to confirm you are safe. $_fallCountdownSeconds seconds left.',
          );
        }
      }

      if (_fallCountdownSeconds <= 0) {
        timer.cancel();
        await _dismissFallPrompt(userConfirmedSafe: false);
        await _sendAutoSosToGuardian();
      }
    });
  }

  Future<void> _dismissFallPrompt({required bool userConfirmedSafe}) async {
    if (!_isFallPromptActive) return;

    _isFallPromptActive = false;
    _fallCountdownTimer?.cancel();
    _fallCountdownTimer = null;
    _fallDialogSetState = null;

    if (mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (userConfirmedSafe) {
      await _tts.stop();
      await _tts.speak('Safety check complete. Stay careful.');
    }
  }

  Future<void> _sendAutoSosToGuardian() async {
    final now = DateTime.now();
    final isRateLimited =
        _lastSosSentAt != null &&
        now.difference(_lastSosSentAt!) < const Duration(seconds: 45);
    if (isRateLimited) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'sosAlert': {
          'active': true,
          'type': 'fall_detected',
          'message':
              'Possible fall detected. User did not respond to safety check.',
          'acknowledged': false,
          'clientTriggeredAt': now.toIso8601String(),
          'triggeredAt': FieldValue.serverTimestamp(),
          'location': {
            'latitude': _currentPosition.latitude,
            'longitude': _currentPosition.longitude,
          },
        },
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lastSosSentAt = now;
      await _tts.stop();
      await _tts.speak('Emergency SOS sent to guardian.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency SOS sent to guardian dashboard'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Auto SOS send failed: $e');
    }
  }

  // Face pipeline init (MobileFaceNet + Firebase -> SQLite cache)
  Future<void> _initializeFacePipeline() async {
    try {
      print('🔄 Initializing face recognition pipeline...');
      await _offlineRecognition.initialize();
      print('🔄 Syncing faces from Firebase...');
      final syncSuccess = await _syncService.syncFacesFromFirebase();
      print('🔄 Sync completed: ${syncSuccess ? "Success" : "Failed"}');

      final status = await _syncService.getSyncStatus();
      _isFaceServicesReady = true;
      print('✅ Face cache ready: ${status['local_faces']} faces');

      if (status['local_faces'] == 0) {
        print('⚠️ No registered faces found! Please register a face first.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No registered faces. Please register your face first.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Face pipeline init error: $e');
    }
  }

  // Model load karo (OFFLINE - assets se)
  Future<void> _loadModel() async {
    try {
      await _detector.loadModel();
      print('✅ Object Detector ready (Offline Mode)');
    } catch (e) {
      print('❌ Model load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Model loading failed. Check assets folder.'),
          ),
        );
      }
    }
  }

  // Camera setup karo
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        print('❌ No camera found');
        return;
      }

      _cameraController = CameraController(
        _cameras![0], // Back camera
        // Lower resolution avoids heavy takePicture I/O and reduces lag.
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Camera size track karo (resolution)
      final videoSize = _cameraController!.value.previewSize;
      if (videoSize != null) {
        _cameraSize = Size(
          videoSize.height.toDouble(),
          videoSize.width.toDouble(),
        ); // Rotation ke liye swapped
        print('📸 Camera Size: $_cameraSize');
      }

      setState(() => _isCameraInitialized = true);
      print('✅ Camera initialized');
    } catch (e) {
      print('❌ Camera error: $e');
    }
  }

  // TTS setup karo
  Future<void> _setupTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  // Initialize Voice Navigation with Hardware Buttons
  Future<void> _initializeVoiceNavigation() async {
    try {
      // Get initial volume
      VolumeController().showSystemUI = false;
      _lastVolume = await VolumeController().getVolume();

      // Initialize speech-to-text plugin with English locale support
      final available = await _speech.initialize(
        onStatus: (status) {
          print('🎤 [STT] Status: $status');
        },
        onError: (error) {
          print('❌ [STT] Error: $error');
        },
        debugLogging: true,
      );

      // Verify English locales are available
      if (available) {
        final locales = await _speech.locales();
        final englishLocales = locales
            .where((locale) => locale.localeId.startsWith('en'))
            .toList();
        print(
          '✅ Available English Locales: ${englishLocales.map((e) => e.localeId).toList()}',
        );
      }

      if (!available) {
        print('⚠️ Speech recognition not available on this device');
      } else {
        _isSpeechInitialized = true;
        print('✅ Speech-to-text initialized successfully');
      }

      // Listen for volume changes (hardware button detection)
      VolumeController().listener((volume) {
        _handleVolumeButtonPress(volume);
      });

      print('✅ Voice navigation initialized');
    } catch (e) {
      print('❌ Voice navigation init error: $e');
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  void _endVoiceListeningSession() {
    if (!mounted) return;
    setState(() {
      _isVoiceNavActive = false;
      _isListeningForDestination = false;
      _isNavigating = false;
    });
  }

  // Detect double/triple volume button press
  void _handleVolumeButtonPress(double newVolume) {
    final volumeChanged = (newVolume - _lastVolume).abs() > 0.01;
    _lastVolume = newVolume;

    if (!volumeChanged) {
      print('📊 Volume listener triggered but no change detected');
      return;
    }

    _volumeButtonPressCount++;
    print(
      '🔊 Volume button press #$_volumeButtonPressCount (volume=$newVolume)',
    );

    // Cancel previous timer
    _volumeButtonTimer?.cancel();

    // Wait for a short timeout to know whether user will press again.
    // On timeout decide action: 2 -> voice search, 3 -> save favorite.
    _volumeButtonTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        if (_volumeButtonPressCount == 2) {
          print('🎤 DETECTED double press -> launching voice navigation');
          await _startVoiceNavigationTrigger();
        } else if (_volumeButtonPressCount >= 3) {
          print(
            '⭐ DETECTED triple press -> saving current location as favorite',
          );
          await _saveCurrentLocationAsFavorite();
        } else {
          print('🔄 Volume press count $_volumeButtonPressCount ignored');
        }
      } catch (e) {
        print('❌ Volume action error: $e');
      } finally {
        _volumeButtonPressCount = 0;
      }
    });
  }

  // Voice navigation: double-press volume then TTS prompt + STT
  Future<void> _startVoiceNavigationTrigger() async {
    final now = DateTime.now();

    // Allow immediate restart if already listening
    if (_isListeningForDestination) {
      print('🔄 Voice already active - restarting session');
      _voiceListeningTimeoutTimer?.cancel();
      await _speech.stop();
      _endVoiceListeningSession();
      // Don't return - proceed to restart below
    } else if (_isNavigating) {
      // If navigating to destination but not listening yet, wait
      print('⏳ Navigation still in progress');
      return;
    } else if (_lastVoiceTriggerAt != null &&
        now.difference(_lastVoiceTriggerAt!) <
            const Duration(milliseconds: 800)) {
      // Only apply cooldown between separate sessions (800ms minimum)
      print(
        '⏳ Voice trigger cooldown active (${now.difference(_lastVoiceTriggerAt!).inMilliseconds}ms)',
      );
      return;
    }

    _lastVoiceTriggerAt = now;

    setState(() {
      _isNavigating = true;
      _isVoiceNavActive = true;
      _isListeningForDestination = false;
    });

    // Pause heavy workloads while listening
    _isDetecting = false;
    _isFaceRecognizing = false;

    try {
      final micAllowed = await _ensureMicrophonePermission();
      if (!micAllowed) {
        await _tts.speak(
          'Microphone permission is required for voice commands.',
        );
        return;
      }

      if (!_isSpeechInitialized) {
        final available = await _speech.initialize(
          onStatus: (status) {
            print('🎤 [STT] Status: $status');
          },
          onError: (error) {
            print('❌ [STT] Error: $error');
          },
          debugLogging: true,
        );
        _isSpeechInitialized = available;
      }

      if (!_isSpeechInitialized) {
        await _tts.speak('Speech recognition is not available on this device.');
        return;
      }

      await _speech.stop();
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);

      await _tts.speak('Where do you want to go?');
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak('Listening now. Please say your destination.');
      await _tts.awaitSpeakCompletion(true);

      print('🎤 [STT] Starting to listen...');
      var gotFinalResult = false;
      setState(() => _isListeningForDestination = true);

      _voiceListeningTimeoutTimer?.cancel();
      _voiceListeningTimeoutTimer = Timer(const Duration(seconds: 12), () async {
        if (!mounted || !_isListeningForDestination) return;
        if (!gotFinalResult) {
          await _speech.stop();
          await _tts.speak(
            'I did not hear a destination. Please double press volume and try again.',
          );
          _endVoiceListeningSession();
        }
      });

      await _speech.listen(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 4),
        partialResults: false,
        cancelOnError: true,
        onSoundLevelChange: (level) {
          print('🎤 [STT] Sound level: $level');
        },
        onResult: (result) async {
          print(
            '🎤 [STT] Result received - isFinal: ${result.finalResult}, words: ${result.recognizedWords}',
          );

          if (!result.finalResult) return;
          gotFinalResult = true;
          _voiceListeningTimeoutTimer?.cancel();

          final destination = result.recognizedWords.trim();
          print('🎤 Heard destination: "$destination"');

          if (destination.isEmpty) {
            await _tts.speak('I did not catch that. Please try again.');
            return;
          }

          await _speech.stop();
          setState(() => _searchController.text = destination);
          _endVoiceListeningSession();
          print('🎯 Voice command received - navigating to: $destination');
          // First check saved favourites for a match
          try {
            final fav = await _findFavoriteByName(destination);
            if (fav != null) {
              final data = fav.data() as Map<String, dynamic>?;
              final lat = (data?['lat'] as num?)?.toDouble();
              final lng = (data?['lng'] as num?)?.toDouble();
              final name = data?['name'] ?? destination;
              if (lat != null && lng != null) {
                print(
                  '📌 Found favourite "$name" at $lat,$lng - routing to favourite',
                );
                await _startRouteTracking(LatLng(lat, lng), name.toString());
                await _tts.speak('Navigating to saved place $name');
              } else {
                print(
                  '⚠️ Favourite found but missing coordinates, falling back to geocoding',
                );
                await _navigateToDestination(destination);
              }
            } else {
              // Not a saved favourite, use geocoding search
              await _navigateToDestination(destination);
            }
          } catch (e) {
            print('❌ Error checking favourites: $e');
            await _navigateToDestination(destination);
          }
          print('🧭 Navigation sequence completed');
        },
      );

      if (!_speech.isListening) {
        print('❌ Unable to start listening');
        await _tts.speak('Unable to start listening. Please try again.');
        _voiceListeningTimeoutTimer?.cancel();
        _endVoiceListeningSession();
      }
    } catch (e) {
      print('❌ Voice navigation error: $e');
      await _tts.speak('Navigation failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          if (!_isListeningForDestination) {
            _isVoiceNavActive = false;
          }
        });
      }
    }
  }

  // Navigate to destination with full announcement
  Future<void> _navigateToDestination(String destination) async {
    if (destination.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      print('📍 Navigating to: $destination');
      // Step 1: Get coordinates from Places API
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(destination)}&key=$_placesApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['results'].isNotEmpty) {
          final result = json['results'][0];
          final location = result['geometry']['location'];
          final placeName = result['formatted_address'];
          final destinationLatLng = LatLng(location['lat'], location['lng']);

          final distance = _calculateDistance(
            _currentPosition.latitude,
            _currentPosition.longitude,
            destinationLatLng.latitude,
            destinationLatLng.longitude,
          );

          print('🗺️ Starting route tracking to $placeName');
          final routed = await _startRouteTracking(
            destinationLatLng,
            placeName,
          );

          if (routed) {
            setState(() => _isNavigationActive = true);
            final announcement =
                'Navigating to $placeName. Distance: ${distance.toStringAsFixed(1)} kilometers.';
            print('🔊 Announcing: $announcement');
            await _tts.speak(announcement);
            print('🎯 Navigation started successfully');
          } else {
            print('❌ Route tracking failed');
          }
        } else {
          print('❌ No results for: $destination');
          await _tts.speak('Destination $destination not found');
        }
      } else {
        print('❌ Geocoding error: ${response.statusCode}');
        await _tts.speak('Search failed');
      }
    } catch (e) {
      print('❌ Navigation error: $e');
      await _tts.speak('Navigation failed');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.14159265359 / 180;
  }

  // Animate camera to show both current and destination
  Future<void> _animateCameraToBounds(LatLng start, LatLng end) async {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        start.latitude < end.latitude ? start.latitude : end.latitude,
        start.longitude < end.longitude ? start.longitude : end.longitude,
      ),
      northeast: LatLng(
        start.latitude > end.latitude ? start.latitude : end.latitude,
        start.longitude > end.longitude ? start.longitude : end.longitude,
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  // Start voice listening for location search
  Future<void> _startVoiceSearch() async {
    await _tts.speak(
      'Voice search feature coming soon. Please type your location instead.',
    );
    print('Voice search not available in this version');
  }

  // Search place using Geocoding API
  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$_placesApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['results'].isNotEmpty) {
          final result = json['results'][0];
          final location = result['geometry']['location'];
          final placeName = result['formatted_address'];

          final newPosition = LatLng(location['lat'], location['lng']);
          final routed = await _startRouteTracking(newPosition, placeName);

          if (routed) {
            await _tts.speak('Navigating to $placeName');
            print('✅ Found & tracking: $placeName at $newPosition');
          }
        } else {
          await _tts.speak('Location not found');
          print('❌ No results found for: $query');
        }
      } else {
        await _tts.speak('Search failed');
        print('❌ Geocoding error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Search error: $e');
      await _tts.speak('Search failed');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // Get autocomplete predictions
  Future<void> _getPlacePredictions(String input) async {
    if (input.isEmpty) {
      setState(() => _searchPredictions = []);
      return;
    }

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&location=${_currentPosition.latitude},${_currentPosition.longitude}&radius=50000&key=$_placesApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List;

        setState(() {
          _searchPredictions = predictions
              .map(
                (p) => PlacePrediction(
                  placeId: p['place_id'] ?? '',
                  description: p['description'] ?? '',
                ),
              )
              .toList();
        });
      }
    } catch (e) {
      print('❌ Autocomplete error: $e');
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    if (prediction.placeId.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final detailsUrl =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=${prediction.placeId}&fields=geometry/location,name,formatted_address&key=$_placesApiKey';

      final response = await http.get(Uri.parse(detailsUrl));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final result = data['result'];
      if (result == null || result['geometry'] == null) return;

      final loc = result['geometry']['location'];
      final dest = LatLng(loc['lat'], loc['lng']);
      final placeName =
          result['name'] ??
          result['formatted_address'] ??
          prediction.description;

      setState(() {
        _searchController.text =
            result['formatted_address'] ?? prediction.description;
        _searchPredictions = [];
      });

      final distance = _calculateDistance(
        _currentPosition.latitude,
        _currentPosition.longitude,
        dest.latitude,
        dest.longitude,
      );

      final routed = await _startRouteTracking(dest, placeName);
      if (routed) {
        await _tts.speak(
          'Navigating to $placeName. Distance ${distance.toStringAsFixed(1)} kilometers.',
        );
      }
    } catch (e) {
      print('❌ Place details error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<Map<String, dynamic>> _fetchRouteData(
    LatLng origin,
    LatLng destination,
  ) async {
    Future<Map<String, dynamic>> fetch(String mode) async {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=$mode&key=$_placesApiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print(
          '❌ Directions $mode HTTP ${response.statusCode}: ${response.body}',
        );
        return {};
      }

      final data = jsonDecode(response.body);
      final status = data['status'];
      final errorMessage = data['error_message'];
      if (status != 'OK') {
        print('❌ Directions $mode failed: $status | $errorMessage');
        return {};
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return {};

      final route = routes.first;
      final overviewPolyline = route['overview_polyline']?['points'];
      if (overviewPolyline is! String || overviewPolyline.isEmpty) return {};

      return {
        'polyline': _decodePolyline(overviewPolyline),
        'steps': _parseNavigationSteps(route),
      };
    }

    // Try walking first, fall back to driving if no route
    final walking = await fetch('walking');
    if (walking.isNotEmpty) return walking;

    final driving = await fetch('driving');
    return driving;
  }

  List<NavigationStep> _parseNavigationSteps(Map<String, dynamic> route) {
    final steps = <NavigationStep>[];
    final legs = route['legs'] as List?;
    if (legs == null || legs.isEmpty) return steps;

    final leg = legs.first;
    final legSteps = leg['steps'] as List?;
    if (legSteps == null) return steps;

    for (var step in legSteps) {
      final startLoc = step['start_location'];
      final endLoc = step['end_location'];
      final instruction = step['html_instructions'] ?? '';
      final distance = step['distance']?['value'] ?? 0;
      final maneuver = step['maneuver'] ?? '';

      steps.add(
        NavigationStep(
          instruction: _cleanHtmlInstruction(instruction),
          startLocation: LatLng(startLoc['lat'], startLoc['lng']),
          endLocation: LatLng(endLoc['lat'], endLoc['lng']),
          distanceMeters: distance.toDouble(),
          maneuver: maneuver,
        ),
      );
    }

    return steps;
  }

  String _cleanHtmlInstruction(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<bool> _startRouteTracking(
    LatLng destinationLatLng,
    String placeName,
  ) async {
    if (_mapController == null) return false;

    final routeData = await _fetchRouteData(
      _currentPosition,
      destinationLatLng,
    );
    if (routeData.isEmpty) {
      await _tts.speak('Route not available for $placeName');
      return false;
    }

    final route = routeData['polyline'] as List<LatLng>;
    final steps = routeData['steps'] as List<NavigationStep>;

    if (route.isEmpty || steps.isEmpty) {
      await _tts.speak('Route not available for $placeName');
      return false;
    }

    // Initialize turn-by-turn navigation
    _navigationSteps = steps;
    _currentStepIndex = 0;
    _announcedSteps.clear();
    _currentInstruction = steps.first.instruction;

    print('🧭 Navigation started with ${steps.length} steps');
    print('📍 First instruction: ${steps.first.instruction}');

    setState(() {
      _destinationPosition = destinationLatLng;
      _routePoints = route;
      _isTrackingRoute = true;

      _markers
        ..removeWhere((m) => m.markerId.value == 'destination')
        ..removeWhere((m) => m.markerId.value == 'current_location')
        ..add(
          Marker(
            markerId: const MarkerId('destination'),
            position: destinationLatLng,
            infoWindow: InfoWindow(title: placeName),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        )
        ..add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: _currentPosition,
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );

      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: darkBlue,
            width: 6,
            points: _routePoints,
          ),
        );
    });

    await _animateCameraToBounds(_currentPosition, destinationLatLng);
    _startTrackingStream();
    return true;
  }

  void _startTrackingStream() {
    _positionSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    print('📍 Starting position stream for turn-by-turn navigation');
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            final newPos = LatLng(position.latitude, position.longitude);
            print(
              '📍 Position update: lat=${position.latitude}, lon=${position.longitude}',
            );

            setState(() {
              _currentPosition = newPos;
              _markers.removeWhere(
                (m) => m.markerId.value == 'current_location',
              );
              _markers.add(
                Marker(
                  markerId: const MarkerId('current_location'),
                  position: newPos,
                  infoWindow: const InfoWindow(title: 'Your Location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                ),
              );
            });

            // Turn-by-turn navigation logic
            if (_navigationSteps.isNotEmpty &&
                _currentStepIndex < _navigationSteps.length &&
                _isTrackingRoute) {
              final currentStep = _navigationSteps[_currentStepIndex];
              final distanceToStepEnd = Geolocator.distanceBetween(
                newPos.latitude,
                newPos.longitude,
                currentStep.endLocation.latitude,
                currentStep.endLocation.longitude,
              );

              setState(() {
                _distanceToNextStep = distanceToStepEnd;
                _currentInstruction = currentStep.instruction;
              });

              print(
                '🧭 Step $_currentStepIndex: Distance=${distanceToStepEnd.round()}m, Maneuver=${currentStep.maneuver}',
              );

              // Announce instruction at 50 meters
              if (distanceToStepEnd <= 50 &&
                  !_announcedSteps.contains(_currentStepIndex) &&
                  _isNavigationActive) {
                _announcedSteps.add(_currentStepIndex);
                final announcement = _formatNavigationAnnouncement(
                  currentStep.instruction,
                  distanceToStepEnd.round(),
                );
                print('📢 Announcing turn-by-turn: $announcement');
                _tts.speak(announcement);
              }

              // Advance to next step when within 10 meters
              if (distanceToStepEnd <= 10) {
                if (_currentStepIndex < _navigationSteps.length - 1) {
                  setState(() {
                    _currentStepIndex++;
                    _currentInstruction =
                        _navigationSteps[_currentStepIndex].instruction;
                  });
                  print(
                    '➡️ Advanced to step ${_currentStepIndex + 1}/${_navigationSteps.length}',
                  );
                }
              }
            }

            // Check arrival at final destination
            if (_destinationPosition != null) {
              final remaining = Geolocator.distanceBetween(
                newPos.latitude,
                newPos.longitude,
                _destinationPosition!.latitude,
                _destinationPosition!.longitude,
              );

              if (remaining < 30 && _isTrackingRoute) {
                _isTrackingRoute = false;
                setState(() => _isNavigationActive = false);
                _tts.speak('You have arrived at your destination');
                print('🎯 Arrived at destination!');
              }

              _animateCameraToBounds(newPos, _destinationPosition!);
            }
          },
          onError: (error) {
            print('❌ Position stream error: $error');
          },
        );
  }

  // Format navigation announcements for TTS
  String _formatNavigationAnnouncement(String instruction, int distanceMeters) {
    if (distanceMeters > 30) {
      return 'In $distanceMeters meters, $instruction';
    } else if (distanceMeters > 10) {
      return '$instruction, in $distanceMeters meters';
    } else {
      return instruction;
    }
  }

  // User ka current location fetch karo
  Future<void> _getUserLocation() async {
    try {
      print('🔍 Starting location fetch...');

      // پہلے 3 سیکنڈ wait کریں تاکہ GPS initialize ہو
      await Future.delayed(const Duration(seconds: 1));

      Position? position = await LocationService.getCurrentLocation();

      if (position != null) {
        print('✅ Got position: ${position.latitude}, ${position.longitude}');
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);

          // Markers clear کریں پھر دوبارہ add کریں
          _markers.clear();
          _markers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: _currentPosition,
              infoWindow: const InfoWindow(
                title: 'Your Location',
                snippet: 'You are here',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          );
          print('📍 Marker added: $_currentPosition');
          print('📌 Total markers: ${_markers.length}');
        });

        // Map کو animate کریں user کی location پر - delay دیں تاکہ map tile load ہو
        if (_mapController != null) {
          await Future.delayed(const Duration(milliseconds: 800));
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition, 15),
          );
          print('🎯 Map animated to: $_currentPosition');
        }
      } else {
        print('⚠️ Position is null - showing default location');
        // Default location پر map دکھائیں
        if (_mapController != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition, 12),
          );
        }
      }
    } catch (e) {
      print('❌ Location error: $e');
    }
  }

  // Detection loop start karo (har 2.5 seconds on background thread to avoid blocking UI)
  void _startDetection() {
    // Cancel any existing timer first
    _detectionTimer?.cancel();
    _isDetectionPaused = false;

    _detectionTimer = Timer.periodic(const Duration(milliseconds: 2500), (
      timer,
    ) {
      // Keep detection running for safety unless explicitly paused by critical errors
      if (_isDetectionPaused) return;
      if (!_isCameraInitialized || _isDetecting || !mounted) {
        return;
      }

      _isDetecting = true;

      // Run detection on background thread to avoid blocking UI
      Future.microtask(() async {
        try {
          final image = await _cameraController!.takePicture();
          final bytes = await image.readAsBytes();

          // Decode and detect in a background compute isolate
          final decodedImage = await compute(_decodeImageInBackground, bytes);

          if (decodedImage != null) {
            final detections = await _detector.detectObjects(decodedImage);

            if (mounted) {
              setState(() => _detections = detections);
            }

            final knownObstacleStopAlert = _buildKnownObstacleStopAlert(
              decodedImage,
              detections,
            );
            if (knownObstacleStopAlert != null) {
              _isFrontBlockedByObstacle = true;
              await _announceSafetyAlert(knownObstacleStopAlert);
              return;
            }

            final safetyAlert = _evaluateSafetyAlert(decodedImage, detections);
            if (safetyAlert != null) {
              _isFrontBlockedByObstacle = true;
              await _announceSafetyAlert(safetyAlert);
              return;
            }

            await _announcePathClearIfNeeded();

            final obstacleDistanceAlert = _buildObstacleDistanceAlert(
              decodedImage,
              detections,
            );
            if (obstacleDistanceAlert != null) {
              await _announceObstacleDistanceAlert(obstacleDistanceAlert);
            }

            if (detections.isNotEmpty) {
              // Debug: Print ALL labels before check
              final allLabels = detections.map((d) => "'${d.label}'").toList();
              print('🔍 ALL LABELS: $allLabels');

              // Pehle face recognition try karo, agar person hai
              final hasPerson = detections.any(
                (d) => d.label.toLowerCase() == 'person',
              );

              print(
                '🔍 Detection check: hasPerson=$hasPerson, faceReady=$_isFaceServicesReady',
              );

              if (hasPerson && _isFaceServicesReady) {
                // Face recognition chalaao - wo khud announce karega
                await _handleFaceRecognition(
                  detections,
                  decodedImage,
                  image.path,
                );
              } else {
                // Agar person nahi ya face service ready nahi, tab objects announce karo
                _announceDetections(detections);
              }
            }
          }
        } catch (e) {
          print('❌ Detection error: $e');
        } finally {
          _isDetecting = false;
        }
      });
    });
  }

  // Background image decoding to prevent UI blocking
  static img.Image? _decodeImageInBackground(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (e) {
      print('❌ Image decode error: $e');
      return null;
    }
  }

  // CameraImage ko img.Image mein convert karo (YUV420 -> RGB)
  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      // YUV420 format se RGB extract karo
      final img.Image image = img.Image(width: width, height: height);
      final Plane yPlane = cameraImage.planes[0];
      final Plane uPlane = cameraImage.planes[1];
      final Plane vPlane = cameraImage.planes[2];

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * yPlane.bytesPerRow + x;
          final int uvIndex =
              (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uPlane.bytesPerPixel!;

          final int yValue = yPlane.bytes[yIndex];
          final int uValue = uPlane.bytes[uvIndex];
          final int vValue = vPlane.bytes[uvIndex];

          // YUV to RGB conversion
          int r = (yValue + 1.370705 * (vValue - 128)).clamp(0, 255).toInt();
          int g =
              (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128))
                  .clamp(0, 255)
                  .toInt();
          int b = (yValue + 1.732446 * (uValue - 128)).clamp(0, 255).toInt();

          image.setPixelRgb(x, y, r, g, b);
        }
      }
      return image;
    } catch (e) {
      print('❌ Camera image conversion error: $e');
      return null;
    }
  }

  // Voice feedback (blind users ke liye)
  void _announceDetections(List<Detection> detections) {
    if (detections.isEmpty) return;

    final labels = detections.map((d) => d.label).toSet().take(3);
    final message = 'Detected: ${labels.join(', ')}';
    // Queue this non-critical detection so safety alerts remain highest priority.
    _safetyAlertQueue.add(message);
    _processSafetyQueue();
  }

  Future<void> _announceSafetyAlert(String message) async {
    final now = DateTime.now();
    final shouldAnnounce =
        _lastSafetyAlertTime == null ||
        now.difference(_lastSafetyAlertTime!) > const Duration(seconds: 8) ||
        _lastSafetyAlertMessage != message;

    if (!shouldAnnounce) return;

    _lastSafetyAlertTime = now;
    _lastSafetyAlertMessage = message;

    print('⚠️ Safety alert queued: $message');

    // If voice navigation or listening was active, mark to resume it after alerts
    if (_isListeningForDestination || _isNavigating || _isVoiceNavActive) {
      _postSafetyResumeVoiceNav = true;
      try {
        await _speech.stop();
      } catch (_) {}
    }

    _safetyAlertQueue.add(message);
    await _processSafetyQueue();
  }

  Future<void> _announcePathClearIfNeeded() async {
    if (!_isFrontBlockedByObstacle) return;

    final now = DateTime.now();
    final isRecentlyAnnounced =
        _lastPathClearAnnouncementTime != null &&
        now.difference(_lastPathClearAnnouncementTime!) <
            const Duration(seconds: 5);
    if (isRecentlyAnnounced) return;

    _isFrontBlockedByObstacle = false;
    _lastPathClearAnnouncementTime = now;

    // Reset safety cache so a new obstacle can be announced immediately.
    _lastSafetyAlertTime = null;
    _lastSafetyAlertMessage = null;

    final msg = 'No obstacle ahead. Move forward.';
    _safetyAlertQueue.add(msg);
    await _processSafetyQueue();
  }

  Future<void> _announceObstacleDistanceAlert(String message) async {
    final now = DateTime.now();
    final shouldAnnounce =
        _lastObstacleAlertTime == null ||
        now.difference(_lastObstacleAlertTime!) > const Duration(seconds: 4) ||
        _lastObstacleAlertMessage != message;

    if (!shouldAnnounce) return;

    _lastObstacleAlertTime = now;
    _lastObstacleAlertMessage = message;

    print('🚧 Obstacle alert queued: $message');
    _safetyAlertQueue.add(message);
    await _processSafetyQueue();
  }

  Future<void> _processSafetyQueue() async {
    if (_isAnnouncingSafety) return;
    _isAnnouncingSafety = true;

    while (_safetyAlertQueue.isNotEmpty) {
      final msg = _safetyAlertQueue.removeAt(0);
      try {
        print('🔊 Announcing safety: $msg');
        await _tts.stop();
        // Ensure speech-to-text not listening
        try {
          await _speech.stop();
        } catch (_) {}
        await _tts.speak(msg);
      } catch (e) {
        print('❌ Error announcing safety message: $e');
      }
      // small delay between announcements to avoid clipping
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isAnnouncingSafety = false;

    // Resume voice navigation flow if it was active before alerts
    if (_postSafetyResumeVoiceNav) {
      _postSafetyResumeVoiceNav = false;
      // Slight delay to allow TTS engine to settle
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await _startVoiceNavigationTrigger();
      } catch (e) {
        print('❌ Error resuming voice nav after safety alerts: $e');
      }
    }
  }

  String? _buildKnownObstacleStopAlert(
    img.Image image,
    List<Detection> detections,
  ) {
    if (detections.isEmpty || image.width <= 0 || image.height <= 0) {
      return null;
    }

    final frontLeft = image.width * 0.25;
    final frontRight = image.width * 0.75;
    final minBottomY = image.height * 0.40;

    Detection? criticalObstacle;
    double nearestDistance = double.infinity;

    for (final detection in detections) {
      final label = detection.label.trim().toLowerCase();
      if (!_hardStopLabels.contains(label) || detection.confidence < 0.45) {
        continue;
      }

      final centerX = detection.x + (detection.width / 2);
      final bottomY = detection.y + detection.height;
      final isInFront =
          centerX >= frontLeft &&
          centerX <= frontRight &&
          bottomY >= minBottomY;
      if (!isInFront) continue;

      final estimatedDistance = _estimateDistanceMeters(detection, image);
      if (estimatedDistance <= 10.0 && estimatedDistance < nearestDistance) {
        criticalObstacle = detection;
        nearestDistance = estimatedDistance;
      }
    }

    if (criticalObstacle == null || !nearestDistance.isFinite) {
      return null;
    }

    final prettyLabel = criticalObstacle.label.trim().replaceAll('_', ' ');
    final distanceText = nearestDistance < 3.0
        ? nearestDistance.toStringAsFixed(1)
        : nearestDistance.toStringAsFixed(0);
    return 'Stop, $prettyLabel ahead at about $distanceText meters.';
  }

  String? _buildObstacleDistanceAlert(
    img.Image image,
    List<Detection> detections,
  ) {
    if (detections.isEmpty || image.width <= 0 || image.height <= 0) {
      return null;
    }

    final frontLeft = image.width * 0.20;
    final frontRight = image.width * 0.80;
    final minBottomY = image.height * 0.35;

    Detection? nearest;
    String? nearestLabel;
    double nearestDistanceMeters = double.infinity;

    for (final detection in detections) {
      if (detection.confidence < 0.35) continue;

      final centerX = detection.x + (detection.width / 2);
      final bottomY = detection.y + detection.height;
      final isInFront =
          centerX >= frontLeft &&
          centerX <= frontRight &&
          bottomY >= minBottomY;
      if (!isInFront) continue;

      final estimatedDistance = _estimateDistanceMeters(detection, image);

      if (estimatedDistance < nearestDistanceMeters) {
        nearest = detection;
        nearestDistanceMeters = estimatedDistance;
        nearestLabel = detection.label.trim().toLowerCase();
      }
    }

    if (nearest == null ||
        nearestLabel == null ||
        !nearestDistanceMeters.isFinite) {
      return null;
    }

    if (_lastObstacleLabel == nearestLabel &&
        _smoothedObstacleDistanceMeters != null) {
      _smoothedObstacleDistanceMeters =
          (_smoothedObstacleDistanceMeters! * 0.65) +
          (nearestDistanceMeters * 0.35);
    } else {
      _smoothedObstacleDistanceMeters = nearestDistanceMeters;
      _lastObstacleLabel = nearestLabel;
    }

    final spokenDistanceMeters = _smoothedObstacleDistanceMeters!.clamp(
      0.5,
      20.0,
    );

    final label = nearest.label.trim().replaceAll('_', ' ');
    final distanceText = spokenDistanceMeters < 3.0
        ? spokenDistanceMeters.toStringAsFixed(1)
        : spokenDistanceMeters.toStringAsFixed(0);
    return '$label ahead, about $distanceText meters.';
  }

  double _estimateDistanceMeters(Detection detection, img.Image image) {
    if (image.width <= 0 || image.height <= 0) return 12.0;

    final normalizedLabel = detection.label.trim().toLowerCase();
    final verticalFovRad = _cameraVerticalFovDeg * pi / 180;
    final focalY = image.height / (2 * tan(verticalFovRad / 2));

    final horizontalFovRad =
        2 * atan(tan(verticalFovRad / 2) * (image.width / image.height));
    final focalX = image.width / (2 * tan(horizontalFovRad / 2));

    final widthReference = _referenceObjectWidthsMeters[normalizedLabel];
    final usesWidthModel = widthReference != null;

    final objectSizeMeters =
        widthReference ??
        _referenceObjectHeightsMeters[normalizedLabel] ??
        1.60;

    final pixelSize = usesWidthModel ? detection.width : detection.height;
    if (pixelSize <= 0) return 12.0;

    final focalPx = usesWidthModel ? focalX : focalY;
    var estimated = (objectSizeMeters * focalPx) / pixelSize;

    final scale = _distanceScaleByLabel[normalizedLabel] ?? 1.0;
    estimated *= scale;

    // If object touches bottom edge, box can be truncated; compensate slightly.
    final boxBottom = detection.y + detection.height;
    final bottomRatio = (boxBottom / image.height).clamp(0.0, 1.0);
    if (bottomRatio > 0.9) {
      estimated *= 0.88;
    }

    return estimated.clamp(0.5, 20.0);
  }

  String? _evaluateSafetyAlert(img.Image image, List<Detection> detections) {
    if (image.width < 40 || image.height < 40) return null;

    // Path-centric view: lower center is the walkable corridor, upper/mid band
    // is where any unknown front obstacle would usually appear first.
    final pathLeft = (image.width * 0.30).round();
    final pathTop = (image.height * 0.62).round();
    final pathWidth = (image.width * 0.40).round();
    final pathHeight = (image.height * 0.26).round();

    final frontLeft = (image.width * 0.20).round();
    final frontTop = (image.height * 0.22).round();
    final frontWidth = (image.width * 0.60).round();
    final frontHeight = (image.height * 0.34).round();

    final pathCrop = _cropRegion(
      image,
      pathLeft,
      pathTop,
      pathWidth,
      pathHeight,
    );
    final frontCrop = _cropRegion(
      image,
      frontLeft,
      frontTop,
      frontWidth,
      frontHeight,
    );

    final pathFlat =
        pathCrop != null &&
        _isFlatTexture(
          pathCrop,
          varianceThreshold: 170,
          edgeRatioThreshold: 0.055,
          edgeDeltaThreshold: 22,
        );
    final frontFlat =
        frontCrop != null &&
        _isFlatTexture(
          frontCrop,
          varianceThreshold: 210,
          edgeRatioThreshold: 0.07,
          edgeDeltaThreshold: 18,
        );

    final hasDetectionInPath = _hasDetectionInArea(
      detections,
      image.width,
      image.height,
      pathLeft,
      pathTop,
      pathWidth,
      pathHeight,
    );
    final hasDetectionInFront = _hasDetectionInArea(
      detections,
      image.width,
      image.height,
      frontLeft,
      frontTop,
      frontWidth,
      frontHeight,
    );

    if (hasDetectionInPath || hasDetectionInFront) {
      _pathFlatStreak = 0;
      _wallFlatStreak = 0;
      return null;
    }

    _pathFlatStreak = pathFlat ? _pathFlatStreak + 1 : 0;
    _wallFlatStreak = frontFlat ? _wallFlatStreak + 1 : 0;
    final stablePathFlat = _pathFlatStreak >= 2;
    final stableFrontFlat = _wallFlatStreak >= 2;

    if (!stablePathFlat && !stableFrontFlat) {
      return null;
    }

    if (stablePathFlat && stableFrontFlat) {
      return 'Stop, unknown obstacle ahead. Please change direction.';
    }

    if (stableFrontFlat) {
      return 'Stop, unknown front obstacle ahead. Please change direction.';
    }

    if (stablePathFlat) {
      return 'Stop, unknown lower path obstacle ahead. Please change direction.';
    }

    return 'Stop, unknown lower path obstacle ahead. Please change direction.';
  }

  bool _hasDetectionInArea(
    List<Detection> detections,
    int imageWidth,
    int imageHeight,
    int left,
    int top,
    int width,
    int height,
  ) {
    final areaRight = left + width;
    final areaBottom = top + height;

    for (final detection in detections) {
      final detectionLeft = detection.x.clamp(0, imageWidth.toDouble());
      final detectionTop = detection.y.clamp(0, imageHeight.toDouble());
      final detectionRight = (detection.x + detection.width).clamp(
        0,
        imageWidth.toDouble(),
      );
      final detectionBottom = (detection.y + detection.height).clamp(
        0,
        imageHeight.toDouble(),
      );

      final overlapLeft = detectionLeft > left
          ? detectionLeft
          : left.toDouble();
      final overlapTop = detectionTop > top ? detectionTop : top.toDouble();
      final overlapRight = detectionRight < areaRight
          ? detectionRight
          : areaRight.toDouble();
      final overlapBottom = detectionBottom < areaBottom
          ? detectionBottom
          : areaBottom.toDouble();

      final overlapWidth = overlapRight - overlapLeft;
      final overlapHeight = overlapBottom - overlapTop;
      if (overlapWidth <= 0 || overlapHeight <= 0) continue;

      final overlapArea = overlapWidth * overlapHeight;
      final detectionArea = detection.width * detection.height;
      if (detectionArea <= 0) continue;

      if (overlapArea / detectionArea >= 0.2) {
        return true;
      }
    }

    return false;
  }

  img.Image? _cropRegion(
    img.Image source,
    int left,
    int top,
    int width,
    int height,
  ) {
    final x = left.clamp(0, source.width - 1);
    final y = top.clamp(0, source.height - 1);
    final cropWidth = width.clamp(1, source.width - x);
    final cropHeight = height.clamp(1, source.height - y);

    if (cropWidth <= 0 || cropHeight <= 0) return null;

    return img.copyCrop(
      source,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );
  }

  bool _isFlatTexture(
    img.Image region, {
    double varianceThreshold = 220,
    double edgeRatioThreshold = 0.08,
    int edgeDeltaThreshold = 18,
  }) {
    if (region.width < 4 || region.height < 4) return false;

    double sum = 0.0;
    double sumSquares = 0.0;
    int sampleCount = 0;
    int edgeCount = 0;

    for (int y = 0; y < region.height; y += 2) {
      for (int x = 0; x < region.width; x += 2) {
        final pixel = region.getPixel(x, y);
        final brightness =
            0.299 * pixel.r.toDouble() +
            0.587 * pixel.g.toDouble() +
            0.114 * pixel.b.toDouble();

        sum += brightness;
        sumSquares += brightness * brightness;
        sampleCount++;

        if (x > 0 && y > 0) {
          final leftPixel = region.getPixel(x - 1, y);
          final topPixel = region.getPixel(x, y - 1);
          final leftBrightness =
              0.299 * leftPixel.r.toDouble() +
              0.587 * leftPixel.g.toDouble() +
              0.114 * leftPixel.b.toDouble();
          final topBrightness =
              0.299 * topPixel.r.toDouble() +
              0.587 * topPixel.g.toDouble() +
              0.114 * topPixel.b.toDouble();

          final horizontalDiff = (brightness - leftBrightness).abs();
          final verticalDiff = (brightness - topBrightness).abs();
          if (horizontalDiff > edgeDeltaThreshold ||
              verticalDiff > edgeDeltaThreshold) {
            edgeCount++;
          }
        }
      }
    }

    if (sampleCount == 0) return false;

    final mean = sum / sampleCount;
    final variance = (sumSquares / sampleCount) - (mean * mean);
    final edgeRatio = edgeCount / sampleCount;

    return variance < varianceThreshold && edgeRatio < edgeRatioThreshold;
  }

  Future<void> _handleFaceRecognition(
    List<Detection> detections,
    img.Image decodedImage,
    String imagePath,
  ) async {
    print(
      '👤 Face recognition check: ready=$_isFaceServicesReady, recognizing=$_isFaceRecognizing',
    );

    if (!_isFaceServicesReady) {
      print('⚠️ Face services not ready - skipping recognition');
      return;
    }
    if (_isFaceRecognizing) {
      print('⏳ Already recognizing - skipping');
      return;
    }

    // Cooldown between recognitions to avoid spam (6 seconds)
    final now = DateTime.now();
    if (_lastRecognitionTime != null &&
        now.difference(_lastRecognitionTime!) < const Duration(seconds: 6)) {
      print(
        '⏱️ Cooldown active (${(6 - now.difference(_lastRecognitionTime!).inSeconds)}s left) - skipping',
      );
      return;
    }

    final personDetection = detections.firstWhere(
      (d) => d.label.toLowerCase() == 'person',
      orElse: () =>
          Detection(label: '', confidence: 0, x: 0, y: 0, width: 0, height: 0),
    );

    if (personDetection.label.isEmpty) {
      print('❌ No person detected in list');
      return;
    }

    print('✅ Person detected! Starting face recognition...');

    _isFaceRecognizing = true;
    _lastRecognitionTime = now;

    try {
      // Crop detected person region to focus on face (upper portion of box)
      final croppedFace = _cropPersonRegion(decodedImage, personDetection);
      final tempPath =
          '${Directory.systemTemp.path}/face_${now.millisecondsSinceEpoch}.jpg';

      final File faceFile;
      if (croppedFace != null) {
        final bytes = img.encodeJpg(croppedFace, quality: 95);
        faceFile = await File(tempPath).writeAsBytes(bytes, flush: true);
      } else {
        faceFile = File(imagePath);
      }

      final result = await _offlineRecognition.recognizeOfflineFace(faceFile);

      if (!mounted) return;

      print(
        '🔍 Recognition result: ${result.isRecognized ? "✅ ${result.personName}" : "❌ Unknown"} (${result.similarity.toStringAsFixed(2)})',
      );

      // Threshold: 70% similarity required for recognition
      const double SIMILARITY_THRESHOLD = 0.7;
      final isSimilarityAboveThreshold =
          result.similarity >= SIMILARITY_THRESHOLD;
      final isActuallyRecognized =
          result.isRecognized && isSimilarityAboveThreshold;

      print(
        '📊 Threshold check: similarity=${result.similarity.toStringAsFixed(2)} | threshold=$SIMILARITY_THRESHOLD | passed=$isSimilarityAboveThreshold',
      );

      setState(() {
        _recognizedPerson = isActuallyRecognized
            ? result.personName ?? 'Unknown'
            : 'Unknown';
        _recognizedSimilarity = result.similarity;
      });

      if (isActuallyRecognized) {
        // Check if it's a DIFFERENT person (name changed) - announce immediately
        final isDifferentPerson = _lastAnnouncedPerson != result.personName;

        // Or if same person but cooldown passed
        final isCooldownPassed =
            _lastSpeechTime == null ||
            now.difference(_lastSpeechTime!) > const Duration(seconds: 6);

        final shouldSpeak = isDifferentPerson || isCooldownPassed;

        print(
          '🔊 Should speak: $shouldSpeak | Different person: $isDifferentPerson | Cooldown passed: $isCooldownPassed | Last: $_lastAnnouncedPerson → Current: ${result.personName}',
        );

        if (shouldSpeak && result.personName != null) {
          _lastAnnouncedPerson = result.personName;
          _lastSpeechTime = now;
          print('📢 Speaking: ${result.personName}');
          await _speakPerson(result.personName!);
        }
      } else {
        // Unknown face detected (below threshold or not recognized)
        // If last was recognized person and now it's unknown → announce immediately
        final wasPreviouslyRecognized =
            _lastAnnouncedPerson != null &&
            _lastAnnouncedPerson != 'Unknown' &&
            _lastAnnouncedPerson != 'Stranger';

        final isUnknownCooldownPassed =
            _lastSpeechTime == null ||
            now.difference(_lastSpeechTime!) > const Duration(seconds: 6);

        final shouldSpeakUnknown =
            wasPreviouslyRecognized || isUnknownCooldownPassed;

        print(
          '⚠️ Unknown face | Was recognized before: $wasPreviouslyRecognized | Cooldown passed: $isUnknownCooldownPassed | Should speak: $shouldSpeakUnknown | Last: $_lastAnnouncedPerson',
        );

        if (shouldSpeakUnknown) {
          _lastAnnouncedPerson = 'Unknown';
          _lastSpeechTime = now;
          print('📢 Speaking: Unknown');
          await _speakPerson('Unknown');
        }
      }
    } catch (e) {
      print('❌ Face recognition error: $e');
    } finally {
      _isFaceRecognizing = false;
    }
  }

  img.Image? _cropPersonRegion(img.Image source, Detection detection) {
    final x = detection.x.clamp(0, source.width.toDouble());
    final y = detection.y.clamp(0, source.height.toDouble());
    final w = detection.width.clamp(16.0, source.width.toDouble() - x);
    final h = detection.height.clamp(16.0, source.height.toDouble() - y);

    // Focus upper portion assuming face near top of person box
    final faceHeight = (h * 0.6).clamp(16.0, source.height.toDouble() - y);

    final cropWidth = w.round();
    final cropHeight = faceHeight.round();
    final cropX = x.round();
    final cropY = y.round();

    if (cropWidth <= 0 || cropHeight <= 0) return null;

    return img.copyCrop(
      source,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );
  }

  Future<void> _speakPerson(String name) async {
    await _tts.stop();
    await _tts.speak('$name is in front of you');
  }

  @override
  void dispose() {
    // Cancel all timers
    _detectionTimer?.cancel();
    _focusCheckTimer?.cancel();
    _pauseDetection();

    _cameraController?.dispose();
    _detector.dispose();
    _tts.stop();
    _speech.stop();
    _voiceListeningTimeoutTimer?.cancel();
    _fallCountdownTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    _volumeButtonTimer?.cancel();
    super.dispose();
  }

  /// Pause object detection and TTS announcements
  void _pauseDetection() {
    if (!_isDetectionPaused) {
      _isDetectionPaused = true;
      _tts.stop(); // Stop any ongoing speech
      _detectionTimer?.cancel();
      debugPrint('⏸️ Detection paused - TTS stopped');
    }
  }

  /// Resume object detection and TTS announcements
  void _resumeDetection() {
    if (_isDetectionPaused && _isCameraInitialized && mounted) {
      _isDetectionPaused = false;
      _startDetection(); // Restart the detection loop
      debugPrint('▶️ Detection resumed - Loop restarted');
    }
  }

  /// Start a timer that continuously checks if this screen is still in focus.
  /// If screen loses focus, pause detection. If regains focus, resume detection.
  void _startFocusChecking() {
    _focusCheckTimer?.cancel();
    _focusCheckTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      try {
        final isFocused = ModalRoute.of(context)?.isCurrent ?? false;
        // Always keep detection active for safety. Track focus but do not pause.
        if (isFocused && !_isScreenFocused) {
          _isScreenFocused = true;
          debugPrint('ℹ️ Screen back in focus (detection kept active)');
        } else if (!isFocused && _isScreenFocused) {
          _isScreenFocused = false;
          debugPrint('ℹ️ Screen lost focus (detection kept active)');
        }
      } catch (e) {
        debugPrint('⚠️ Focus check error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: darkBlue),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'User Profile',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: darkBlue),
                title: const Text('Account Details'),
                onTap: () async {
                  // Keep detection active while navigating for safety
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileInfoScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark, color: darkBlue),
                title: const Text('Favourite Destinations'),
                onTap: () async {
                  // Keep detection active while navigating for safety
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavouriteDestinationsScreen(),
                    ),
                  );

                  if (result != null && result is Map) {
                    try {
                      final lat = (result['lat'] as num?)?.toDouble();
                      final lng = (result['lng'] as num?)?.toDouble();
                      final name = result['name'] ?? 'Saved Place';
                      if (lat != null && lng != null) {
                        final routed = await _startRouteTracking(
                          LatLng(lat, lng),
                          name.toString(),
                        );
                        if (routed) {
                          await _tts.speak('Navigating to $name');
                        } else {
                          await _tts.speak(
                            'Unable to start navigation to $name',
                          );
                        }
                      }
                    } catch (e) {
                      print('❌ Error handling favourite selection: $e');
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignInScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: darkBlue),
          centerTitle: true,
          title: Text(
            "VisionMate",
            style: GoogleFonts.inter(
              color: darkBlue,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: Column(
          children: [
            // 1. Navigation Section (Upper Half) - Google Maps
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition,
                      zoom: 15,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      print('✅ Google Map Created Successfully');
                      // Ab location fetch karo jab map ready ho gaya
                      _getUserLocation();
                    },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapType: MapType.normal,
                    onCameraMove: (position) {
                      print('📍 Map Camera: ${position.target}');
                    },
                  ),

                  // Search Bar Overlay
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search location...',
                                    hintStyle: GoogleFonts.inter(
                                      color: Colors.grey,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: darkBlue,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 15,
                                    ),
                                  ),
                                  onChanged: _getPlacePredictions,
                                  onSubmitted: _searchPlace,
                                ),
                              ),
                              // Search Progress Indicator
                              if (_isSearching)
                                const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Autocomplete Suggestions
                        if (_searchPredictions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            constraints: const BoxConstraints(maxHeight: 240),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _searchPredictions.length > 5
                                  ? 5
                                  : _searchPredictions.length,
                              itemBuilder: (context, index) {
                                final prediction = _searchPredictions[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.location_on,
                                    color: darkBlue,
                                  ),
                                  title: Text(
                                    prediction.description,
                                    style: GoogleFonts.inter(fontSize: 14),
                                  ),
                                  onTap: () {
                                    _selectPrediction(prediction);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Object Detection Section (Lower Half) - LIVE CAMERA
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  // Camera Preview (Real-time) - Properly scaled
                  _isCameraInitialized && _cameraController != null
                      ? AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),

                  // Detection Bounding Boxes (Overlay)
                  ..._detections.map((detection) {
                    return _buildDetectionBox(detection, brandYellow);
                  }),

                  // Detection Count Indicator
                  if (_detections.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_detections.length} objects',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  if (_isListeningForDestination)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Listening...',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Face recognition status
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Person in front',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _recognizedPerson,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(_recognizedSimilarity * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionBox(Detection detection, Color color) {
    if (_cameraSize == null) return const SizedBox.shrink();

    // Context se current screen size nikal lo
    final screenSize = MediaQuery.of(context).size;
    final cameraPreviewHeight = screenSize.height / 2; // Lower half

    // Camera feed ke according scale karo (use actual aspect ratio)
    final aspectRatio = _cameraController?.value.aspectRatio ?? 1.0;
    final displayWidth = cameraPreviewHeight * aspectRatio;

    final scaleX = displayWidth / _cameraSize!.width;
    final scaleY = cameraPreviewHeight / _cameraSize!.height;

    // Clamp positions to prevent negative or out-of-bounds values
    final displayX = (detection.x * scaleX).clamp(0.0, screenSize.width - 50);
    final displayY = (detection.y * scaleY).clamp(
      0.0,
      cameraPreviewHeight - 50,
    );
    final displayBoxWidth = (detection.width * scaleX).clamp(
      10.0,
      screenSize.width,
    );
    final displayBoxHeight = (detection.height * scaleY).clamp(
      10.0,
      cameraPreviewHeight,
    );

    print(
      '📍 ${detection.label} | Screen: (${screenSize.width}x${screenSize.height}) | CameraSize: $_cameraSize | Box at: ($displayX, $displayY)',
    );

    return Positioned(
      top:
          displayY, // Stack pehle se lower half mein hai, extra offset ki zarurat nahi
      left: displayX,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            width: displayBoxWidth,
            height: displayBoxHeight,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
            ),
          ),
        ],
      ),
    );
  }
}

// Model class for navigation steps
class NavigationStep {
  final String instruction;
  final LatLng startLocation;
  final LatLng endLocation;
  final double distanceMeters;
  final String? maneuver;

  NavigationStep({
    required this.instruction,
    required this.startLocation,
    required this.endLocation,
    required this.distanceMeters,
    this.maneuver,
  });
}

// Model class for place predictions
class PlacePrediction {
  final String placeId;
  final String description;

  PlacePrediction({required this.placeId, required this.description});
}
