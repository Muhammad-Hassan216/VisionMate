import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/services/offline_recognition_service.dart';
import 'package:flutter_application_1/services/firebase_sync_service.dart';

class OfflineRecognitionScreen extends StatefulWidget {
  const OfflineRecognitionScreen({super.key});

  @override
  State<OfflineRecognitionScreen> createState() =>
      _OfflineRecognitionScreenState();
}

class _OfflineRecognitionScreenState extends State<OfflineRecognitionScreen> {
  CameraController? _cameraController;
  late List<CameraDescription> cameras;
  bool _isCameraInitialized = false;
  bool _isRecognizing = false;

  final OfflineRecognitionService _recognitionService =
      OfflineRecognitionService();
  final FirebaseToSQLiteSync _syncService = FirebaseToSQLiteSync();

  String _currentPerson = 'Initializing...';
  bool _isPersonRecognized = false;
  double _similarity = 0.0;
  int _registeredFacesCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    try {
      // 1. Model initialize karo
      print('📱 Initializing recognition model...');
      await _recognitionService.initialize();

      // 2. Firebase se faces sync karo
      print('🔄 Syncing faces from Firebase...');
      await _syncService.syncFacesFromFirebase();

      // 3. Local faces count nikalo
      final status = await _syncService.getSyncStatus();
      setState(() {
        _registeredFacesCount = status['local_faces'] ?? 0;
        print('✅ Synced $_registeredFacesCount faces to local database');
      });

      // 4. Camera initialize karo
      print('📷 Initializing camera...');
      await _initializeCamera();

      if (mounted) {
        setState(() {
          _currentPerson = 'Ready - ${_registeredFacesCount} faces loaded';
          _isPersonRecognized = false;
        });
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      if (mounted) {
        setState(() {
          _currentPerson = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras[0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('❌ Camera error: $e');
    }
  }

  Future<void> _captureAndRecognize() async {
    if (_isRecognizing || _cameraController == null) return;

    try {
      setState(() => _isRecognizing = true);

      // Photo capture karo
      final image = await _cameraController!.takePicture();
      final imageFile = File(image.path);

      print('📸 Photo captured, recognizing...');

      // Offline recognition chalaao
      final result = await _recognitionService.recognizeOfflineFace(imageFile);

      if (mounted) {
        setState(() {
          _isPersonRecognized = result.isRecognized;
          _currentPerson = result.personName ?? 'Unknown Person';
          _similarity = result.similarity;
        });

        // Feedback dikhao
        _showRecognitionDialog(result);
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecognizing = false);
      }
    }
  }

  void _showRecognitionDialog(dynamic result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.isRecognized ? '✅ Recognized' : '❌ Unknown',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: result.isRecognized ? Colors.green : Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.isRecognized) ...[
              Text(
                'Person: ${result.personName}',
                style: GoogleFonts.inter(fontSize: 16),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Confidence: ${result.confidence}',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Similarity: ${(result.similarity * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: darkBlue,
          title: Text(
            'OFFLINE RECOGNITION',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'OFFLINE RECOGNITION',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_cameraController!),

          // Status Overlay (Top)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 Offline Mode',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$_registeredFacesCount faces loaded',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recognition Result (Center)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isPersonRecognized
                        ? Colors.green.withOpacity(0.9)
                        : Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isPersonRecognized ? Colors.green : Colors.red,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPersonRecognized ? Icons.check : Icons.person_outline,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _currentPerson,
                        style: GoogleFonts.inter(
                          color: _isPersonRecognized
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Similarity: ${(_similarity * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Capture Button (Bottom)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isRecognizing ? null : _captureAndRecognize,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: brandYellow, width: 4),
                      color: _isRecognizing ? Colors.grey : Colors.white,
                    ),
                    child: _isRecognizing
                        ? const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.camera_alt_outlined,
                            size: 50,
                            color: Color(0xFF1B2E58),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
