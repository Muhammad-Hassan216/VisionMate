import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Tasalli kar lein ke files ke naam sahi hain
import 'user_signup.dart';
import 'guardian_signup.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Back button function
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: darkBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: SvgPicture.asset(
                  'assets/svg/logo.svg',
                  height: 80,
                  width: 80,
                  // Agar logo file missing ho toh ye icon dikhayega (No Crash)
                  placeholderBuilder: (context) =>
                      const Icon(Icons.visibility, size: 80, color: darkBlue),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'WHO ARE YOU?',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),

              // ✅ User Button
              _buildRoleButton(
                context,
                title: 'Sign Up as User',
                iconPath: 'assets/svg/user.svg',
                fallbackIcon: Icons.person,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserSignUpScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),

              // ✅ Guardian Button
              _buildRoleButton(
                context,
                title: 'Sign Up as Guardian',
                iconPath: 'assets/svg/link.svg',
                fallbackIcon: Icons.security,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GuardianSignUpScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Improved Role Button Widget Helper
  Widget _buildRoleButton(
    BuildContext context, {
    required String title,
    required String iconPath,
    required IconData fallbackIcon,
    required VoidCallback onTap,
  }) {
    const Color darkBlue = Color(0xFF1B2E58);

    return Material(
      // Added Material for better splash effect
      color: darkBlue,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              // Safe SVG Loader
              SvgPicture.asset(
                iconPath,
                height: 100,
                width: 100,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                // Agar SVG file assets mein nahi hai, toh fallbackIcon show hoga
                placeholderBuilder: (context) =>
                    Icon(fallbackIcon, size: 100, color: Colors.white),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
