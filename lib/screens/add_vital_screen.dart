import 'package:flutter/material.dart';
import 'package:elderly_vitals_monitor/services/firestore_service.dart';

class AddVitalScreen extends StatefulWidget {
  @override
  _AddVitalScreenState createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _heartRateController = TextEditingController();
  final _bpController = TextEditingController();
  final _tempController = TextEditingController();
  final _firestoreService = FirestoreService();

  void _submit() async {
    try {
      await _firestoreService.addVital(
        heartRate: _heartRateController.text.trim(),
        bloodPressure: _bpController.text.trim(),
        temperature: _tempController.text.trim(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vitals saved!')));
      Navigator.pop(context); // Go back to dashboard or previous screen
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving vitals: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Vitals")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _heartRateController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Heart Rate (bpm)"),
            ),
            TextField(
              controller: _bpController,
              decoration: InputDecoration(
                labelText: "Blood Pressure (e.g. 120/80)",
              ),
            ),
            TextField(
              controller: _tempController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Body Temperature (°C)"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Center(child: CircularProgressIndicator()),
                );
                try {
                  await _firestoreService.addVital(
                    heartRate: _heartRateController.text.trim(),
                    bloodPressure: _bpController.text.trim(),
                    temperature: _tempController.text.trim(),
                  );
                  Navigator.pop(context); // close loading
                  Navigator.pop(context); // go back
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Vitals saved!')));
                } catch (e) {
                  Navigator.pop(context); // close loading
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: Text("Save Vitals"),
            ),
          ],
        ),
      ),
    );
  }
}
