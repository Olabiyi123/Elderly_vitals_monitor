import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final Set<String> _notifiedVitalIds = {};

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
  }

  void _requestNotificationPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
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

                  String body = "Abnormal ";
                  if (isHrAbnormal) body += "Heart Rate (${hr} bpm), ";
                  if (isTempAbnormal)
                    body += "Temperature (${temp?.toStringAsFixed(1)}°C), ";
                  if (isBpAbnormal) body += "Blood Pressure ($bp), ";
                  body += "recorded at $time";

                  _sendAbnormalNotification("Vital Alert", body);
                  _logAbnormalAlertToFirestore(data, body, "vitals");
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
