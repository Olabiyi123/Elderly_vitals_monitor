// lib/screens/notification_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationScreen extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot> _getAlertsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAlertsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading notifications"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!.docs;
          if (alerts.isEmpty) {
            return Center(child: Text("No notifications yet."));
          }

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final data = alerts[index].data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final time = timestamp != null
                  ? "${timestamp.toLocal().toString().split('.')[0]}"
                  : "Unknown";

              final type = data['type'] ?? 'vitals';
              final lat = data['latitude'];
              final lng = data['longitude'];

              return ListTile(
                leading: Icon(
                  type == 'geofence'
                      ? Icons.location_off
                      : type == 'fall'
                      ? Icons.accessibility_new
                      : Icons.monitor_heart,
                  color: type == 'geofence'
                      ? Colors.orange
                      : type == 'fall'
                      ? Colors.deepPurple
                      : Colors.red,
                ),
                title: Text(data['message'] ?? 'Alert'),
                subtitle: Text(data['details'] ?? 'Time: $time'),
                trailing: lat != null && lng != null
                    ? IconButton(
                        icon: Icon(Icons.map),
                        onPressed: () {
                          final url = Uri.parse(
                            "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
                          );
                          launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
