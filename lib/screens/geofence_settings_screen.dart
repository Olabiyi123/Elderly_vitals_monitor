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

  static const int minRadius = 50;
  static const int stepRadius = 50;

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
      _radiusController.text = data?['radius']?.toString() ?? '$minRadius';
    } else {
      _radiusController.text = '$minRadius';
    }

    setState(() => _isLoading = false);
  }

  int _currentRadius() {
    final n = int.tryParse(_radiusController.text.trim());
    if (n == null) return minRadius;
    return n;
  }

  void _bumpRadius(int delta) {
    int r = _currentRadius() + delta;
    if (r < minRadius) r = minRadius;

    // snap to nearest 50
    r = ((r + stepRadius - 1) ~/ stepRadius) * stepRadius;
    _radiusController.text = r.toString();
    setState(() {});
  }

  Future<void> _saveGeofence() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final latitude = double.tryParse(_latController.text.trim());
    final longitude = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());

    if (latitude == null || longitude == null || radius == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid values')));
      return;
    }

    // enforce min + increments
    if (radius < minRadius || radius % stepRadius != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Radius must be at least $minRadius and in $stepRadius m steps',
          ),
        ),
      );
      return;
    }

    // Firestore (app UI use)
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
        }, SetOptions(merge: true));

    // Realtime DB (for Arduino)
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

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
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
        title: Text('Edit Safe Zone'),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            tooltip: 'Set Home Address',
            onPressed: () => Navigator.pushNamed(context, '/home-address'),
          ),
        ],
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
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          TextFormField(
                            controller: _latController,
                            keyboardType: TextInputType.number,
                            decoration: _dec('Latitude', Icons.my_location),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Required'
                                : null,
                          ),
                          SizedBox(height: 12),
                          TextFormField(
                            controller: _lngController,
                            keyboardType: TextInputType.number,
                            decoration: _dec('Longitude', Icons.location_on),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Required'
                                : null,
                          ),
                          SizedBox(height: 12),

                          Text(
                            'Radius (meters) - minimum $minRadius, step $stepRadius',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _bumpRadius(-stepRadius),
                                icon: Icon(Icons.remove_circle_outline),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _radiusController,
                                  keyboardType: TextInputType.number,
                                  decoration: _dec('Radius', Icons.radar),
                                  validator: (value) {
                                    final r = int.tryParse(value ?? '');
                                    if (r == null) return 'Required';
                                    if (r < minRadius) return 'Min $minRadius';
                                    if (r % stepRadius != 0)
                                      return 'Must be in $stepRadius m steps';
                                    return null;
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: () => _bumpRadius(stepRadius),
                                icon: Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),

                          SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _saveGeofence,
                            icon: Icon(Icons.save),
                            label: Text('Save Zone'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
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
    );
  }
}
