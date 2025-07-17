import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  Future<String> _getFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    return doc['firstName'] ?? 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vitals Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            FutureBuilder<String>(
              future: _getFirstName(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Text('Welcome...');
                return Text(
                  'Welcome back, ${snapshot.data}!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                );
              },
            ),
            SizedBox(height: 20),
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
                    return Center(child: Text("No vitals recorded yet."));
                  }

                  return ListView.builder(
                    itemCount: vitals.length,
                    itemBuilder: (context, index) {
                      final data = vitals[index].data() as Map<String, dynamic>;
                      final timestamp = (data['timestamp'] as Timestamp?)
                          ?.toDate();
                      final time = timestamp != null
                          ? "${timestamp.toLocal().toString().split('.')[0]}"
                          : "Unknown";

                      final int? hr = int.tryParse(data['heartRate'] ?? '');
                      final double? temp = double.tryParse(
                        data['temperature'] ?? '',
                      );
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
                                      color: isAbnormal
                                          ? Colors.red
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text("Blood Pressure: ${data['bloodPressure']}"),
                              Text("Temperature: ${data['temperature']} °C"),
                              if (data['latitude'] != null &&
                                  data['longitude'] != null)
                                Text(
                                  "Location: ${data['latitude'].toStringAsFixed(4)}, ${data['longitude'].toStringAsFixed(4)}",
                                ),
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
          ],
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
