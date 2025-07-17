import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> addVital({
    required String heartRate,
    required String bloodPressure,
    required String temperature,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) throw Exception("User not logged in");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vitals')
        .add({
          'heartRate': heartRate,
          'bloodPressure': bloodPressure,
          'temperature': temperature,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
}
