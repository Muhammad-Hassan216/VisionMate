import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Agle flow ke liye registration screen ka import
import 'face_registration_screen.dart';

class ManageFacesListScreen extends StatefulWidget {
  final List<QueryDocumentSnapshot> faces;

  const ManageFacesListScreen({super.key, required this.faces});

  @override
  State<ManageFacesListScreen> createState() => _ManageFacesListScreenState();
}

class _ManageFacesListScreenState extends State<ManageFacesListScreen> {
  late List<QueryDocumentSnapshot> registeredFaces;

  @override
  void initState() {
    super.initState();
    registeredFaces = widget.faces;
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: darkBlue, // Dark blue header
        elevation: 0,
        centerTitle: true,
        title: Text(
          "MANAGE FACES",
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
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 20),
              itemCount: registeredFaces.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Colors.black),
              itemBuilder: (context, index) {
                final faceDoc = registeredFaces[index];
                final faceName = faceDoc['name'] ?? 'Unknown';
                final imagePath = faceDoc['image_path'] ?? '';
                final faceId = faceDoc.id;

                return _buildFaceTile(faceName, imagePath, faceId);
              },
            ),
          ),

          // ✅ ADD NEW BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
            child: SizedBox(
              width: 250, // Button size as per design
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // Naya face add karne ke liye camera screen par bhejien
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FaceRegistrationScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  "+ ADD NEW",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Face List Item Helper
  Widget _buildFaceTile(String name, String imagePath, String faceId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: ListTile(
        leading: CircleAvatar(
          radius: 35,
          backgroundColor: Colors.grey.shade200,
          child: _buildFaceImage(imagePath),
        ),
        title: Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B2E58),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 35),
          onPressed: () {
            _showDeleteConfirmation(context, faceId, name);
          },
        ),
      ),
    );
  }

  // Image ko actual file ya placeholder se load karo
  Widget _buildFaceImage(String imagePath) {
    if (imagePath.isEmpty) {
      return Icon(Icons.person, color: Colors.grey.shade400, size: 40);
    }

    final file = File(imagePath);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, color: Colors.grey.shade400, size: 40);
          },
        ),
      );
    } else {
      return Icon(Icons.person, color: Colors.grey.shade400, size: 40);
    }
  }

  // Delete confirmation dialog
  void _showDeleteConfirmation(
    BuildContext context,
    String faceId,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Face?'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteFace(faceId, name);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Firestore se face delete karo
  Future<void> _deleteFace(String faceId, String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('registered_faces')
            .doc(faceId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$name deleted successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting face: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
