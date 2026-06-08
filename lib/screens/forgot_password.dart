import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: darkBlue, // Blue Background as per screenshot
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            Center(
              child: SvgPicture.asset(
                'assets/svg/logo.svg', // White version of logo if available
                height: 120,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Find your account',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your registered email address.',
              style: GoogleFonts.inter(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You will receive a password reset link via email.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white60),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter your email')),
                    );
                    return;
                  }

                  // Email validation
                  if (!email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid email'),
                      ),
                    );
                    return;
                  }

                  try {
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(color: brandYellow),
                      ),
                    );

                    // Send Firebase password reset link
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email,
                    );

                    Navigator.pop(context); // Hide loading

                    // Show success message
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Password reset link sent to $email.\nPlease check your email.',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );

                    // Navigate back to login screen
                    await Future.delayed(const Duration(seconds: 2));
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(),
                      ),
                      (route) => false,
                    );
                  } on FirebaseAuthException catch (e) {
                    Navigator.pop(context); // Hide loading
                    String errorMsg = 'Failed to send reset link';

                    if (e.code == 'user-not-found') {
                      errorMsg = 'No account found with this email';
                    } else if (e.code == 'invalid-email') {
                      errorMsg = 'Invalid email address';
                    } else if (e.code == 'too-many-requests') {
                      errorMsg = 'Too many requests. Please try again later';
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMsg),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    debugPrint('Error sending password reset link: $e');

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('An error occurred. Please try again'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'SEND RESET LINK',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
