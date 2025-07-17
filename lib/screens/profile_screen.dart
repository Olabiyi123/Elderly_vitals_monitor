import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = true;

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final data = doc.data();
    if (data != null) {
      _firstNameController.text = data['firstName'] ?? '';
      _lastNameController.text = data['lastName'] ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _updateName() async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Name updated!")));
  }

  Future<void> _changePassword() async {
    try {
      await user!.updatePassword(_passwordController.text.trim());
      _passwordController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Password updated!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Password change failed: $e")));
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Icon(Icons.account_circle, size: 100, color: Colors.teal),
              SizedBox(height: 20),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: "First Name"),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: "Last Name"),
              ),
              SizedBox(height: 16),
              ElevatedButton(onPressed: _updateName, child: Text("Save Name")),
              Divider(height: 40),
              Text(
                "Change Password",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: "New Password"),
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : "Min 6 characters",
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) _changePassword();
                },
                child: Text("Update Password"),
              ),
              SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _signOut,
                icon: Icon(Icons.logout),
                label: Text("Sign Out"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
