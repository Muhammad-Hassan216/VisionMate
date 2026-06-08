import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_main_screen.dart';
import '../config/email_config.dart';

class VerifyGuardianOtpScreen extends StatefulWidget {
  final String email;
  final String correctOtp;

  const VerifyGuardianOtpScreen({
    super.key,
    required this.email,
    required this.correctOtp,
  });

  @override
  State<VerifyGuardianOtpScreen> createState() =>
      _VerifyGuardianOtpScreenState();
}

class _VerifyGuardianOtpScreenState extends State<VerifyGuardianOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  // Focus nodes taake backspace handle ho sake
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLinking = false;

  // Resend OTP ke liye
  late String _currentOtp;
  int _resendTimer = 60;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.correctOtp;
    _startTimer();
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
    if (!_canResend) {
      _showMsg('Please wait ${_resendTimer}s before resending', Colors.orange);
      return;
    }

    setState(() => _isLinking = true);
    String newOtp = (Random().nextInt(900000) + 100000).toString();

    try {
      // Validate configuration first
      if (!EmailConfig.isConfigured()) {
        throw Exception('❌ Email configuration incomplete!');
      }

      debugPrint('📧 Resending OTP: $newOtp to ${widget.email}');

      // Send OTP via Brevo API
      final Map<String, dynamic> payload = {
        'sender': {
          'name': EmailConfig.senderName,
          'email': EmailConfig.senderEmail,
        },
        'to': [
          {'email': widget.email},
        ],
        'subject': 'Guardian Link Authentication Code - Resent',
        'htmlContent':
            '''
            <h2>Guardian Link Authentication</h2>
            <p>Your new One Time Password (OTP) is:</p>
            <h1 style="color: #1B2E58;">$newOtp</h1>
            <p>This OTP will be valid for 15 minutes. Do not share this OTP with anyone.</p>
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
            .timeout(const Duration(seconds: 20));
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
            .timeout(const Duration(seconds: 20));
      }

      debugPrint('📬 Resend Response: ${response.statusCode}');

      if (response.statusCode == 201) {
        _showMsg('✅ New OTP sent to ${widget.email}', Colors.green);
        setState(() => _currentOtp = newOtp);
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

        _showMsg('$errorMsg Testing OTP: $newOtp', Colors.orange);
        setState(() => _currentOtp = newOtp);
        _startTimer();
      }
    } catch (e) {
      debugPrint('❌ Resend error: $e');
      debugPrint('🔐 FALLBACK OTP: $newOtp');
      _showMsg('⚠️ Email failed. Use: $newOtp', Colors.orange);
      setState(() => _currentOtp = newOtp);
      _startTimer();
    } finally {
      setState(() => _isLinking = false);
    }
  }

  Future<void> _verifyAndLink() async {
    String enteredOtp = _controllers.map((c) => c.text).join();

    if (enteredOtp.length < 6) {
      _showMsg("Please enter the full 6-digit code", Colors.orange);
      return;
    }

    if (enteredOtp != _currentOtp) {
      _showMsg("Invalid OTP! Please check your email.", Colors.red);
      return;
    }

    setState(() => _isLinking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMsg("User session expired. Please login again.", Colors.red);
        return;
      }

      // Firestore mein link save kar rahe hain
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'guardianEmail': widget.email,
            'isLinked': true,
            'linkedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      _showMsg("Guardian Linked Successfully!", Colors.green);

      // Redirect to Dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const UserMainScreen()),
        (route) => false,
      );
    } catch (e) {
      _showMsg("Database Error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: brandYellow,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            color: Colors.white,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: darkBlue),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Text(
                  'VERIFY CODE',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                        (index) => _otpBox(index, darkBlue),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Code sent to ${widget.email}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Resend OTP button
                    TextButton(
                      onPressed: _canResend ? _resendOtp : null,
                      child: Text(
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
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: _isLinking ? null : _verifyAndLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                        ),
                        child: _isLinking
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'LINK NOW',
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index, Color borderColor) {
    return Container(
      width: 45,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        onChanged: (v) {
          if (v.length == 1 && index < 5) {
            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
          } else if (v.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
        },
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: "",
        ),
      ),
    );
  }
}
