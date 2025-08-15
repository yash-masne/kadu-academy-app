import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void dispose() {
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

  Future<void> _ensureUserProfile(User user, String studentType) async {
    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      await userDocRef.set({
        'uid': user.uid,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'studentType': studentType,
        'isRegistered': false,
        'isApprovedByAdmin': false,
        'isBasicRegistration': false,
        'firstName': '',
        'lastName': '',
        'phoneNumber': '',
        'rollNo': '',
        'branch': '',
        'year': '',
        'subject': '',
        'role': 'student',
      });
      if (!mounted) return;
      // Pass isInitialLogin: true and an empty phoneNumber for a brand new user
      Navigator.pushReplacementNamed(
        context,
        '/basic_profile',
        arguments: {'isInitialLogin': true, 'phoneNumber': ''},
      );
      return;
    } else {
      final userData = userDoc.data() as Map<String, dynamic>;

      if (userData['isBasicRegistration'] == true) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        if (!mounted) return;
        // Pass isInitialLogin: false for a returning user with incomplete profile
        Navigator.pushReplacementNamed(
          context,
          '/basic_profile',
          arguments: {'isInitialLogin': false, 'phoneNumber': ''},
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _showSnackBar('Signing in with Google...', duration: 2);
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        _showSnackBar('Google Sign-In cancelled.');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        await _ensureUserProfile(userCredential.user!, 'google_user');
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Google Sign-In failed: ${e.message}');
    } catch (e) {
      _showSnackBar('An unexpected error occurred during Google Sign-In: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOutGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _showSnackBar('Signing out...', duration: 2);
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      _showSnackBar('Signed out successfully.');
    } on Exception catch (e) {
      _showSnackBar('Error signing out: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New method to show the Google recommendation dialog.
  void _showGoogleRecommendationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Google Sign-In Recommended'),
          content: const Text(
            'We recommend using Google for a faster and more secure sign-in experience. Would you like to continue with Phone and Password instead?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                if (!_isLoading) {
                  Navigator.pushNamed(context, '/phone_login');
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Student Login',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/kadu_logo.png',
                height: 100,
                width: 100,
              ),
              const SizedBox(height: 1),
              Text.rich(
                TextSpan(
                  text: 'Kadu',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 215, 8, 8),
                  ),
                  children: const <TextSpan>[
                    TextSpan(
                      text: ' Academy',
                      style: TextStyle(color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pushNamed(context, '/admin_login');
                        },
                  child: const Text(
                    'Admin Login',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign in to your Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              // --- Google Sign-In Button ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: _isLoading
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Image.asset(
                          'assets/images/google_logo.png',
                          height: 24,
                          width: 24,
                        ),
                  label: Text(
                    _isLoading ? 'Signing in...' : 'Continue with Google',
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // --- Revoke Login Button (TextButton) ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: _isLoading ? null : _signOutGoogle,
                  child: const Text(
                    'Revoke Login',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // --- "Login with Phone" TextButton ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : _showGoogleRecommendationDialog,
                  child: const Text(
                    'Unable to login or forget password?\nLogin with Phone and Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 13,
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
