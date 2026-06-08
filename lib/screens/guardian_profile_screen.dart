import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'change_password_screen.dart';

class GuardianProfileScreen extends StatefulWidget {
  const GuardianProfileScreen({super.key});

  @override
  State<GuardianProfileScreen> createState() => _GuardianProfileScreenState();
}

class _GuardianProfileScreenState extends State<GuardianProfileScreen> {
  late Future<Map<String, dynamic>> _guardianDataFuture;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _guardianDataFuture = _fetchGuardianData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchGuardianData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'error': 'Not logged in'};

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) return doc.data() ?? {};
      return {'error': 'Guardian document not found'};
    } catch (e) {
      return {'error': 'Failed to fetch data: ${e.toString()}'};
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final newEmail = _emailController.text.trim();
      final newName = _nameController.text.trim();
      final oldEmail = user.email ?? '';

      // Update name immediately
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'name': newName},
      );

      // If email changed, ensure uniqueness then send verification
      if (newEmail != oldEmail && newEmail.isNotEmpty) {
        final emailQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: newEmail)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty &&
            emailQuery.docs.first.id != user.uid) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This email is already in use by another account'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        try {
          await user.verifyBeforeUpdateEmail(newEmail);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Name updated! Verification email sent to $newEmail.\nEmail will update after you verify.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        } catch (e) {
          if (e.toString().contains('requires-recent-login')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please logout and login again to change email'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          rethrow;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 5),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            suffixIcon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Vision Mate",
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _guardianDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Text('Failed to load profile', style: GoogleFonts.inter()),
            );
          }

          final data = snapshot.data!;
          if (data.containsKey('error')) {
            return Center(
              child: Text(data['error'] ?? 'Error', style: GoogleFonts.inter()),
            );
          }

          if (!_dataLoaded) {
            _nameController.text = data['name'] ?? '';
            _emailController.text = data['email'] ?? '';
            _dataLoaded = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: Icon(Icons.account_circle, size: 120, color: darkBlue),
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: darkBlue, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: darkBlue,
                        child: Text(
                          "PROFILE INFORMATION",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEditableField(
                              label: 'Name',
                              controller: _nameController,
                            ),
                            const SizedBox(height: 15),
                            _buildEditableField(
                              label: 'Email',
                              controller: _emailController,
                            ),
                            const SizedBox(height: 25),
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ChangePasswordScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.lock,
                                  color: darkBlue,
                                  size: 20,
                                ),
                                label: Text(
                                  "CHANGE PASSWORD",
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "UPDATE PROFILE",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      "LOGOUT",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
