import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadGeofenceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('geofence')
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
        .collection('settings')
        .doc('geofence')
        .set({
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    final rtdbRef = FirebaseDatabase.instance.ref();
    await rtdbRef.child('Location').child('Safe Zone').set({
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Geofence updated')));
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
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
          'Edit Safe Zone',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
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
                              "Safe Zone Configuration",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 8),

                            Text(
                              "Set the central coordinates and radius for monitoring movement.",
                              style: TextStyle(color: Colors.grey.shade700),
                            ),

                            SizedBox(height: 24),

                            _buildInputField(
                              controller: _latController,
                              label: "Latitude",
                              icon: Icons.location_on,
                            ),

                            SizedBox(height: 20),

                            _buildInputField(
                              controller: _lngController,
                              label: "Longitude",
                              icon: Icons.explore,
                            ),

                            SizedBox(height: 20),

                            _buildInputField(
                              controller: _radiusController,
                              label: "Radius (meters)",
                              icon: Icons.radio_button_checked,
                            ),

                            SizedBox(height: 30),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveGeofence,
                                icon: Icon(Icons.save),
                                label: Text(
                                  'Save Zone',
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
