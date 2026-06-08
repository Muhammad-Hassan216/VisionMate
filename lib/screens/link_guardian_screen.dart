import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verify_guardian_otp.dart';
import 'user_main_screen.dart';
import '../config/email_config.dart';

class LinkGuardianScreen extends StatefulWidget {
  const LinkGuardianScreen({super.key});
  @override
  State<LinkGuardianScreen> createState() => _LinkGuardianScreenState();
}

class _LinkGuardianScreenState extends State<LinkGuardianScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    String emailAddress = _emailController.text.trim();

    if (emailAddress.isEmpty || !emailAddress.contains('@')) {
      _showMessage("Please enter a valid Email", Colors.red);
      return;
    }

    // Prevent self-linking and verify target is a guardian
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage("Session expired. Please login again.", Colors.red);
      return;
    }

    if (user.email != null &&
        user.email!.toLowerCase() == emailAddress.toLowerCase()) {
      _showMessage("You cannot link your own email as guardian.", Colors.red);
      return;
    }

    try {
      // If already linked, skip this screen
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && (userDoc.data()?['isLinked'] == true)) {
        _showMessage("Guardian already linked. Redirecting...", Colors.green);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserMainScreen()),
        );
        return;
      }

      // Check entered email belongs to a guardian
      final guardianQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailAddress)
          .limit(1)
          .get();
      if (guardianQuery.docs.isEmpty) {
        _showMessage("No account found with this email.", Colors.red);
        return;
      }

      final guardianData = guardianQuery.docs.first.data();
      final role = guardianData['role'];

      // Check if the guardian email is actually registered as a guardian
      if (role != 'guardian') {
        _showMessage(
          "Please enter a guardian's email, not a user email.",
          Colors.red,
        );
        return;
      }

      // Prevent duplicate email: user email cannot be same as guardian email
      // (guardian email must be unique to guardian account)
      if (user.email?.toLowerCase() == emailAddress.toLowerCase()) {
        _showMessage("You cannot link your own email as guardian.", Colors.red);
        return;
      }
    } catch (e) {
      _showMessage("Validation failed. Please try again.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    // 6-digit OTP
    String otpCode = (Random().nextInt(900000) + 100000).toString();

    try {
      debugPrint("Sending OTP: $otpCode to $emailAddress");

      // Validate API configuration first
      if (!EmailConfig.isConfigured()) {
        throw Exception('❌ Email configuration incomplete! API key not set.');
      }

      if (!EmailConfig.isSenderEmailValid()) {
        throw Exception('❌ Sender email invalid in configuration!');
      }

      // Send OTP via Brevo API
      final Map<String, dynamic> payload = {
        'sender': {
          'name': EmailConfig.senderName,
          'email': EmailConfig.senderEmail,
        },
        'to': [
          {'email': emailAddress},
        ],
        'subject': 'Guardian Link Authentication Code',
        'htmlContent':
            '''
            <h2>Guardian Link Authentication</h2>
            <p>To authenticate, please use the following One Time Password (OTP):</p>
            <h1 style="color: #1B2E58;">$otpCode</h1>
            <p>This OTP will be valid for 15 minutes. Do not share this OTP with anyone.</p>
            <p><strong>Vision Mate</strong> will never contact you about this email or ask for any login codes or links.</p>
            <p>Thanks for visiting Vision Mate!</p>
          ''',
      };

      http.Response response;

      try {
        debugPrint('📧 Attempting to send OTP via Brevo...');
        debugPrint('API URL: ${EmailConfig.brevoApiUrl}');
        debugPrint('Sender: ${EmailConfig.senderEmail}');

        response = await http
            .post(
              Uri.parse(EmailConfig.brevoApiUrl),
              headers: {
                'api-key': EmailConfig.brevoApiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint('⚠️ Brevo API failed. Trying fallback endpoint...');
        debugPrint('Error: $e');

        // Fallback to sendinblue domain if brevo hostname fails
        response = await http
            .post(
              Uri.parse(EmailConfig.brevoFallbackUrl),
              headers: {
                'api-key': EmailConfig.brevoApiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));
      }

      debugPrint('📬 Brevo Response Status: ${response.statusCode}');
      debugPrint('📬 Brevo Response Body: ${response.body}');

      // Check response
      if (response.statusCode != 201) {
        debugPrint('❌ Email send failed with status: ${response.statusCode}');

        // Parse error from response
        try {
          final errorBody = jsonDecode(response.body);
          debugPrint('Error details: $errorBody');
        } catch (e) {
          debugPrint('Could not parse error body');
        }

        // Status code breakdown
        switch (response.statusCode) {
          case 400:
            throw Exception('⚠️ Bad Request - Check email format or content');
          case 401:
            throw Exception('⚠️ Unauthorized - API Key invalid or expired!');
          case 403:
            throw Exception('⚠️ Forbidden - Check sender email is verified');
          case 429:
            throw Exception('⚠️ Rate limited - Too many requests');
          case 500:
            throw Exception('⚠️ Brevo server error - Try again later');
          default:
            throw Exception('⚠️ Email service failed (${response.statusCode})');
        }
      }

      debugPrint('✅ OTP sent successfully!');
      if (!mounted) return;
      _showMessage("OTP Sent to $emailAddress", Colors.green);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VerifyGuardianOtpScreen(email: emailAddress, correctOtp: otpCode),
        ),
      );
    } catch (e) {
      debugPrint("❌ Email sending error: $e");
      debugPrint('🔐 FALLBACK OTP: $otpCode');

      if (!mounted) return;
      _showMessage(
        "⚠️ Email service failed. Testing mode: $otpCode",
        Colors.orange,
      );

      // Allow testing even if email fails
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VerifyGuardianOtpScreen(email: emailAddress, correctOtp: otpCode),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    return Scaffold(
      backgroundColor: darkBlue,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.16,
            color: Colors.white,
            child: Center(
              child: SvgPicture.asset('assets/svg/logo.svg', height: 70),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    const SizedBox(height: 50),
                    Text(
                      'LINK GUARDIAN',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 60),
                    TextField(
                      controller: _emailController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Enter Guardian Email',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: darkBlue),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 65,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'SEND OTP',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
