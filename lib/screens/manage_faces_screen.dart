import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manage_faces_empty.dart';
import 'manage_faces_list.dart';

class ManageFacesScreen extends StatelessWidget {
  const ManageFacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Faces')),
        body: const Center(child: Text('Please login first')),
      );
    }

    // Firestore se registered faces fetch karo
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registered_faces')
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Manage Faces')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Manage Faces')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        // Data se list banao
        final docs = snapshot.data?.docs ?? [];

        // Agar koi face nahi hai to empty screen dikha do
        if (docs.isEmpty) {
          return const ManageFacesEmptyScreen();
        }

        // Agar faces hain to list screen dikha do with actual data
        return ManageFacesListScreen(faces: docs);
      },
    );
  }
}
