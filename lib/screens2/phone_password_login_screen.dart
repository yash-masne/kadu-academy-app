// File: lib/screens2/phone_password_login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class PhonePasswordLoginScreen extends StatefulWidget {
  final String phoneNumber;
  const PhonePasswordLoginScreen({super.key, required this.phoneNumber});

  @override
  State<PhonePasswordLoginScreen> createState() =>
      _PhonePasswordLoginScreenState();
}

class _PhonePasswordLoginScreenState extends State<PhonePasswordLoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // State variables for the cooldown timer
  bool _isCooldownActive = false;
  int _cooldownSeconds = 60;
  Timer? _timer;

  @override
  void dispose() {
    _passwordController.dispose();
    _timer?.cancel();
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

  void _startCooldownTimer() {
    _cooldownSeconds = 60;
    _isCooldownActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds == 0) {
        setState(() {
          _isCooldownActive = false;
          timer.cancel();
        });
      } else {
        setState(() {
          _cooldownSeconds--;
        });
      }
    });
  }

  Future<void> _forgotPassword() async {
    if (_isCooldownActive) {
      return;
    }

    _showSnackBar('Sending password reset link...', duration: 2);
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: '+91${widget.phoneNumber}')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showSnackBar('No account found with this phone number.');
        return;
      }

      final userData = querySnapshot.docs.first.data();
      final String userEmail = userData['email'] as String;

      await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Password Reset Email Sent'),
            content: Text(
              'A password reset link has been sent to $userEmail. Please check your inbox.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );

      _startCooldownTimer();
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error sending reset email: ${e.message}');
    } catch (e) {
      _showSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithPhoneAndPassword() async {
    final String password = _passwordController.text.trim();
    if (password.isEmpty) {
      _showSnackBar('Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: '+91${widget.phoneNumber}')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showSnackBar(
          'No user found with that phone number. Please try again.',
        );
        return;
      }

      final userData = querySnapshot.docs.first.data();
      final String userEmail = userData['email'] as String;

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: userEmail,
        password: password,
      );

      _showSnackBar('Sign in successful!', duration: 1);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        _showSnackBar('Incorrect password. Please try again.');
      } else {
        _showSnackBar('Login failed: ${e.message}');
      }
    } catch (e) {
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
        title: const Text('Enter Password'),
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
              Text(
                'Enter the password for the account associated with +91 ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
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
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithPhoneAndPassword,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading || _isCooldownActive
                    ? null
                    : _forgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: _isCooldownActive ? Colors.grey : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isCooldownActive)
                Text(
                  'Please wait $_cooldownSeconds seconds to request a new link.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
