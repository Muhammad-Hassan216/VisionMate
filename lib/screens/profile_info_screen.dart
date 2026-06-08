import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
// ✅ Change Password screen ka import lazmi karein
import 'change_password_screen.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  late Future<Map<String, dynamic>> _userDataFuture;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _userDataFuture = _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'error': 'Not logged in'};
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data() ?? {};
      } else {
        return {'error': 'User document not found'};
      }
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
      if (user == null) {
        throw Exception('User not logged in');
      }

      final newEmail = _emailController.text.trim();
      final newName = _nameController.text.trim();
      final oldEmail = user.email ?? '';

      // 1. Always update name in Firestore (no verification needed)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'name': newName},
      );

      // 2. If email changed, check if email already exists in Firestore
      if (newEmail != oldEmail && newEmail.isNotEmpty) {
        // Check if this email is already used by someone else
        final emailQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: newEmail)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty &&
            emailQuery.docs.first.id != user.uid) {
          // Email already exists for another user
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
          // Send verification email to new email address
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
            if (!mounted) return;
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

      // No email change - just name update
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
          icon: const Icon(Icons.arrow_back_ios, color: darkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Vision Mate",
          style: GoogleFonts.inter(
            color: darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Icon(Icons.account_circle, size: 120, color: darkBlue),
            ),
            const SizedBox(height: 30),

            FutureBuilder<Map<String, dynamic>>(
              future: _userDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: darkBlue),
                  );
                }

                if (snapshot.hasError ||
                    (snapshot.data?.containsKey('error') ?? false)) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      snapshot.data?['error'] ?? 'Failed to load profile',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final userData = snapshot.data ?? {};
                final name = userData['name'] ?? 'No Name';
                final email = userData['email'] ?? 'No Email';

                // Set controller text only once when data is first loaded
                if (!_dataLoaded && name != 'No Name' && email != 'No Email') {
                  _nameController.text = name;
                  _emailController.text = email;
                  _dataLoaded = true;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 15,
                          ),
                          decoration: const BoxDecoration(
                            color: darkBlue,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'PROFILE INFORMATION',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("Name"),
                              _buildEditableField(_nameController, "Name"),
                              const SizedBox(height: 20),
                              _buildFieldLabel("Email"),
                              _buildEditableField(_emailController, "Email"),
                              const SizedBox(height: 25),

                              // ✅ CHANGE PASSWORD LINK (Functional)
                              Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    // Navigator to Change Password Screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
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
                                      color: darkBlue,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // ✅ UPDATE PROFILE BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'UPDATE PROFILE',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // ✅ LOGOUT BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'LOGOUT',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 5),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEditableField(TextEditingController controller, String label) {
    const Color darkBlue = Color(0xFF1B2E58);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkBlue),
        ),
        suffixIcon: const Icon(Icons.edit, color: Colors.blue, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
      ),
    );
  }
}
