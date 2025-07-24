import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_vital_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/alerts_screen.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
//import 'services/location_polling_service.dart';
import 'screens/geofence_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'basic_channel',
      channelName: 'Basic Notifications',
      channelDescription: 'For basic notifications',
      defaultColor: const Color(0xFF9D50DD),
      ledColor: Colors.white,
    ),
    NotificationChannel(
      channelKey: 'geofence_alerts',
      channelName: 'Geofence Alerts',
      channelDescription: 'Notification channel for geofence alerts',
      defaultColor: const Color(0xFF9D50DD),
      importance: NotificationImportance.High,
      channelShowBadge: true,
      ledColor: Colors.white,
    ),
  ], debug: true);

  //await LocationPollingService().init();

  runApp(const ElderlyVitalsApp());
}

class ElderlyVitalsApp extends StatelessWidget {
  const ElderlyVitalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elderly Vitals Monitor',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => LoginScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/add-vitals': (context) => AddVitalScreen(),
        '/profile': (context) => ProfileScreen(),
        '/alerts': (context) => AlertsScreen(),
        '/geofence-settings': (context) => GeofenceSettingsScreen(),
        '/notifications': (_) => NotificationScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return DashboardScreen();
          }
          return LoginScreen();
        },
      ),
    );
  }
}
