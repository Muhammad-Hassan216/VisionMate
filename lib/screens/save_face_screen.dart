import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/services/facenet_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SaveFaceScreen extends StatefulWidget {
  final String capturedImagePath;

  const SaveFaceScreen({super.key, required this.capturedImagePath});

  @override
  State<SaveFaceScreen> createState() => _SaveFaceScreenState();
}

class _SaveFaceScreenState extends State<SaveFaceScreen> {
  final TextEditingController _nameController = TextEditingController();
  final MobileFaceNetService _mobileFaceNetService = MobileFaceNetService();
  bool _isProcessing = false;
  List<double>? _embeddings;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMobileFaceNet();
  }

  Future<void> _initializeMobileFaceNet() async {
    try {
      await _mobileFaceNetService.loadModel();
      print('✅ MobileFaceNet model initialized');
    } catch (e) {
      print('❌ MobileFaceNet initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load MobileFaceNet model: $e';
        });
      }
    }
  }

  Future<void> _generateAndSaveFace() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 1. Image file se embeddings generate karo
      final imageFile = File(widget.capturedImagePath);
      final embeddings = await _mobileFaceNetService.generateEmbeddings(
        imageFile,
      );

      setState(() {
        _embeddings = embeddings;
      });

      // 2. Firestore mein save karo
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final facesCollection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('registered_faces');

        // Embeddings ko string mein convert karo storage ke liye
        final embeddingsJson = jsonEncode(embeddings);

        await facesCollection.add({
          'name': _nameController.text.trim(),
          'embeddings': embeddingsJson,
          'image_path': widget.capturedImagePath,
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
          'is_primary': true, // First face ko primary mark karo
        });

        print('✅ Face saved successfully with embeddings');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Face Saved Successfully!"),
              backgroundColor: Colors.green,
            ),
          );

          // ManageFacesScreen par wapis jao taaki naye faces show ho saken
          // Pop 3 times: SaveFaceScreen → FaceRegistrationScreen → ManageFacesEmptyScreen → ManageFacesScreen
          Navigator.of(context).pop(); // SaveFaceScreen se bahar
          Navigator.of(context).pop(); // FaceRegistrationScreen se bahar
          Navigator.of(context).pop(); // ManageFacesEmptyScreen se bahar
          // Ab ManageFacesScreen ke pass hain jo StreamBuilder ko refresh karega
        }
      } else {
        throw Exception('User not authenticated');
      }
    } catch (e) {
      print('❌ Error saving face: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving face: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileFaceNetService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "SAVE FACE",
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 50),

            // ✅ Circular Preview with Captured Image
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: darkBlue, width: 3),
                ),
                child: ClipOval(
                  child: Image.file(
                    File(widget.capturedImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.error_outline,
                        size: 120,
                        color: Colors.red.shade300,
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 60),

            // ✅ Input Field with Label on Border
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: TextField(
                controller: _nameController,
                enabled: !_isProcessing,
                decoration: InputDecoration(
                  labelText: "PERSON NAME",
                  labelStyle: GoogleFonts.inter(
                    color: darkBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  hintText: "Enter Name (e.g., Mom)",
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: darkBlue, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: darkBlue, width: 2),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            // ✅ Embeddings Status
            if (_embeddings != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Face embeddings generated: ${_embeddings!.length} dimensions',
                          style: GoogleFonts.inter(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ✅ Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),

            // ✅ SAVE PERSON BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _generateAndSaveFace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandYellow,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(darkBlue),
                          ),
                        )
                      : Text(
                          "SAVE PERSON",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
