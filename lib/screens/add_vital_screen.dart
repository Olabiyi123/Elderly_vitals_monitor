import 'package:flutter/material.dart';
import 'package:elderly_vitals_monitor/services/firestore_service.dart';

class AddVitalScreen extends StatefulWidget {
  @override
  _AddVitalScreenState createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heartRateController = TextEditingController();
  final _bpController = TextEditingController();
  final _tempController = TextEditingController();
  final _firestoreService = FirestoreService();

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final hr = int.parse(_heartRateController.text.trim());
    final temp = double.parse(_tempController.text.trim());
    final bp = _bpController.text.trim();

    // Abnormal checks
    final isAbnormalHR = hr < 50 || hr > 120;
    final isAbnormalTemp = temp < 35.0 || temp > 38.0;

    if (isAbnormalHR || isAbnormalTemp) {
      final warning = [
        if (isAbnormalHR) "⚠️ Heart Rate is outside safe range.",
        if (isAbnormalTemp) "⚠️ Temperature is outside safe range.",
      ].join('\n');

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Abnormal Vitals"),
          content: Text(warning),
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

      if (proceed != true) return;
    }

    try {
      await _firestoreService.addVital(
        heartRate: hr.toString(),
        bloodPressure: bp,
        temperature: temp.toStringAsFixed(1),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Vitals saved")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Vitals")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                "Enter today's vital signs",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Heart Rate
              TextFormField(
                controller: _heartRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Heart Rate (bpm)",
                  hintText: "e.g. 72",
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null) return "Enter a valid number";
                  if (n < 30 || n > 200) return "Unrealistic heart rate";
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Blood Pressure
              TextFormField(
                controller: _bpController,
                decoration: InputDecoration(
                  labelText: "Blood Pressure (e.g. 120/80)",
                  hintText: "e.g. 120/80",
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Enter BP";
                  if (!RegExp(r'^\d{2,3}/\d{2,3}$').hasMatch(val)) {
                    return "Format: 120/80";
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Temperature
              TextFormField(
                controller: _tempController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Temperature (°C)",
                  hintText: "e.g. 36.5",
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final n = double.tryParse(val ?? '');
                  if (n == null) return "Enter a valid temperature";
                  if (n < 30.0 || n > 45.0) return "Unrealistic temperature";
                  return null;
                },
              ),

              SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _submit,
                icon: Icon(Icons.save),
                label: Text("Save Vitals"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
