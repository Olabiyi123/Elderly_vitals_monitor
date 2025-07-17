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
    final hrText = _heartRateController.text.trim();
    final tempText = _tempController.text.trim();

    // Basic checks
    if (hrText.isEmpty || tempText.isEmpty || _bpController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('All fields are required')));
      return;
    }

    final int? heartRate = int.tryParse(hrText);
    final double? temperature = double.tryParse(tempText);

    if (heartRate == null || temperature == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid number format')));
      return;
    }

    // Check abnormal values
    final isAbnormalHR = heartRate > 120 || heartRate < 50;
    final isAbnormalTemp = temperature > 38.0 || temperature < 35.0;

    if (isAbnormalHR || isAbnormalTemp) {
      final warningMsg = [
        if (isAbnormalHR) "⚠️ Heart Rate is abnormal",
        if (isAbnormalTemp) "⚠️ Temperature is abnormal",
      ].join("\n");

      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Abnormal Vitals Detected"),
          content: Text(warningMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text("Save Anyway"),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    try {
      await _firestoreService.addVital(
        heartRate: hrText,
        bloodPressure: _bpController.text.trim(),
        temperature: tempText,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vitals saved!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
