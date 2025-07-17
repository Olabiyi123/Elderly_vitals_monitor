import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vitals Dashboard'),
        actions: [
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
            if (snapshot.hasError) {
              return Center(child: Text("Error loading vitals"));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final vitals = snapshot.data!.docs;

            if (vitals.isEmpty) {
              return Center(child: Text("No vitals recorded yet."));
            }

            return ListView.builder(
              itemCount: vitals.length,
              itemBuilder: (context, index) {
                final data = vitals[index].data() as Map<String, dynamic>;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final time = timestamp != null
                    ? "${timestamp.toLocal().toString().split('.')[0]}"
                    : "Unknown";

                final int? hr = int.tryParse(data['heartRate'] ?? '');
                final double? temp = double.tryParse(data['temperature'] ?? '');
                final isAbnormal =
                    (hr != null && (hr > 120 || hr < 50)) ||
                    (temp != null && (temp > 38.0 || temp < 35.0));

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
                                color: isAbnormal ? Colors.red : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text("Blood Pressure: ${data['bloodPressure']}"),
                        Text("Temperature: ${data['temperature']} °C"),
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
