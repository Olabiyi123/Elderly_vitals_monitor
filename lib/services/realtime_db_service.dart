import 'package:firebase_database/firebase_database.dart';

class RealtimeDbService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference get _wifiRef => _db.ref('WiFi');
  DatabaseReference get _safeZoneRef => _db.ref('Location/Safe Zone');
  DatabaseReference get _checkInRef => _db.ref('CheckIn');

  Future<Map<String, dynamic>?> getWifi() async {
    final snap = await _wifiRef.get();
    if (!snap.exists) return null;
    final data = snap.value;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Stream<DatabaseEvent> wifiStream() => _wifiRef.onValue;

  Future<void> setWifi({required String ssid, required String password}) async {
    await _wifiRef.set({
      'ssid': ssid,
      'password': password,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> setSafeZone({
    required double latitude,
    required double longitude,
    required double radius,
    String? address,
  }) async {
    await _safeZoneRef.set({
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      if (address != null) 'address': address,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<Map<String, dynamic>?> getSafeZone() async {
    final snap = await _safeZoneRef.get();
    if (!snap.exists) return null;
    final data = snap.value;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> sendCheckInRequest({required String requestedBy}) async {
    await _checkInRef.child('request').set({
      'active': true,
      'requestedBy': requestedBy,
      'requestedAt': ServerValue.timestamp,
    });
  }

  Future<void> clearCheckInRequest() async {
    await _checkInRef.child('request').update({'active': false});
  }

  Stream<DatabaseEvent> checkInStream() => _checkInRef.onValue;
}
