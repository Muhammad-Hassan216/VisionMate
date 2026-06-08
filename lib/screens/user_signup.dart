import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firestore import
import 'login_screen.dart';

class UserSignUpScreen extends StatefulWidget {
  const UserSignUpScreen({super.key});

  @override
  State<UserSignUpScreen> createState() => _UserSignUpScreenState();
}

class _UserSignUpScreenState extends State<UserSignUpScreen> {
  String? _gender = "Male";
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ✅ Firebase Sign Up Function with Firestore Role
  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar("Passwords do not match!");
      return;
    }

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      _showErrorSnackBar("Please fill all fields!");
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Firebase Auth mein account create karein
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Firestore mein User ka Role "user" save karein
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': 'user', // ✅ Isse login ke waqt blind user ki pehchan hogi
            'gender': _gender,
            'createdAt': DateTime.now(),
          });

      if (!mounted) return;
      Navigator.pop(context); // Dialog band karein

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User Account Created Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Login screen par wapas bhej dein
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar(e.message ?? "Registration failed");
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar("An error occurred. Please try again.");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: darkBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const Icon(Icons.account_circle, size: 100, color: Colors.white),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandYellow,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'USER PROFILE INFORMATION',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 30),
              _buildTextField("Enter your Name", _nameController),
              const SizedBox(height: 20),
              _buildTextField("Enter your Email", _emailController),
              const SizedBox(height: 20),

              _buildPasswordField(
                "Enter your Password",
                _obscurePassword,
                _passwordController,
                () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 20),

              _buildPasswordField(
                "Confirm Password",
                _obscureConfirmPassword,
                _confirmPasswordController,
                () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),

              const SizedBox(height: 20),
              _buildGenderSection(),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'SIGN UP',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String hint,
    bool isObscure,
    TextEditingController controller,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Gender",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.help_outline, color: Colors.white, size: 18),
          ],
        ),
        Row(
          children: [
            Radio(
              value: "Male",
              groupValue: _gender,
              onChanged: (v) => setState(() => _gender = v.toString()),
              activeColor: Colors.white,
            ),
            const Text("Male", style: TextStyle(color: Colors.white)),
            const SizedBox(width: 20),
            Radio(
              value: "Female",
              groupValue: _gender,
              onChanged: (v) => setState(() => _gender = v.toString()),
              activeColor: Colors.white,
            ),
            const Text("Female", style: TextStyle(color: Colors.white)),
          ],
        ),
      ],
    );
  }
}
