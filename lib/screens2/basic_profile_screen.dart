// File: lib/screens2/basic_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class BasicProfileScreen extends StatefulWidget {
  // Use a named constructor to pass the flag for initial registration
  final bool isInitialLogin;
  final String phoneNumber;
  const BasicProfileScreen({
    super.key,
    this.isInitialLogin = false,
    this.phoneNumber = '',
  });

  @override
  State<BasicProfileScreen> createState() => _BasicProfileScreenState();
}

class _BasicProfileScreenState extends State<BasicProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  User? _currentUser;
  bool _isSaving = false;
  bool _isPhoneLogin = false;

  // New state variable to toggle password visibility
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _isPhoneLogin = widget.phoneNumber.isNotEmpty;

    if (_isPhoneLogin) {
      _phoneNumberController.text = widget.phoneNumber;
    }

    _loadExistingProfileData();
  }

  Future<void> _loadExistingProfileData() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';

        if (!_isPhoneLogin) {
          _emailController.text = userData['email'] ?? '';
        }

        if (!_isPhoneLogin) {
          String savedPhoneNumber = userData['phoneNumber'] ?? '';
          if (savedPhoneNumber.startsWith('+91')) {
            _phoneNumberController.text = savedPhoneNumber.substring(3);
          } else {
            _phoneNumberController.text = savedPhoneNumber;
          }
        }
      }
    } catch (e) {
      _showSnackBar('Failed to load existing data.');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {int duration = 1}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateBasicProfile() async {
    if (_currentUser == null) {
      _showSnackBar('No active user. Please login again.');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String phoneNumber = _phoneNumberController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phoneNumber.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar('Please fill all fields.');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber)) {
      _showSnackBar('Please enter a valid 10-digit phone number.');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showSnackBar('Please enter a valid email address.');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match.');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    _showSnackBar('Saving profile...', duration: 2);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
            'firstName': firstName,
            'lastName': lastName,
            'phoneNumber': '+91$phoneNumber',
            'email': email,
            'isBasicRegistration': true,
          });

      if (_currentUser!.providerData.any(
        (info) => info.providerId == 'google.com',
      )) {
        final emailCred = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await _currentUser!.linkWithCredential(emailCred);
      } else {
        await _currentUser!.updateEmail(email);
        await _currentUser!.updatePassword(password);
      }

      _showSnackBar('Profile saved!', duration: 1);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/exam_selection');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showSnackBar(
          'The email address is already in use by another account.',
        );
      } else {
        _showSnackBar('Failed to save profile: ${e.message}');
      }
    } catch (e) {
      _showSnackBar('Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _signOutAndNavigateToLogin() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    } catch (e) {
      _showSnackBar('Failed to sign out. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Just a few more details to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                readOnly: !_isPhoneLogin,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                  fillColor: !_isPhoneLogin
                      ? Colors.grey.shade200
                      : Colors.white,
                  filled: !_isPhoneLogin,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                readOnly: _isPhoneLogin,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                  prefix: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Text(
                      '+91',
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.titleMedium?.fontSize ??
                            16,
                        color:
                            Theme.of(context).textTheme.titleMedium?.color ??
                            Colors.black87,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  fillColor: _isPhoneLogin
                      ? Colors.grey.shade200
                      : Colors.white,
                  filled: _isPhoneLogin,
                  counterText: "",
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true, // This field remains obscured
                decoration: const InputDecoration(
                  labelText: 'Create Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmPasswordController,
                obscureText:
                    !_isConfirmPasswordVisible, // Toggles visibility based on state
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    // The new visibility toggle icon
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateBasicProfile,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _signOutAndNavigateToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.blue),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    'Return to Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
