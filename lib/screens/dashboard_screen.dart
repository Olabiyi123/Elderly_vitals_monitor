import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:async';

import 'package:elderly_vitals_monitor/services/realtime_db_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _rtdb = RealtimeDbService();

  StreamSubscription<DatabaseEvent>? _gyroSub;
  StreamSubscription<DatabaseEvent>? _locationSub;

  bool _fallDetected = false;
  bool _fallNotified = false;

  String _zoneStatus = "UNINITIALIZED";
  bool _zoneNotified = false;

  DateTime? _lastDeviceUpdate;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _listenToRealtimeDeviceData();
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  void _requestNotificationPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  void _listenToRealtimeDeviceData() {
    final gyroRef = FirebaseDatabase.instance.ref().child('Gyro');
    final locationRef = FirebaseDatabase.instance.ref().child('Location');

    // ------------------ FALL DETECTION ------------------
    _gyroSub = gyroRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final fall = data['Fall Detection']?.toString().toLowerCase();

      setState(() {
        _lastDeviceUpdate = DateTime.now();
        _fallDetected = (fall == 'true');
      });

      if (fall == 'true' && !_fallNotified) {
        _fallNotified = true;

        final timestamp = DateTime.now().toLocal().toString().split('.')[0];
        final title = "Fall Detected";
        final details = "Fall detected at $timestamp";

        await _sendAbnormalNotification(title, details);
        await _logAlertToFirestore(
          type: "fall",
          title: title,
          message: details,
        );

        await FirebaseDatabase.instance
            .ref()
            .child('Gyro')
            .child('Fall Detection')
            .set("false");
      }

      if (fall == 'false') {
        _fallNotified = false;
      }
    });

    // ------------------ GEOFENCE ------------------
    _locationSub = locationRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final zone = data['Zone Indicator']?.toString().toUpperCase();

      setState(() {
        _lastDeviceUpdate = DateTime.now();
        _zoneStatus = zone ?? "UNINITIALIZED";
      });

      if (_zoneStatus == 'OUT OF ZONE' && !_zoneNotified) {
        _zoneNotified = true;

        final timestamp = DateTime.now().toLocal().toString().split('.')[0];
        final title = "Geofence Breach";
        final details = "User exited safe zone at $timestamp";

        await _sendAbnormalNotification(title, details);

        await _logAlertToFirestore(
          type: "geofence",
          title: title,
          message: details,
        );
      }

      if (_zoneStatus == 'INSIDE ZONE') {
        _zoneNotified = false;
      }
    });
  }

  bool get _isDeviceOnline {
    if (_lastDeviceUpdate == null) return false;
    return DateTime.now().difference(_lastDeviceUpdate!).inSeconds < 60;
  }

  Future<void> _sendAbnormalNotification(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'geofence_alerts',
        title: title,
        body: body,
      ),
    );
  }

  Future<void> _logAlertToFirestore({
    required String type,
    required String title,
    required String message,
  }) async {
    final uid = user?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .add({
          'type': type,
          'title': title, // bold header
          'message': message, // subtext
          'timestamp': FieldValue.serverTimestamp(),
          'notifiedByApp': true,
        });
  }

  Future<void> _sendCheckIn() async {
    final current = FirebaseAuth.instance.currentUser;
    final requestedBy = current?.email ?? current?.uid ?? 'caregiver';

    try {
      await _rtdb.sendCheckInRequest(requestedBy: requestedBy);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Check-in request sent')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send check-in: $e')));
    }
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Color _zoneColor() {
    if (_zoneStatus == "INSIDE ZONE") return Colors.green;
    if (_zoneStatus == "OUT OF ZONE") return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.warning_amber),
            tooltip: 'Alert History',
            onPressed: () => Navigator.pushNamed(context, '/alerts'),
          ),
          IconButton(
            icon: Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'geofence') {
                Navigator.pushNamed(context, '/geofence-settings');
              } else if (value == 'wifi') {
                Navigator.pushNamed(context, '/wifi-settings');
              } else if (value == 'home') {
                Navigator.pushNamed(context, '/home-address');
              } else if (value == 'logout') {
                _signOut(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'wifi', child: Text('Wi-Fi Settings')),
              PopupMenuItem(value: 'home', child: Text('Set Home Address')),
              PopupMenuItem(value: 'geofence', child: Text('Edit Safe Zone')),
              PopupMenuItem(value: 'logout', child: Text('Sign Out')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            HeaderCard(onCheckIn: _sendCheckIn),
            SizedBox(height: 16),
            StatusCard(
              title: "Device Status",
              value: _isDeviceOnline ? "ONLINE" : "OFFLINE",
              icon: Icons.devices,
              color: _isDeviceOnline ? Colors.green : Colors.red,
              subtitle: _lastDeviceUpdate == null
                  ? "No updates yet"
                  : "Last update: ${_lastDeviceUpdate!.toLocal().toString().split('.')[0]}",
            ),
            SizedBox(height: 16),
            StatusCard(
              title: "Fall Detection",
              value: _fallDetected ? "FALL DETECTED" : "No fall detected",
              icon: Icons.accessibility_new,
              color: _fallDetected ? Colors.red : Colors.green,
              subtitle: _fallDetected
                  ? "Immediate attention recommended"
                  : "No active fall event",
            ),
            SizedBox(height: 16),
            StatusCard(
              title: "Safe Zone",
              value: _zoneStatus,
              icon: Icons.location_on,
              color: _zoneColor(),
              subtitle: _zoneStatus == "INSIDE ZONE"
                  ? "User is within the safe radius"
                  : _zoneStatus == "OUT OF ZONE"
                  ? "User left safe area"
                  : "Safe zone not initialized",
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderCard extends StatelessWidget {
  final VoidCallback onCheckIn;

  const HeaderCard({required this.onCheckIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Image.asset('assets/logo.png', height: 40),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Elderly Vitals Monitor",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "Send a check-in reminder if needed",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onCheckIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text("Check In"),
          ),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const StatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
