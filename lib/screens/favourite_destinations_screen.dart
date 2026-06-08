import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavouriteDestinationsScreen extends StatelessWidget {
  const FavouriteDestinationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        title: Text(
          "SAVED PLACES",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Info Bar: User ko batane ke liye ke Triple-Press se yahan data ata hai
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            color: brandYellow.withOpacity(0.2),
            child: Text(
              "Locations saved via Voice appear here.",
              style: GoogleFonts.inter(
                color: darkBlue,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildFavouritesList(darkBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavouritesList(Color themeColor) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'Please sign in to see saved places.',
          style: GoogleFonts.inter(color: themeColor),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favourites')
        .orderBy('created_at', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No saved places yet. Triple-press the volume button to save your current location.',
              style: GoogleFonts.inter(color: themeColor),
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final name = data['name'] ?? 'Saved Place';
            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();

            return GestureDetector(
              onTap: () {
                // Return selection to caller
                Navigator.pop(context, {'name': name, 'lat': lat, 'lng': lng});
              },
              child: _buildPlaceTile(
                name.toString(),
                lat != null && lng != null ? '$lat, $lng' : 'No coordinates',
                Icons.place,
                themeColor,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceTile(
    String name,
    String address,
    IconData icon,
    Color themeColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.1), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: themeColor,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        title: Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: themeColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            address,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Tap karne par is jagah ki navigation shuru ho jaye gi
        },
      ),
    );
  }
}
