import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeofenceSettingsScreen extends StatefulWidget {
  @override
  _GeofenceSettingsScreenState createState() => _GeofenceSettingsScreenState();
}

class _GeofenceSettingsScreenState extends State<GeofenceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGeofenceData();
  }

  Future<void> _loadGeofenceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('geofence')
        .doc('zone')
        .get();

    if (doc.exists) {
      final data = doc.data();
      _latController.text = data?['latitude']?.toString() ?? '';
      _lngController.text = data?['longitude']?.toString() ?? '';
      _radiusController.text = data?['radius']?.toString() ?? '';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveGeofence() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final latitude = double.tryParse(_latController.text);
    final longitude = double.tryParse(_lngController.text);
    final radius = double.tryParse(_radiusController.text);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('geofence')
        .doc('zone')
        .set({
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Geofence updated')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Safe Zone')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _latController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Latitude'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _lngController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Longitude'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Radius (in meters)',
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saveGeofence,
                      icon: Icon(Icons.save),
                      label: Text('Save Zone'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
