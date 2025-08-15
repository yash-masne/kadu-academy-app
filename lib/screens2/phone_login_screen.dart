// File: lib/screens2/phone_login_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadu_academy_app/screens2/phone_password_login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isNewUser = false;

  // New state variables to toggle password visibility
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
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

  Future<void> _continueWithPhoneNumber() async {
    final String phoneNumber = _phoneNumberController.text.trim();

    if (phoneNumber.isEmpty || !RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber)) {
      _showSnackBar('Please enter a valid 10-digit phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _showSnackBar('Checking phone number...', duration: 2);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: '+91$phoneNumber')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _showSnackBar(
          'Phone number found. Please enter your password.',
          duration: 2,
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PhonePasswordLoginScreen(phoneNumber: phoneNumber),
          ),
        );
      } else {
        _showSnackBar('New user detected. Please register.', duration: 2);

        if (!mounted) return;
        setState(() {
          _isNewUser = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('An error occurred. Please try again.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerNewUser() async {
    final String phoneNumber = _phoneNumberController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Please fill all fields.');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _showSnackBar('Creating your account...', duration: 2);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'studentType': 'phone_user',
          'isRegistered': false,
          'isApprovedByAdmin': false,
          'isBasicRegistration': false,
          'firstName': '',
          'lastName': '',
          'phoneNumber': '+91$phoneNumber',
          'rollNo': '',
          'branch': '',
          'year': '',
          'subject': '',
          'role': 'student',
        });
        _showSnackBar(
          'Registration successful! Please complete your profile.',
          duration: 2,
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/basic_profile',
          arguments: {'isInitialLogin': true, 'phoneNumber': phoneNumber},
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showSnackBar(
          'The email address is already in use by another account.',
        );
      } else {
        _showSnackBar('Registration failed: ${e.message}');
      }
    } catch (e) {
      print('ERROR: Unexpected registration error: $e');
      _showSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login with Phone'),
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
                'Enter your 10-digit phone number to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                readOnly: _isNewUser,
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
                  fillColor: _isNewUser ? Colors.grey.shade200 : Colors.white,
                  filled: _isNewUser,
                  counterText: "",
                ),
              ),
              const SizedBox(height: 20),
              if (_isNewUser) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible, // Visibility toggle
                  decoration: InputDecoration(
                    labelText: 'Create Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible, // Visibility toggle
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_isNewUser
                            ? _registerNewUser
                            : _continueWithPhoneNumber),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isNewUser ? 'Register' : 'Continue',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text(
                    'Use Google instead',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
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
