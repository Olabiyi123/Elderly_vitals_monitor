import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

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

  Future<Map<String, dynamic>?> _getGeofence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('geofence')
        .get();

    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  Future<void> _checkGeofence(Position position) async {
    final geofence = await _getGeofence();
    if (geofence == null) return;

    final double lat = geofence['latitude'];
    final double lng = geofence['longitude'];
    final double radius = geofence['radius'] ?? 300.0;

    final distance = Geolocator.distanceBetween(
      lat,
      lng,
      position.latitude,
      position.longitude,
    );

    if (distance > radius) {
      await _sendGeofenceNotification();
      await _logGeofenceAlert(position);
    }
  }

  Future<void> _sendGeofenceNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'geofence_alerts',
        title: 'Geofence Alert',
        body: 'User is outside the defined safe zone.',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  Future<void> _logGeofenceAlert(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .add({
          'type': 'geofence',
          'timestamp': FieldValue.serverTimestamp(),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'notifiedByApp': true,
        });
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
      await _checkGeofence(position);

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

  Future<void> addAlert(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .add({
          'heartRate': data['heartRate'],
          'temperature': data['temperature'],
          'bloodPressure': data['bloodPressure'],
          'timestamp': data['timestamp'] ?? FieldValue.serverTimestamp(),
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'notifiedByApp': true,
        });
  }
}
