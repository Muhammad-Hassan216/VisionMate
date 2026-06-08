import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'forgot_password.dart';
import 'role_selection_screen.dart';
import 'user_main_screen.dart';
import 'link_guardian_screen.dart';
// ✅ Is file ka import lazmi check karein (Guardian wali screen)
import 'guardian_link_screen.dart';
import 'guardian_linked_dashboard.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Firebase Auth Login
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Firestore se Role check karna ✅
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // Loading band karein

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final String role = data['role'] ?? '';
        final bool isLinked = data['isLinked'] == true;

        // 3. UPDATED LOGIC: Role-Based Navigation ✅
        if (role == 'user') {
          // If already linked, go directly to main screen
          if (isLinked) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserMainScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LinkGuardianScreen(),
              ),
            );
          }
        } else if (role == 'guardian') {
          // Guardian login - check if already linked to a user
          final guardianEmail = userCredential.user!.email;
          final linkedUserQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('guardianEmail', isEqualTo: guardianEmail)
              .where('isLinked', isEqualTo: true)
              .limit(1)
              .get();

          if (linkedUserQuery.docs.isNotEmpty) {
            // Guardian already linked - go to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const GuardianLinkedDashboard(),
              ),
            );
          } else {
            // Guardian not linked yet - show waiting screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const GuardianLinkScreen(),
              ),
            );
          }
        }
      } else {
        _showSnackBar("User data not found!", Colors.orange);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar(e.message ?? "Login Failed", Colors.red);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Center(
                child: SvgPicture.asset(
                  'assets/svg/logo.svg',
                  height: 80,
                  placeholderBuilder: (context) =>
                      const Icon(Icons.visibility, size: 80, color: darkBlue),
                ),
              ),
              const SizedBox(height: 40),

              _buildLabel('Email'),
              const SizedBox(height: 8),
              _buildTextField(_emailController, 'Enter your Email', false),

              const SizedBox(height: 25),

              _buildLabel('Password'),
              const SizedBox(height: 8),
              _buildPasswordField(),

              const SizedBox(height: 40),

              _buildButton('LOGIN', brandYellow, Colors.black, _login),

              const SizedBox(height: 30),

              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                ),
                child: Text(
                  'FORGOTTEN ACCOUNT?',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              _buildButton('CREATE NEW ACCOUNT', darkBlue, Colors.white, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectionScreen(),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    bool obscure,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: 'Enter your password',
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
      ),
    );
  }

  Widget _buildButton(
    String text,
    Color bgColor,
    Color textColor,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
