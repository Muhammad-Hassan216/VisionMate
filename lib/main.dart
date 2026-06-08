import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// 1. Firebase ke zaroori imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// Folder ka path
import 'package:flutter_application_1/screens/splash_screen.dart';

// 2. main() ko async banayein
void main() async {
  // 3. Flutter framework ko initialize karein
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Firebase ko initialize karein
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vision Mate',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const VisionMateSplash(),
    );
  }
}
