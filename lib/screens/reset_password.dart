import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Apni login screen ka sahi import yahan check karlein
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final bool isFromProfile;
  final String? email;
  final bool isEmailVerified; // Add this flag

  const ResetPasswordScreen({
    super.key,
    this.isFromProfile = false,
    this.email,
    this.isEmailVerified = false,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Vision Mate Consistent Theme Color
    const Color darkBlue = Color(0xFF1B2E58);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              // ✅ Logo Section
              Center(
                child: SvgPicture.asset('assets/svg/logo.svg', height: 100),
              ),
              const SizedBox(height: 40),

              Text(
                'Reset Password',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Set your new password to secure your account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),

              // ✅ New Password Field
              _buildPasswordField(
                'New Password',
                _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew),
                _newPasswordController,
              ),
              const SizedBox(height: 20),

              // ✅ Confirm Password Field
              _buildPasswordField(
                'Confirm Password',
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
                _confirmPasswordController,
              ),

              const SizedBox(height: 50),

              // ✅ UPDATE BUTTON WITH SMART NAVIGATION
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    final newPassword = _newPasswordController.text.trim();
                    final confirmPassword = _confirmPasswordController.text
                        .trim();

                    // Validation
                    if (newPassword.isEmpty || confirmPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (newPassword.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password must be at least 6 characters',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (newPassword != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passwords do not match'),
                          backgroundColor: Colors.red,
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
                          child: CircularProgressIndicator(color: darkBlue),
                        ),
                      );

                      if (widget.isFromProfile) {
                        // Profile flow - user is logged in, update password directly
                        User? currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null) {
                          await currentUser.updatePassword(newPassword);
                        }
                      } else if (widget.isEmailVerified) {
                        // Forgot password flow with email verified via OTP
                        // User is already logged in, so we can directly update password
                        User? currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null) {
                          // User is logged in - directly update password after OTP verification
                          await currentUser.updatePassword(newPassword);
                        } else {
                          // User is not logged in - need to use different approach
                          // This shouldn't happen from change_password_screen, but handle it
                          if (widget.email != null) {
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: widget.email!,
                            );
                          }
                        }
                      } else {
                        // Regular forgot password flow - send reset link
                        if (widget.email != null) {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: widget.email!,
                          );
                        }
                      }

                      // Hide loading
                      Navigator.pop(context);

                      // Success Message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            widget.isFromProfile
                                ? "Password Updated Successfully!"
                                : widget.isEmailVerified
                                ? "Password has been set successfully!"
                                : "Password reset link sent to ${widget.email}. Please check your email.",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // SMART NAVIGATION LOGIC
                      await Future.delayed(const Duration(milliseconds: 1500));

                      if (widget.isFromProfile) {
                        // Profile se aaya hai toh Dashboard par wapis jayein
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      } else {
                        // Forgot Password flow se aaya hai toh Login par jayein
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignInScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      // Hide loading
                      Navigator.pop(context);

                      String errorMessage = 'Failed to update password';
                      if (e.code == 'weak-password') {
                        errorMessage = 'Password is too weak';
                      } else if (e.code == 'requires-recent-login') {
                        errorMessage = 'Please login again to change password';
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      // Hide loading
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('An error occurred. Please try again'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'UPDATE PASSWORD',
                    style: GoogleFonts.inter(
                      fontSize: 18,
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

  // Password Field Helper
  Widget _buildPasswordField(
    String label,
    bool obscure,
    VoidCallback onToggle,
    TextEditingController controller,
  ) {
    const Color darkBlue = Color(0xFF1B2E58);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: '********',
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: darkBlue,
              ),
              onPressed: onToggle,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: darkBlue, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
