import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_vitals_monitor/services/realtime_db_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class HomeAddressScreen extends StatefulWidget {
  @override
  State<HomeAddressScreen> createState() => _HomeAddressScreenState();
}

class _HomeAddressScreenState extends State<HomeAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _rtdb = RealtimeDbService();

  bool _loading = true;
  bool _saving = false;

  String? _currentAddress;
  double? _currentLat;
  double? _currentLng;
  double _currentRadius = 50;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
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
      _currentAddress = data?['address'];
      _currentLat = (data?['latitude'] as num?)?.toDouble();
      _currentLng = (data?['longitude'] as num?)?.toDouble();
      _currentRadius = (data?['radius'] as num?)?.toDouble() ?? 50;

      if (_currentAddress != null) {
        _addressController.text = _currentAddress!;
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final address = _addressController.text.trim();

      final locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        throw Exception("Address could not be resolved");
      }

      final lat = locations.first.latitude;
      final lng = locations.first.longitude;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not signed in");

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('geofence')
          .set({
            'latitude': lat,
            'longitude': lng,
            'radius': _currentRadius,
            'address': address,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Save to Realtime DB (Arduino)
      await _rtdb.setSafeZone(
        latitude: lat,
        longitude: lng,
        radius: _currentRadius,
        address: address,
      );

      setState(() {
        _currentAddress = address;
        _currentLat = lat;
        _currentLng = lng;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Home address updated")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invalid address: $e")));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text("Home Address"),
      ),
      body: _loading
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
                child: ListView(
                  children: [
                    if (_currentAddress != null)
                      Container(
                        margin: EdgeInsets.only(bottom: 20),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Current Home Address",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(_currentAddress!),
                            if (_currentLat != null && _currentLng != null) ...[
                              SizedBox(height: 6),
                              Text(
                                "Lat: ${_currentLat!.toStringAsFixed(5)}",
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                "Lng: ${_currentLng!.toStringAsFixed(5)}",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),

                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _addressController,
                                decoration: InputDecoration(
                                  labelText: "Enter new home address",
                                  prefixIcon: Icon(Icons.home),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? "Address required"
                                    : null,
                              ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(Icons.save),
                                  label: Text(
                                    _saving ? "Saving..." : "Save Address",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    padding: EdgeInsets.symmetric(vertical: 16),
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
                  ],
                ),
              ),
            ),
    );
  }
}
