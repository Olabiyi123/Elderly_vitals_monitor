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

  @override
  void dispose() {
    _heartRateController.dispose();
    _bpController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  void _submit() async {
    final hr = int.tryParse(_heartRateController.text.trim());
    final temp = double.tryParse(_tempController.text.trim());
    final bp = _bpController.text.trim();

    if (hr == null || temp == null || bp.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invalid or empty fields")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      await _firestoreService.addVital(
        heartRate: hr.toString(),
        bloodPressure: bp,
        temperature: temp.toStringAsFixed(1),
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Vitals saved!")));
      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
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
          "Add Vital Signs",
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
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enter today's vital signs",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 24),

                      _buildInputField(
                        controller: _heartRateController,
                        label: "Heart Rate (bpm)",
                        hint: "e.g. 72",
                        icon: Icons.favorite,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          final n = int.tryParse(val ?? '');
                          if (n == null) return "Enter a valid number";
                          if (n < 30 || n > 200)
                            return "Unrealistic heart rate";
                          return null;
                        },
                      ),

                      SizedBox(height: 20),

                      _buildInputField(
                        controller: _bpController,
                        label: "Blood Pressure",
                        hint: "Format: 120/80",
                        icon: Icons.monitor_heart,
                        keyboardType: TextInputType.text,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Enter BP";
                          if (!RegExp(r'^\d{2,3}/\d{2,3}$').hasMatch(val)) {
                            return "Format: 120/80";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20),

                      _buildInputField(
                        controller: _tempController,
                        label: "Temperature (°C)",
                        hint: "e.g. 36.5",
                        icon: Icons.thermostat,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (val) {
                          final n = double.tryParse(val ?? '');
                          if (n == null) return "Enter a valid temperature";
                          if (n < 30.0 || n > 45.0)
                            return "Unrealistic temperature";
                          return null;
                        },
                      ),

                      SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: Icon(Icons.save),
                          label: Text(
                            "Save Vitals",
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            padding: EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
