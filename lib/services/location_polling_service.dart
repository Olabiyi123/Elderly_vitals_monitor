import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class LocationPollingService {
  static final LocationPollingService _instance =
      LocationPollingService._internal();
  factory LocationPollingService() => _instance;
  LocationPollingService._internal();

  Timer? _pollingTimer;
  bool _breachDetected = false;

  Future<void> init() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'geofence_alerts',
        channelName: 'Geofence Alerts',
        channelDescription: 'Notification channel for geofence alerts',
        defaultColor: const Color(0xFF9D50DD),
        importance: NotificationImportance.High,
        channelShowBadge: true,
        ledColor: Colors.white,
      ),
    ]);
  }

  void startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(Duration(minutes: 2), (_) async {
      final position = await _getCurrentLocation();
      if (position == null) return;

      final geofence = await _getGeofence();
      if (geofence == null) return;

      final lat = geofence['latitude'];
      final lng = geofence['longitude'];
      final radius = geofence['radius'];

      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        position.latitude,
        position.longitude,
      );

      print('Current distance from safe zone: $distance m');

      if (distance > radius && !_breachDetected) {
        _breachDetected = true;

        final timestamp = DateTime.now().toLocal();
        final formattedTime = timestamp.toString().split('.')[0];
        final latStr = position.latitude.toStringAsFixed(4);
        final lngStr = position.longitude.toStringAsFixed(4);

        final title = "Geofence Breach Detected";
        final body =
            "User exited safe zone at $formattedTime\nLocation: $latStr, $lngStr";

        await _sendNotification(title, body);
        await _logGeofenceAlert(position, title, body);
      } else if (distance <= radius) {
        _breachDetected = false; // reset if back inside
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<Position?> _getCurrentLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<Map<String, dynamic>?> _getGeofence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('geofence')
        .get();

    return doc.exists ? doc.data() : null;
  }

  Future<void> _sendNotification(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'geofence_alerts',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  Future<void> _logGeofenceAlert(
    Position position,
    String title,
    String details,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .add({
          'type': 'geofence',
          'message': title,
          'details': details,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'notifiedByApp': true,
        });
  }
}
