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
      backgroundColor: Color(0xFFF2F6FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          "Alert History",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F6FA), Color(0xFFE6EEF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getAlertsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Failed to load alerts.",
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final alerts = snapshot.data!.docs;

            if (alerts.isEmpty) {
              return Center(
                child: Text("No alerts found.", style: TextStyle(fontSize: 18)),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final data = alerts[index].data() as Map<String, dynamic>;

                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final time = timestamp != null
                    ? timestamp.toLocal().toString().split('.')[0]
                    : "Unknown time";

                final type = data['type'] ?? 'vitals';

                IconData icon;
                Color color;

                switch (type) {
                  case 'geofence':
                    icon = Icons.location_off;
                    color = Colors.orange;
                    break;
                  case 'fall':
                    icon = Icons.accessibility_new;
                    color = Colors.deepPurple;
                    break;
                  case 'vitals':
                  default:
                    icon = Icons.monitor_heart;
                    color = Colors.red;
                    break;
                }

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
                      child: Row(
                        children: [
                          // Colored indicator stripe
                          Container(width: 6, height: 120, color: color),

                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(icon, color: color),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          data['message'] ?? 'Alert',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 8),

                                  if (data['details'] != null)
                                    Text(
                                      data['details'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey.shade800,
                                        height: 1.4,
                                      ),
                                    ),

                                  SizedBox(height: 12),

                                  Text(
                                    "Time: $time",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
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
    );
  }
}
