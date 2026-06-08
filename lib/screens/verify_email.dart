import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'reset_password.dart'; // Name check karlein apni file ka
import '../config/email_config.dart';

class VerifyEmailScreen extends StatefulWidget {
  final bool isFromProfile;
  final String email;
  final String? correctOtp;
  final bool isFromForgotPassword; // Add this flag

  const VerifyEmailScreen({
    super.key,
    this.isFromProfile = false,
    required this.email,
    this.correctOtp,
    this.isFromForgotPassword = false,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // Vision Mate Theme Color
  final Color darkBlue = const Color(0xFF1B2E58);

  // OTP Controllers
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Resend OTP timer
  late String _currentOtp;
  int _resendTimer = 60;
  bool _canResend = false;
  bool _isSendingOtp = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.correctOtp ?? '';
    if (widget.isFromForgotPassword) {
      _startTimer();
    }
  }

  void _startTimer() {
    _resendTimer = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    if (!_canResend || !widget.isFromForgotPassword || _isSendingOtp) return;

    setState(() => _isSendingOtp = true);

    String newOtp = (Random().nextInt(900000) + 100000).toString();

    try {
      // Validate configuration first
      if (!EmailConfig.isConfigured()) {
        throw Exception('❌ Email configuration incomplete!');
      }

      debugPrint('📧 Resending password reset OTP: $newOtp to ${widget.email}');

      final Map<String, dynamic> payload = {
        'sender': {
          'name': EmailConfig.senderName,
          'email': EmailConfig.senderEmail,
        },
        'to': [
          {'email': widget.email},
        ],
        'subject': 'Password Reset Code - Vision Mate',
        'htmlContent':
            '''
          <h2>Password Reset Request</h2>
          <p>We received a request to reset your password. Use the code below:</p>
          <h1 style="color: #1B2E58; letter-spacing: 5px;">$newOtp</h1>
          <p>This code is valid for 15 minutes. Do not share this code with anyone.</p>
          <p>If you didn't request a password reset, please ignore this email.</p>
          <p>Thanks,<br><strong>Vision Mate Team</strong></p>
        ''',
      };

      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(EmailConfig.brevoApiUrl),
              headers: {
                'api-key': EmailConfig.brevoApiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        // Try fallback endpoint
        debugPrint('⚠️ Primary endpoint failed, trying fallback...');
        response = await http
            .post(
              Uri.parse(EmailConfig.brevoFallbackUrl),
              headers: {
                'api-key': EmailConfig.brevoApiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));
      }

      debugPrint('📬 Resend Response: ${response.statusCode}');

      if (response.statusCode == 201) {
        setState(() => _currentOtp = newOtp);
        debugPrint('✅ New OTP sent to email: $newOtp');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New OTP sent to ${widget.email}'),
            backgroundColor: Colors.green,
          ),
        );
        _startTimer();
      } else {
        debugPrint('❌ Failed to resend: ${response.body}');
        debugPrint('🔐 FALLBACK OTP: $newOtp');

        // Show error details
        String errorMsg = 'Email failed';
        if (response.statusCode == 401) {
          errorMsg = '❌ API Key invalid/expired!';
        } else if (response.statusCode == 403) {
          errorMsg = '❌ Sender email not verified in Brevo!';
        }

        // Email failed but still update OTP for testing
        setState(() => _currentOtp = newOtp);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMsg Testing OTP: $newOtp'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        _startTimer();
      }
    } catch (e) {
      // Network error - still update OTP for testing
      setState(() => _currentOtp = newOtp);
      debugPrint('❌ Exception resending OTP: $e');
      debugPrint('🔐 FALLBACK OTP: $newOtp');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error. Testing OTP: $newOtp'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      _startTimer();
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: darkBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              Center(
                child: SvgPicture.asset('assets/svg/logo.svg', height: 100),
              ),
              const SizedBox(height: 40),
              Text(
                'Verify Email',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Enter the 6-digit code sent to',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 40),

              // ✅ OTP Boxes Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _otpBox(context, index)),
              ),

              const SizedBox(height: 20),
              // Resend OTP button (always visible with timer)
              TextButton(
                onPressed:
                    (_canResend &&
                        widget.isFromForgotPassword &&
                        !_isSendingOtp)
                    ? _resendOtp
                    : null,
                child: _isSendingOtp
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _canResend
                            ? 'Resend Code'
                            : 'Resend in $_resendTimer sec',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _canResend ? darkBlue : Colors.grey,
                        ),
                      ),
              ),
              const SizedBox(height: 50),

              // ✅ VERIFY BUTTON WITH SMART NAVIGATION
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    // Get entered OTP from all controllers
                    String enteredOtp = _otpControllers
                        .map((controller) => controller.text)
                        .join();

                    // Validate OTP length
                    if (enteredOtp.length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter complete 6-digit code'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Verify OTP if correctOtp is provided
                    if (widget.correctOtp != null &&
                        enteredOtp != _currentOtp) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid code. Please try again'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // OTP verified, navigate to reset password
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResetPasswordScreen(
                          isFromProfile: widget.isFromProfile,
                          email: widget.email,
                          isEmailVerified:
                              true, // Mark email as verified via OTP
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'VERIFY',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ OTP Box Helper with Auto-Focus Logic
  Widget _otpBox(BuildContext context, int index) {
    return Container(
      width: 45,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        maxLength: 1,
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: "",
        ),
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
