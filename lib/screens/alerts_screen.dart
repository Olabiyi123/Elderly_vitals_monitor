import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
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
      appBar: AppBar(title: Text("Alert History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAlertsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Failed to load alerts."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!.docs;

          if (alerts.isEmpty) {
            return Center(child: Text("No alerts found."));
          }

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final data = alerts[index].data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final time = timestamp != null
                  ? "${timestamp.toLocal().toString().split('.')[0]}"
                  : "Unknown time";

              return ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text(data['message'] ?? 'Alert'),
                subtitle: Text("Time: $time\n${data['details'] ?? ''}"),
              );
            },
          );
        },
      ),
    );
  }
}
