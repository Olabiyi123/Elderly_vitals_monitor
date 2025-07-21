import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class LocationPollingService {
  static final LocationPollingService _instance =
      LocationPollingService._internal();
  factory LocationPollingService() => _instance;
  LocationPollingService._internal();

  final double safeLat = 43.6532;
  final double safeLng = -79.3832;
  final double safeRadiusMeters = 100;

  Timer? _pollingTimer;

  Future<void> init() async {
    await AwesomeNotifications().initialize(
      null, // icon can be null to use default app icon
      [
        NotificationChannel(
          channelKey: 'geofence_alerts',
          channelName: 'Geofence Alerts',
          channelDescription: 'Notification channel for geofence alerts',
          defaultColor: const Color(0xFF9D50DD),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          ledColor: Colors.white,
        ),
      ],
    );
  }

  void startPolling() {
    _pollingTimer?.cancel(); // Cancel if already running

    _pollingTimer = Timer.periodic(Duration(minutes: 2), (_) async {
      final position = await _getCurrentLocation();
      if (position == null) return;

      final distance = Geolocator.distanceBetween(
        safeLat,
        safeLng,
        position.latitude,
        position.longitude,
      );

      print('Current distance from safe zone: $distance m');
      if (distance > safeRadiusMeters) {
        _sendNotification("Alert", "Elderly has exited the safe zone.");
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

  Future<void> _sendNotification(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 0,
        channelKey: 'geofence_alerts',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }
}
