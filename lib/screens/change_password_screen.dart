import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'verify_email.dart';
import '../config/email_config.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // Password visibility controllers
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureRetype = true;
  bool _isLoading = false;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _retypePasswordController =
      TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final retypePassword = _retypePasswordController.text.trim();

    // Validation
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        retypePassword.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    if (newPassword.length < 6) {
      _showError("New password must be at least 6 characters");
      return;
    }

    if (newPassword != retypePassword) {
      _showError("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("User not logged in");
        return;
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      if (!mounted) return;
      _showSuccess("Password changed successfully!");

      // Clear fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _retypePasswordController.clear();

      // Go back
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Failed to change password';
      if (e.code == 'wrong-password') {
        errorMsg = 'Current password is incorrect';
      } else if (e.code == 'requires-recent-login') {
        errorMsg = 'Please logout and login again to change password';
      } else if (e.code == 'weak-password') {
        errorMsg = 'New password is too weak';
      }
      _showError(errorMsg);
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _sendOtpForPasswordReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showError("User not logged in");
      return;
    }

    final email = user.email!;

    setState(() => _isLoading = true);

    // Generate 6-digit OTP
    String otpCode = (Random().nextInt(900000) + 100000).toString();
    debugPrint("🔐 Generated OTP: $otpCode for $email");

    try {
      // Send OTP via Brevo API
      final Map<String, dynamic> payload = {
        'sender': {
          'name': EmailConfig.senderName,
          'email': EmailConfig.senderEmail,
        },
        'to': [
          {'email': email},
        ],
        'subject': 'Password Reset Code - Vision Mate',
        'htmlContent':
            '''
          <h2>Password Reset Request</h2>
          <p>We received a request to reset your password. Use the code below:</p>
          <h1 style="color: #1B2E58; letter-spacing: 5px;">$otpCode</h1>
          <p>This code is valid for 15 minutes. Do not share this code with anyone.</p>
          <p>If you didn't request a password reset, please ignore this email.</p>
          <p>Thanks,<br><strong>Vision Mate Team</strong></p>
        ''',
      };

      final response = await http
          .post(
            Uri.parse(EmailConfig.brevoApiUrl),
            headers: {
              'api-key': EmailConfig.brevoApiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📧 Email API Response: ${response.statusCode}');
      debugPrint('📧 Response Body: ${response.body}');

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        // OTP sent successfully
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(
              email: email,
              correctOtp: otpCode,
              isFromProfile: true,
              isFromForgotPassword: true,
            ),
          ),
        );
      } else {
        // Email sending failed - but still show OTP for testing
        debugPrint('❌ Failed to send email: ${response.body}');

        // Navigate anyway with OTP shown in console
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email failed. Check console for OTP: $otpCode'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(
              email: email,
              correctOtp: otpCode,
              isFromProfile: true,
              isFromForgotPassword: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Exception sending OTP: $e');
      debugPrint('🔐 FALLBACK OTP (check console): $otpCode');

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Show error but still navigate with OTP for testing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email unavailable. Testing OTP: $otpCode'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyEmailScreen(
            email: email,
            correctOtp: otpCode,
            isFromProfile: true,
            isFromForgotPassword: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);

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
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              // ✅ Main Heading
              Text(
                'Change pasword',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 15),
              // ✅ Requirements Text
              Text(
                'Your password must be at least 6 characters and should include a combination of numbers, letters and special characters(!\$@%).',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: darkBlue.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),

              // ✅ Current Password Field
              _buildPasswordField(
                "Current password",
                _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent),
                _currentPasswordController,
              ),
              const SizedBox(height: 20),

              // ✅ New Password Field
              _buildPasswordField(
                "New password",
                _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew),
                _newPasswordController,
              ),
              const SizedBox(height: 20),

              // ✅ Re-type Password Field
              _buildPasswordField(
                "Re-type password",
                _obscureRetype,
                () => setState(() => _obscureRetype = !_obscureRetype),
                _retypePasswordController,
              ),

              const SizedBox(height: 25),

              // ✅ Forgot Password Link - Sends OTP directly to logged-in user's email
              TextButton(
                onPressed: _sendOtpForPasswordReset,
                child: Text(
                  "Forgot your password?",
                  style: GoogleFonts.inter(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // ✅ Change Password Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Change password',
                          style: GoogleFonts.inter(
                            fontSize: 20,
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
    );
  }

  // ✅ Password field helper with visibility toggle
  Widget _buildPasswordField(
    String hint,
    bool obscure,
    VoidCallback onToggle,
    TextEditingController controller,
  ) {
    const Color darkBlue = Color(0xFF1B2E58);
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBlue, width: 2),
        ),
      ),
    );
  }
}
