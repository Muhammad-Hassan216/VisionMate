import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/services/face_matching_service.dart';

/// Example Implementation: MobileFace Recognition Screen
/// Ye screen face recognition ke liye use ho sakta hai
class MobileFaceRecognitionExample extends StatefulWidget {
  final String capturedImagePath;

  const MobileFaceRecognitionExample({
    super.key,
    required this.capturedImagePath,
  });

  @override
  State<MobileFaceRecognitionExample> createState() =>
      _MobileFaceRecognitionExampleState();
}

class _MobileFaceRecognitionExampleState
    extends State<MobileFaceRecognitionExample> {
  final FaceMatchingService _matchingService = FaceMatchingService();
  bool _isMatching = false;
  Map<String, dynamic>? _matchResult;
  List<Map<String, dynamic>>? _allMatches;

  @override
  void initState() {
    super.initState();
    _initializeAndMatch();
  }

  Future<void> _initializeAndMatch() async {
    try {
      setState(() => _isMatching = true);

      // Model load karo
      await _matchingService.loadModel();

      // Captured image se matching shuru karo
      final imageFile = File(widget.capturedImagePath);
      final result = await _matchingService.matchFaceWithRegistered(imageFile);

      // Tamam matches nikalo
      final allMatches = await _matchingService.getAllFacesWithSimilarity(
        imageFile,
      );

      setState(() {
        _matchResult = result;
        _allMatches = allMatches;
        _isMatching = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        setState(() => _isMatching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _matchingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: darkBlue,
        title: Text(
          'FACE RECOGNITION',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isMatching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Captured Image
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: darkBlue, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.file(
                        File(widget.capturedImagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Best Match Result
                  if (_matchResult != null)
                    Card(
                      color: _matchResult!['matched'] == true
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              _matchResult!['matched'] == true
                                  ? Icons.check_circle
                                  : Icons.cancel_rounded,
                              color: _matchResult!['matched'] == true
                                  ? Colors.green
                                  : Colors.red,
                              size: 50,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _matchResult!['matched'] == true
                                  ? 'Face Recognized'
                                  : 'Face Not Recognized',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_matchResult!['matched'] == true) ...[
                              Text(
                                'Name: ${_matchResult!['name']}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Confidence: ${_matchResult!['confidence']}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),

                  // All Matches List
                  if (_allMatches != null && _allMatches!.isNotEmpty) ...[
                    Text(
                      'All Matches:',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._allMatches!.map((match) {
                      final isMatched = match['matched'] as bool;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isMatched
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: isMatched
                              ? Colors.green.shade50
                              : Colors.grey.shade50,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    match['name'] as String,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Similarity: ${match['confidence']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isMatched ? Icons.check : Icons.close,
                              color: isMatched ? Colors.green : Colors.red,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],

                  // No matches
                  if (_allMatches != null && _allMatches!.isEmpty)
                    Center(
                      child: Text(
                        'No registered faces found',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                          ),
                          child: Text(
                            'Back',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Grant access or take action based on match
                            if (_matchResult?['matched'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Access Granted!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Access Denied!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _matchResult?['matched'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                          child: Text(
                            _matchResult?['matched'] == true
                                ? 'Confirm'
                                : 'Retry',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

// ============================================
// Usage Example in Another Screen:
// ============================================
/*
// Jab face capture ho jaye to ye screen use karo:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MobileFaceRecognitionExample(
      capturedImagePath: imageFile.path,
    ),
  ),
);
*/
