import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Zaroori screens ke imports
import 'manage_faces_screen.dart';
import 'navigate_user_screen.dart';
import 'guardian_profile_screen.dart';

class GuardianLinkedDashboard extends StatefulWidget {
  const GuardianLinkedDashboard({super.key});

  @override
  State<GuardianLinkedDashboard> createState() =>
      _GuardianLinkedDashboardState();
}

class _GuardianLinkedDashboardState extends State<GuardianLinkedDashboard> {
  static const Color darkBlue = Color(0xFF1B2E58);
  static const Color brandYellow = Color(0xFFFFBF55);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _linkedUserSubscription;

  String? _linkedUserId;
  int? _userBatteryLevel;
  bool _isLowBattery = false;
  bool _isCriticalBattery = false;
  String? _lastLowBatteryToken;
  bool _sosActive = false;
  String _sosMessage = 'Emergency alert triggered by user.';
  String? _sosTimeLabel;
  String? _lastSosToken;

  @override
  void initState() {
    super.initState();
    _startSosListener();
  }

  @override
  void dispose() {
    _linkedUserSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startSosListener() async {
    try {
      final guardian = FirebaseAuth.instance.currentUser;
      if (guardian == null) return;

      final guardianDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(guardian.uid)
          .get();

      final guardianEmail =
          (guardianDoc.data()?['email'] as String?) ?? guardian.email;
      if (guardianEmail == null || guardianEmail.isEmpty) return;

      final linkedUserQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('guardianEmail', isEqualTo: guardianEmail)
          .where('isLinked', isEqualTo: true)
          .limit(1)
          .get();

      if (linkedUserQuery.docs.isEmpty) return;

      _linkedUserId = linkedUserQuery.docs.first.id;
      _linkedUserSubscription?.cancel();
      _linkedUserSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_linkedUserId)
          .snapshots()
          .listen(_handleLinkedUserUpdate);
    } catch (e) {
      debugPrint('❌ Guardian SOS listener failed: $e');
    }
  }

  void _handleLinkedUserUpdate(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final deviceStatus = data?['deviceStatus'] as Map<String, dynamic>?;
    final batteryLevelRaw = deviceStatus?['batteryLevel'];
    final parsedBattery = batteryLevelRaw is int
        ? batteryLevelRaw
        : (batteryLevelRaw is num ? batteryLevelRaw.round() : null);
    final isLowBattery = deviceStatus?['isLowBattery'] == true;
    final isCriticalBattery = deviceStatus?['isCriticalBattery'] == true;

    String? lowBatteryToken;
    if (isLowBattery && parsedBattery != null) {
      final severity = isCriticalBattery ? 'critical' : 'low';
      lowBatteryToken = '${severity}_${snapshot.id}_$parsedBattery';
    }

    if (mounted) {
      setState(() {
        _userBatteryLevel = parsedBattery == null
            ? null
            : parsedBattery.clamp(0, 100);
        _isLowBattery = isLowBattery;
        _isCriticalBattery = isCriticalBattery;
      });
    }

    if (isLowBattery && lowBatteryToken != null && mounted) {
      if (_lastLowBatteryToken != lowBatteryToken) {
        _lastLowBatteryToken = lowBatteryToken;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _userBatteryLevel == null
                  ? 'Warning: linked user battery is low.'
                  : 'Warning: linked user battery is low ($_userBatteryLevel%).',
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }

    final sosData = data?['sosAlert'] as Map<String, dynamic>?;
    if (sosData == null) {
      if (mounted) {
        setState(() => _sosActive = false);
      }
      return;
    }

    final isActive = sosData['active'] == true;
    if (!isActive) {
      if (mounted) {
        setState(() => _sosActive = false);
      }
      return;
    }

    final message =
        (sosData['message'] as String?) ?? 'Emergency alert triggered by user.';
    final triggeredAt = sosData['triggeredAt'];
    String? timeLabel;
    String token;

    if (triggeredAt is Timestamp) {
      final dt = triggeredAt.toDate();
      timeLabel =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      token = 'ts_${triggeredAt.millisecondsSinceEpoch}';
    } else {
      token =
          (sosData['clientTriggeredAt'] as String?) ??
          DateTime.now().toIso8601String();
    }

    if (mounted) {
      setState(() {
        _sosActive = true;
        _sosMessage = message;
        _sosTimeLabel = timeLabel;
      });
    }

    if (_lastSosToken != token && mounted) {
      _lastSosToken = token;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS received from linked user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acknowledgeSos() async {
    if (_linkedUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_linkedUserId)
          .set({
            'sosAlert': {
              'active': false,
              'acknowledged': true,
              'acknowledgedAt': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _sosActive = false);
      }
    } catch (e) {
      debugPrint('❌ SOS acknowledge failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        title: Text(
          "Vision Mate",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 35,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GuardianProfileScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        // Isse card screen ke center mein rahega
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              // ✅ White box ki height ko munasib rakha hai (Not too big)
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
              ),
              child: Column(
                mainAxisSize: MainAxisSize
                    .min, // ✅ Card sirf content ke mutabiq jagah lega
                children: [
                  if (_isLowBattery)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isCriticalBattery
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isCriticalBattery
                              ? const Color(0xFFE57373)
                              : const Color(0xFFFFB74D),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.battery_alert_rounded,
                            color: _isCriticalBattery
                                ? const Color(0xFFC62828)
                                : const Color(0xFFE65100),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userBatteryLevel == null
                                  ? (_isCriticalBattery
                                        ? 'Critical battery warning for linked user.'
                                        : 'Low battery warning for linked user.')
                                  : (_isCriticalBattery
                                        ? 'Critical battery warning: user is at $_userBatteryLevel%. Device may shut down soon.'
                                        : 'Low battery warning: user is at $_userBatteryLevel%.'),
                              style: GoogleFonts.inter(
                                color: _isCriticalBattery
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFFE65100),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD8E2FF)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.battery_std_rounded,
                          color: (_userBatteryLevel ?? 100) <= 20
                              ? Colors.red
                              : Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _userBatteryLevel == null
                              ? 'User Battery: --'
                              : 'User Battery: $_userBatteryLevel%',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B2E58),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_sosActive)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_rounded,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _sosTimeLabel == null
                                    ? 'SOS ALERT'
                                    : 'SOS ALERT • $_sosTimeLabel',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _sosMessage,
                            style: GoogleFonts.inter(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NavigateUserScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.navigation_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('OPEN USER MAP'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: _acknowledgeSos,
                                child: const Text('MARK SAFE'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),

                  // Top Illustration Icon
                  const Icon(
                    Icons.accessibility_new_rounded,
                    size: 130,
                    color: Colors.black,
                  ),

                  const SizedBox(height: 50),

                  // ✅ MANAGE FACES BUTTON
                  _buildDashboardButton(
                    text: "MANAGE FACES",
                    icon: Icons.face_retouching_natural,
                    color: brandYellow,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageFacesScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ✅ NAVIGATE USER BUTTON
                  _buildDashboardButton(
                    text: "NAVIGATE USER",
                    icon: Icons.send_rounded,
                    color: brandYellow,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NavigateUserScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dashboard Button Helper
  Widget _buildDashboardButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 65, // Standard button height
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: Colors.black, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
