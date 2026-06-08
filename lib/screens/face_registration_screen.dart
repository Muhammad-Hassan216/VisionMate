import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'save_face_screen.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  CameraController? _cameraController;
  late List<CameraDescription> cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Front camera ke liye index check karo
        int cameraIndex = 0;
        for (int i = 0; i < cameras.length; i++) {
          if (cameras[i].lensDirection == CameraLensDirection.front) {
            cameraIndex = i;
            break;
          }
        }

        _cameraController = CameraController(
          cameras[cameraIndex], // Front camera use karo
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
      print('❌ Camera initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final image = await _cameraController!.takePicture();

        if (mounted) {
          // Captured image ko SaveFaceScreen par pass karo
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SaveFaceScreen(capturedImagePath: image.path),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Photo capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "REGISTER FACE",
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
          "REGISTER FACE",
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
          // ✅ 1. Camera Preview
          CameraPreview(_cameraController!),

          // ✅ 2. Circular Face Guide Overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: brandYellow, width: 3),
              ),
              child: Center(
                child: Text(
                  "Keep face in circle",
                  style: GoogleFonts.inter(
                    color: brandYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // ✅ 3. Dark overlay outside circle (optional for better focus)
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Stack(
                children: [
                  // Top dark area
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(height: 150, color: Colors.black45),
                  ),
                  // Bottom dark area
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(height: 150, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),

          // ✅ 4. Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 60),

                // ✅ CAPTURE BUTTON
                GestureDetector(
                  onTap: _capturePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: brandYellow, width: 4),
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 50,
                      color: brandYellow,
                    ),
                  ),
                ),

                // Close Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 40, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
