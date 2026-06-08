import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Step 2: Firestore import add kiya
import 'login_screen.dart';

class GuardianSignUpScreen extends StatefulWidget {
  const GuardianSignUpScreen({super.key});

  @override
  State<GuardianSignUpScreen> createState() => _GuardianSignUpScreenState();
}

class _GuardianSignUpScreenState extends State<GuardianSignUpScreen> {
  String? _gender = "Male";
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("Passwords do not match!", Colors.red);
      return;
    }

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      _showSnackBar("Please fill all fields!", Colors.red);
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Create User in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          )
          .timeout(const Duration(seconds: 15));

      // 2. Save User Role and Info in Firestore ✅
      // Ye part Guardian ki pehchan save karega
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': 'guardian', // ✅ Role set as guardian
            'gender': _gender,
            'createdAt': DateTime.now(),
          });

      if (!mounted) return;
      Navigator.pop(context);

      _showSnackBar("Guardian Account Created Successfully!", Colors.green);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar(
        e.toString().contains("timeout")
            ? "Network Timeout. Check Internet!"
            : e.toString(),
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.account_circle,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: brandYellow,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      'GUARDIAN PROFILE INFORMATION',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                _buildTextField("Enter your Name", _nameController),
                const SizedBox(height: 15),
                _buildTextField("Enter your Email", _emailController),
                const SizedBox(height: 15),
                _buildPasswordField(
                  "Enter your Password",
                  _obscurePassword,
                  _passwordController,
                  () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 15),
                _buildPasswordField(
                  "Confirm Password",
                  _obscureConfirmPassword,
                  _confirmPasswordController,
                  () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),

                const SizedBox(height: 25),
                _buildGenderSection(),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'SIGN UP',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String hint,
    bool obscure,
    TextEditingController controller,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.help_outline, color: Colors.white, size: 20),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _genderTile("Male")),
            const SizedBox(width: 15),
            Expanded(child: _genderTile("Female")),
          ],
        ),
      ],
    );
  }

  Widget _genderTile(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        value: title,
        groupValue: _gender,
        activeColor: const Color(0xFF1B2E58),
        onChanged: (value) => setState(() => _gender = value.toString()),
      ),
    );
  }
}
