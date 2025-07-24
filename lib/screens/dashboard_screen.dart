import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
//import '../services/location_polling_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final Set<String> _notifiedVitalIds = {};
  bool _fallNotified = false;
  bool _zoneNotified = false;

  StreamSubscription<DatabaseEvent>? fallSub;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    //LocationPollingService().startPolling();
    _listenToRealtimeGyroAlerts();
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

    // Save subscription reference
    fallSub = gyroRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final fall = data['Fall Detection']?.toString().toLowerCase();
      final timestamp = DateTime.now().toLocal().toString().split('.')[0];

      if (fall == 'true' && !_fallNotified) {
        _fallNotified = true;

        final message = "Fall detected at $timestamp";
        await _sendAbnormalNotification("Fall Alert", message);
        await _logRealtimeAlert("fall", "Fall Detected", message);

        // 🔇 Temporarily cancel listener to avoid loop
        await fallSub?.cancel();

        // ✅ Reset fall detection in DB
        await FirebaseDatabase.instance
            .ref()
            .child('Gyro')
            .child('Fall Detection')
            .set("false");

        // 🕒 Re-attach listener after delay
        await Future.delayed(Duration(seconds: 2));
        _listenToRealtimeGyroAlerts(); // re-listen
      }

      if (fall == 'false') _fallNotified = false;
    });

    // Your existing locationRef listener can stay the same
    locationRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final zone = data['Zone Indicator']?.toString().toUpperCase();
      final timestamp = DateTime.now().toLocal().toString().split('.')[0];

      if (zone == 'OUT OF ZONE' && !_zoneNotified) {
        _zoneNotified = true;
        final message = "User exited safe zone at $timestamp";
        await _sendAbnormalNotification("Geofence Breach", message);
        await _logRealtimeAlert("geofence", "Geofence Breach", message);
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
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _sendAbnormalNotification(String title, String body) async {
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

  Future<void> _logAbnormalAlertToFirestore(
    Map<String, dynamic> data,
    String message,
    String type,
  ) async {
    final uid = user?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .add({
          'message': message,
          'type': type,
          'heartRate': data['heartRate'],
          'temperature': data['temperature'],
          'bloodPressure': data['bloodPressure'],
          'timestamp': data['timestamp'] ?? FieldValue.serverTimestamp(),
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'notifiedByApp': true,
        });
  }

  Future<void> _logRealtimeAlert(
    String type,
    String message,
    String details,
  ) async {
    final uid = user?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .add({
          'type': type,
          'message': message,
          'details': details,
          'timestamp': FieldValue.serverTimestamp(),
          'notifiedByApp': true,
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.warning_amber),
            tooltip: 'View Alerts',
            onPressed: () => Navigator.pushNamed(context, '/alerts'),
          ),
          IconButton(
            icon: Icon(Icons.my_location),
            tooltip: 'Edit Safe Zone',
            onPressed: () => Navigator.pushNamed(context, '/geofence-settings'),
          ),
          IconButton(
            icon: Icon(Icons.notifications),
            tooltip: 'Notification Center',
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getVitalsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(child: Text("Error loading vitals"));
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());

            final vitals = snapshot.data!.docs;
            if (vitals.isEmpty)
              return Center(child: Text("No vitals recorded yet."));

            return ListView.builder(
              itemCount: vitals.length,
              itemBuilder: (context, index) {
                final doc = vitals[index];
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final time = timestamp != null
                    ? "${timestamp.toLocal().toString().split('.')[0]}"
                    : "Unknown";

                final int? hr = int.tryParse(data['heartRate'] ?? '');
                final double? temp = double.tryParse(data['temperature'] ?? '');
                final String bp = data['bloodPressure'] ?? '';
                final parts = bp.split('/');
                final int? systolic = parts.length == 2
                    ? int.tryParse(parts[0])
                    : null;
                final int? diastolic = parts.length == 2
                    ? int.tryParse(parts[1])
                    : null;

                final bool isHrAbnormal = hr != null && (hr > 120 || hr < 50);
                final bool isTempAbnormal =
                    temp != null && (temp > 38.0 || temp < 35.0);
                final bool isBpAbnormal =
                    (systolic != null && systolic > 140) ||
                    (diastolic != null && diastolic > 90);

                final bool isAbnormal =
                    isHrAbnormal || isTempAbnormal || isBpAbnormal;

                if (isAbnormal && !_notifiedVitalIds.contains(docId)) {
                  _notifiedVitalIds.add(docId);

                  Future<void> notifyAndMark() async {
                    String body = "Abnormal ";
                    if (isHrAbnormal) body += "Heart Rate (${hr} bpm)";
                    if (isTempAbnormal)
                      body += "Temperature (${temp?.toStringAsFixed(1)}°C)";
                    if (isBpAbnormal) body += "Blood Pressure ($bp)";

                    // Remove trailing comma and space
                    if (body.endsWith(", ")) {
                      body = body.substring(0, body.length - 2);
                    }

                    await _sendAbnormalNotification("Vital Alert", body);
                    await _logAbnormalAlertToFirestore(data, body, "vitals");

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('vitals')
                        .doc(docId)
                        .update({'notifiedByApp': true});
                  }

                  notifyAndMark();
                }

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  color: isAbnormal ? Colors.red.shade50 : Colors.white,
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monitor_heart, color: Colors.teal),
                            SizedBox(width: 8),
                            Text(
                              "Heart Rate: ${data['heartRate']} bpm",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isHrAbnormal ? Colors.red : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Blood Pressure: $bp",
                          style: TextStyle(
                            color: isBpAbnormal ? Colors.red : Colors.black,
                          ),
                        ),
                        Text(
                          "Temperature: ${data['temperature']} °C",
                          style: TextStyle(
                            color: isTempAbnormal ? Colors.red : Colors.black,
                          ),
                        ),
                        if (data['latitude'] != null &&
                            data['longitude'] != null) ...[
                          Text(
                            "Location: ${data['latitude'].toStringAsFixed(4)}, ${data['longitude'].toStringAsFixed(4)}",
                          ),
                          SizedBox(height: 4),
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
                              backgroundColor: Colors.teal.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              textStyle: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                        SizedBox(height: 6),
                        Text(
                          "Logged at: $time",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-vitals'),
        icon: Icon(Icons.add),
        label: Text("Add Vitals"),
      ),
    );
  }
}
