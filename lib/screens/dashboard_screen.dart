import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;

  // Stream to fetch user's vitals from Firestore
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
        padding: EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getVitalsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error loading vitals."));
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
                    : "Unknown time";

                final latitude = data['latitude'];
                final longitude = data['longitude'];

                final String heartRateStr = data['heartRate'].toString();
                final String tempStr = data['temperature'].toString();
                final String bpStr = data['bloodPressure'].toString();

                final int heartRate = int.tryParse(heartRateStr) ?? 0;
                final double temperature = double.tryParse(tempStr) ?? 0.0;

                // Handle BP format "120/80"
                int? systolic;
                int? diastolic;
                if (bpStr.contains("/")) {
                  final parts = bpStr.split("/");
                  systolic = int.tryParse(parts[0]);
                  diastolic = parts.length > 1 ? int.tryParse(parts[1]) : null;
                }

                Color getHRColor() {
                  if (heartRate > 120) return Colors.red;
                  if (heartRate < 50) return Colors.orange;
                  return Colors.black;
                }

                Color getTempColor() {
                  if (temperature > 38.0 || temperature < 35.0)
                    return Colors.red;
                  return Colors.black;
                }

                Color getBPColor() {
                  if ((systolic != null && systolic > 140) ||
                      (diastolic != null && diastolic > 90))
                    return Colors.red;
                  if ((systolic != null && systolic < 90) ||
                      (diastolic != null && diastolic < 60))
                    return Colors.orange;
                  return Colors.black;
                }

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      "Heart Rate: $heartRate bpm",
                      style: TextStyle(
                        color: getHRColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Blood Pressure: $bpStr",
                          style: TextStyle(
                            color: getBPColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Temperature: $temperature °C",
                          style: TextStyle(
                            color: getTempColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (data['latitude'] != null &&
                            data['longitude'] != null)
                          Text(
                            "Location: ${data['latitude'].toStringAsFixed(4)}, ${data['longitude'].toStringAsFixed(4)}",
                          ),
                        SizedBox(height: 4),
                        Text(
                          "Logged at: $time",
                          style: TextStyle(fontSize: 12),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-vitals'),
        child: Icon(Icons.add),
        tooltip: "Add Vitals",
      ),
    );
  }
}
