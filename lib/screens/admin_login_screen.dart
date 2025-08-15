import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {int duration = 1}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11), // SnackBar font remains small
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _adminLogin() async {
    setState(() {
      _isLoading = true;
    });

    // Trim spaces from the email and password inputs
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter email and password.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists &&
            (userDoc.data() as Map<String, dynamic>)['isAdmin'] == true) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/admin_dashboard',
              (route) => false,
            );
            _showSnackBar('Admin Login Successful!');
          }
        } else {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            _showSnackBar('Access Denied: Not an Admin.');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Login failed: ${e.message}';
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e');
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
      appBar: AppBar(title: const Text('Admin Login'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(
            24.0,
          ), // Reverted to 24.0 for outer padding
          child: SingleChildScrollView(
            // Wrap the form in AutofillGroup to enable password saving suggestions
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter Admin Credentials',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ), // Reverted to 20 for prominence
                  ),
                  const SizedBox(height: 30), // Reverted spacing
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    // Add autofillHints for email
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ), // Increased padding inside TextField
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                    ), // Increased input font size
                  ),
                  const SizedBox(height: 20), // Reverted spacing
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    // Add autofillHints for password
                    autofillHints: const [AutofillHints.password],
                    // The `onEditingComplete` callback has been removed as it was causing a compilation error.
                    // The password manager will still suggest saving the password automatically
                    // upon successful login, triggered by the `_adminLogin` method.
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ), // Increased padding inside TextField
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                    ), // Increased input font size
                  ),
                  const SizedBox(height: 30), // Reverted spacing
                  SizedBox(
                    width: double.infinity,
                    height: 50, // Reverted button height
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _adminLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24, // Standard loading indicator size
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3, // Standard stroke
                              ),
                            )
                          : const Text(
                              'Login as Admin',
                              style: TextStyle(
                                fontSize: 18,
                              ), // Reverted button font size
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
