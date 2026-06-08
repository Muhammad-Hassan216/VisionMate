# VisionMate

VisionMate is an assistive Flutter mobile application designed for visually impaired users. It combines object detection, voice guidance, haptic feedback, location saving, and emergency SOS support in a single accessible experience.

## Key Features

- Object detection with continuous camera monitoring
- Text-to-speech alerts and audio guidance
- Haptic feedback for immediate physical notification
- Live Google Maps integration with saved favorite locations
- Firebase authentication, Firestore sync, and local SQLite caching
- Emergency SOS and guardian alert support
- Voice-enabled location naming and save flow

## Technologies

- Flutter
- Firebase (Auth, Firestore)
- Camera
- tflite_flutter
- Flutter TTS
- Google Maps Flutter
- Geolocator
- Permission Handler
- SQLite / sqflite

## Setup

1. Install Flutter and configure your development environment.
2. Open the project folder in VS Code or Android Studio.
3. Run:
   ```bash
   flutter pub get
   flutter run
   ```
4. Make sure to configure Firebase in `lib/firebase_options.dart` and platform-specific files.

## Notes

- Keep object detection always enabled for accessibility.
- Ensure camera, location, microphone, and storage permissions are granted.
- This project includes `assets/models/` and sample datasets for vision tasks.

## Repository

This repository is prepared for GitHub push to `https://github.com/Muhammad-Hassan216/VisionMate`.
