import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Face Registration screen ka import lazmi karein
import 'face_registration_screen.dart';

class ManageFacesEmptyScreen extends StatelessWidget {
  const ManageFacesEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1B2E58);
    const Color brandYellow = Color(0xFFFFBF55);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "MANAGE FACES",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Spacer(flex: 2),

          // ✅ Empty State Illustration
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 150,
                      color: Colors.grey,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                Text(
                  "No faces registered yet.",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),

          // ✅ ADD FIRST FACE BUTTON (Navigator Added)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  // ✅ Navigator push to FaceRegistrationScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FaceRegistrationScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "+ ADD FIRST FACE",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
