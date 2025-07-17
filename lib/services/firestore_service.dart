import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;

  Future<Position> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
    } catch (e) {
      print("Location fetch failed: $e");
      throw Exception("Failed to get location. Please try again.");
    }
  }

  Future<void> addVital({
    required String heartRate,
    required String bloodPressure,
    required String temperature,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      final position = await _getCurrentLocation();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('vitals')
          .add({
            'heartRate': heartRate,
            'bloodPressure': bloodPressure,
            'temperature': temperature,
            'timestamp': FieldValue.serverTimestamp(),
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
    } catch (e, stack) {
      print("🔥 Error saving vital: $e");
      print(stack);
      rethrow; // Let UI show snackbar or alert
    }
  }
}
