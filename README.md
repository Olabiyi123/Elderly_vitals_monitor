# Elderly Vitals Monitor

Elderly Vitals Monitor is a Flutter mobile application designed to help elderly individuals and caregivers track vital health signs. It supports real-time data logging with GPS location, alerts for abnormal vitals, and user authentication via Firebase.

---

## Features

- Firebase Authentication (Email & Password)
- Add vitals: heart rate, blood pressure, temperature
- Save GPS location with each entry
- Detect and warn about abnormal vitals
- Real-time vitals dashboard using Firestore
- Google Maps link for viewing location
- Profile screen with name editing and password change

---

## Getting Started

### Prerequisites

- Flutter SDK (3.x recommended)
- Android Studio or VS Code
- Firebase project set up with:
  - Email/Password Authentication enabled
  - Firestore Database enabled
- Android device or emulator

---

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/elderly_vitals_monitor.git
   cd elderly_vitals_monitor

2. Install dependencies:flutter pub get

3. Configure Firebase:
Go to the Firebase Console
Create a new project
Register an Android app:
Use the package name: com.example.elderlyvitals
Download the google-services.json file
Place it in: android/app/google-services.json

4. Generate Firebase config: flutterfire configure
 
5. Run the app: flutter run

Tech Stack

Flutter

Firebase Authentication

Cloud Firestore

Geolocator (for location tracking)

URL Launcher (to open Google Maps)

Provider (optional state management)


Building APK
To generate an APK for testing or distribution:
flutter build apk --release

Output path:
build/app/outputs/flutter-apk/app-release.apk