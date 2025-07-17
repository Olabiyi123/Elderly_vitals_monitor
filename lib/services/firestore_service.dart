import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;

  Future<Position> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw Exception("Location permission denied");
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 5),
    );
  }

  Future<void> addVital({
    required String heartRate,
    required String bloodPressure,
    required String temperature,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

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
  }
}
