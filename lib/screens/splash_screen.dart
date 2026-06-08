import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
// Login screen ka import yahan zaroori hai:
import 'login_screen.dart';

class VisionMateSplash extends StatefulWidget {
  // ... baaki pura code jo maine pehle diya tha

  const VisionMateSplash({super.key});

  @override
  State<VisionMateSplash> createState() => _VisionMateSplashState();
}

class _VisionMateSplashState extends State<VisionMateSplash> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              SizedBox(
                height: 240,
                width: 240,
                child: SvgPicture.asset(
                  'assets/svg/logo.svg',
                  height: 240,
                  width: 240,
                  placeholderBuilder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                  // Fallback if SVG fails to load
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 50),
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 54,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: 0,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Vision',
                          style: TextStyle(color: darkBlue),
                        ),
                        TextSpan(
                          text: 'M',
                          style: TextStyle(color: brandYellow),
                        ),
                        TextSpan(
                          text: 'ate',
                          style: TextStyle(color: darkBlue),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -35,
                    bottom: 0,
                    child: SvgPicture.asset(
                      'assets/svg/mic.svg',
                      height: 38,
                      width: 38,
                      colorFilter: const ColorFilter.mode(
                        brandYellow,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'YOUR VOICE. YOUR VISION.',
                style: GoogleFonts.inter(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: brandYellow,
                  letterSpacing: 0,
                  height: 1.0,
                ),
              ),
              const Spacer(flex: 3),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(brandYellow),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading...',
                style: GoogleFonts.inter(fontSize: 16, color: darkBlue),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
