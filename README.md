# VisionMate

VisionMate is an assistive Flutter application built for visually impaired users. It combines AI-powered object detection, spoken guidance, haptic feedback, GPS navigation, emergency guardian support, and offline face recognition into one accessible and safety-focused experience.

## Project Overview

VisionMate helps blind and low-vision users move safely through real environments. The app uses the device camera to detect objects and obstacles, then provides spoken alerts and vibration feedback so users can understand surroundings without relying on eyesight.

The app also includes a guardian-linking system that allows a trusted person to monitor the user, receive SOS updates, and help save important locations.

## Key Features

- Live object detection through the camera feed
- Spoken alerts and direction guidance with `flutter_tts`
- Haptic feedback for immediate attention and safety
- Google Maps integration with real-time position and route display
- Favorite destination saving with voice-assisted naming
- Emergency SOS notifications and guardian alert workflow
- Firebase Authentication and Firestore synchronization
- Local SQLite caching for face recognition and offline data
- Role-based flow for `user` and `guardian` accounts
- Automatic device motion and fall detection using sensors
- Voice command and speech recognition support

## App Flow

1. Splash screen loads branding and navigates to login.
2. User signs in with email/password using Firebase Auth.
3. Firestore determines the account role (`user` or `guardian`).
4. Users are routed to the main assistive dashboard or guardian link flow.
5. The main user screen offers object detection, navigation, saved places, and safety alerts.
6. Guardian users can access linked dashboards and monitor connected users.

## Screens and Modules

- `lib/main.dart` — app entrypoint and Firebase initialization
- `lib/screens/splash_screen.dart` — branded startup experience
- `lib/screens/login_screen.dart` — email login with role and guardian handling
- `lib/screens/user_main_screen.dart` — core assistive experience with camera, maps, and safety
- `lib/screens/favourite_destinations_screen.dart` — saved locations and voice naming
- `lib/screens/profile_info_screen.dart` — profile and settings
- `lib/services/firebase_sync_service.dart` — sync registered faces between Firestore and SQLite
- `lib/services/facenet_service.dart` — offline face embedding generation
- `lib/services/object_detector.dart` — camera-based object detection
- `lib/services/user_location_tracker.dart` — location tracking for guardian updates

## Technology Stack

- Flutter
- Firebase (Auth, Firestore)
- Camera
- `tflite_flutter`
- `flutter_tts`
- `google_maps_flutter`
- `geolocator`
- `permission_handler`
- `sqflite`
- `speech_to_text`
- `sensors_plus`
- `volume_controller`
- `image`

## AI Models and Assets

VisionMate includes local ML models for on-device intelligence:

- `assets/models/yolov8n_int8.tflite` — object detection model
- `assets/models/mobilefacenet.tflite` — mobile face recognition model
- `assets/models/labels.txt` — object labels for detection

## Setup Instructions

1. Install Flutter and configure Android/iOS development.
2. Open the project folder in VS Code or Android Studio.
3. Run:
   ```bash
   flutter pub get
   flutter run
   ```
4. Configure Firebase by updating `lib/firebase_options.dart` with your project settings.
5. Ensure required permissions are granted when the app launches:
   - Camera
   - Microphone
   - Location
   - Storage

## Firebase Configuration

The project depends on Firebase for:

- Authentication
- Firestore user data
- Guardian relationship sync
- Registered face storage

Make sure your Firebase project includes matching app bundle IDs / package names and that Firestore permissions are configured appropriately.

## Security & Best Practices

- Do not commit real API keys or secrets to GitHub.
- Replace placeholder values in `lib/config/email_config.dart` only in a secure local environment.
- Remove any hard-coded service keys before sharing or publishing the repository.

## Notes for Developers

- Object detection is designed to remain enabled for accessibility.
- Voice interaction supports English speech recognition.
- Fall and impact detection uses device motion sensors to detect potential safety events.
- Guardian linking is managed via Firestore fields like `guardianEmail` and `isLinked`.
- Local face recognition sync is handled by `lib/services/firebase_sync_service.dart`.

## Repository

This project is published to:

`https://github.com/Muhammad-Hassan216/VisionMate`
