import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import 'package:elderly_vitals_monitor/services/realtime_db_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final Set<String> _notifiedVitalIds = {};
  bool _fallNotified = false;
  bool _zoneNotified = false;

  final _rtdb = RealtimeDbService();

  StreamSubscription<DatabaseEvent>? fallSub;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _listenToRealtimeGyroAlerts();
  }

  @override
  void dispose() {
    fallSub?.cancel();
    super.dispose();
  }

  void _requestNotificationPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  void _listenToRealtimeGyroAlerts() {
    final uid = user?.uid;
    if (uid == null) return;

    final gyroRef = FirebaseDatabase.instance.ref().child('Gyro');
    final locationRef = FirebaseDatabase.instance.ref().child('Location');

    fallSub = gyroRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final fall = data['Fall Detection']?.toString().toLowerCase();
      final timestamp = DateTime.now().toLocal().toString().split('.')[0];

      if (fall == 'true' && !_fallNotified) {
        _fallNotified = true;

        final message = "Fall detected at $timestamp";
        await _sendAbnormalNotification("Fall Alert", message);

        await fallSub?.cancel();
        await FirebaseDatabase.instance
            .ref()
            .child('Gyro')
            .child('Fall Detection')
            .set("false");

        await Future.delayed(Duration(seconds: 2));
        _listenToRealtimeGyroAlerts();
      }

      if (fall == 'false') _fallNotified = false;
    });

    locationRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final zone = data['Zone Indicator']?.toString().toUpperCase();
      final timestamp = DateTime.now().toLocal().toString().split('.')[0];

      if (zone == 'OUT OF ZONE' && !_zoneNotified) {
        _zoneNotified = true;
        final message = "User exited safe zone at $timestamp";
        await _sendAbnormalNotification("Geofence Breach", message);
      }

      if (zone == 'INSIDE ZONE') _zoneNotified = false;
    });
  }

  Stream<QuerySnapshot> _getVitalsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('vitals')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _launchUrl(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F6FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          "Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.warning_amber),
            onPressed: () => Navigator.pushNamed(context, '/alerts'),
          ),
          IconButton(
            icon: Icon(Icons.notifications),
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

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F6FA), Color(0xFFE6EEF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // header card + check-in button
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Image.asset('assets/logo.png', height: 46),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Elderly Vitals Monitor",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Send a check-in reminder if needed",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _sendCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text("Check in"),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getVitalsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error loading vitals"));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final vitals = snapshot.data!.docs;

                    if (vitals.isEmpty) {
                      return Center(
                        child: Text(
                          "No vitals recorded yet.",
                          style: TextStyle(fontSize: 18),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: vitals.length,
                      itemBuilder: (context, index) {
                        final doc = vitals[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final timestamp = (data['timestamp'] as Timestamp?)
                            ?.toDate();
                        final time = timestamp != null
                            ? timestamp.toLocal().toString().split('.')[0]
                            : "Unknown";

                        return Container(
                          margin: EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              color: Colors.white,
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.favorite, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text(
                                        "${data['heartRate']} bpm",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Blood Pressure: ${data['bloodPressure']}",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Temperature: ${data['temperature']} °C",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  if (data['latitude'] != null &&
                                      data['longitude'] != null) ...[
                                    SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        final lat = data['latitude'];
                                        final lng = data['longitude'];
                                        final url = Uri.parse(
                                          "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
                                        );
                                        _launchUrl(url);
                                      },
                                      icon: Icon(Icons.map),
                                      label: Text("View on Map"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 12),
                                  Text(
                                    "Logged at: $time",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-vitals'),
        icon: Icon(Icons.add),
        label: Text("Add Vitals"),
        backgroundColor: Colors.blue[700],
      ),
    );
  }
}
