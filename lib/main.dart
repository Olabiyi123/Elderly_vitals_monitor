import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_vital_screen.dart';
import 'screens/profile_screen.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'services/location_polling_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'basic_channel',
      channelName: 'Basic Notifications',
      channelDescription: 'For basic notifications',
      defaultColor: const Color(0xFF9D50DD),
      ledColor: Colors.white,
    ),
  ], debug: true);
  await LocationPollingService().init();
  LocationPollingService().startPolling();

  final user = FirebaseAuth.instance.currentUser;

  runApp(ElderlyVitalsApp(isLoggedIn: user != null));
}

class ElderlyVitalsApp extends StatelessWidget {
  final bool isLoggedIn;

  ElderlyVitalsApp({required this.isLoggedIn});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elderly Vitals Monitor',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/add-vitals': (context) => AddVitalScreen(),
        '/profile': (context) => ProfileScreen(),
      },
    );
  }
}
