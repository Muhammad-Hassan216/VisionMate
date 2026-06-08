import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Agli screen ka import (Apni file ka sahi naam check kar lein)
import 'guardian_linked_dashboard.dart';

class GuardianLinkScreen extends StatefulWidget {
  const GuardianLinkScreen({super.key});

  @override
  State<GuardianLinkScreen> createState() => _GuardianLinkScreenState();
}

class _GuardianLinkScreenState extends State<GuardianLinkScreen> {
  Timer? _checkTimer;
  StreamSubscription<QuerySnapshot>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _startCheckingForLink();
  }

  void _startCheckingForLink() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    // Real-time listener: Check if any user has linked this guardian
    _linkSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('guardianEmail', isEqualTo: user.email)
        .where('isLinked', isEqualTo: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            // User found who linked this guardian - navigate to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const GuardianLinkedDashboard(),
              ),
            );
          }
        });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: brandYellow,
      body: Column(
        children: [
          /// 1. TOP WHITE HEADER
          Container(
            width: double.infinity,
            height: 120,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Text(
                  'LINK WITH USER',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
              ),
            ),
          ),

          /// 2. MAIN WHITE CARD
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// SVG LINK ICON
                  SvgPicture.asset(
                    'assets/svg/link.svg',
                    height: 200,
                    width: 200,
                    colorFilter: const ColorFilter.mode(
                      darkBlue,
                      BlendMode.srcIn,
                    ),
                    placeholderBuilder: (context) =>
                        const Icon(Icons.link, size: 200, color: darkBlue),
                  ),

                  const SizedBox(height: 30),

                  /// "No users Linked" Text
                  Text(
                    'No users Linked',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Chhota sa loader dikha dete hain taake lage kuch ho raha hai
                  const CircularProgressIndicator(color: darkBlue),
                ],
              ),
            ),
          ),

          /// 3. BOTTOM SPACING
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
