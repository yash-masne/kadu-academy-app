// app_drawer.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadu_academy_app/screens2/buy_course_screen.dart';
import 'package:kadu_academy_app/screens2/free_zone_screen.dart';
import 'package:kadu_academy_app/screens2/info_pages_screen.dart';
import 'package:kadu_academy_app/screens/registration_screen.dart';
import 'package:share_plus/share_plus.dart'; // NEW IMPORT for sharing functionality

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = 'Loading...';
  String _userEmailAddress = 'Loading...';
  Map<String, dynamic>? _userProfileData;

  @override
  void initState() {
    super.initState();
    _initializeUserProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.isAnonymous) {
        setState(() {
          _userName = 'Anonymous User';
          _userEmailAddress = 'N/A';
        });
      } else {
        _userEmailAddress = user.email ?? 'N/A';

        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            setState(() {
              _userProfileData = userDoc.data() as Map<String, dynamic>;
              String firstName = _userProfileData!['firstName'] ?? '';
              String lastName = _userProfileData!['lastName'] ?? '';
              String fullName = '${firstName.trim()} ${lastName.trim()}';

              _userName = fullName.isNotEmpty
                  ? fullName
                  : user.email ?? 'Logged In User';
            });
          } else {
            setState(() {
              _userName = user.email ?? 'User Profile Not Found';
            });
          }
        } catch (e) {
          setState(() {
            _userName = user.email ?? 'Error Loading Profile';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to load user name: $e',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          }
        }
      }
    } else {
      setState(() {
        _userName = 'Not logged in';
        _userEmailAddress = 'N/A';
      });
    }
  }

  // NEW: Function to handle sharing the app link
  void _shareApp() async {
    try {
      await Share.share(
        'Check out Kadu Academy for amazing learning! Visit our website: https://kaduacademy.com/',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to share: $e',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.payment, 'Payments', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BuyCourseScreen(),
                ),
              );
            }),
            _buildDrawerItem(Icons.subscriptions, 'My Subscriptions', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BuyCourseScreen(),
                ),
              );
            }),
            _buildDrawerItem(Icons.videocam, 'Videos', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BuyCourseScreen(),
                ),
              );
            }),

            const Divider(),

            // NEW: Register / Update Profile - Visible to ALL
            _buildDrawerItem(Icons.how_to_reg, 'Enroll for Paid Courses', () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const RegistrationScreen(), // Navigate to RegistrationScreen
                ),
              );
            }),

            _buildDrawerItem(Icons.category, 'Select Exam Type', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/exam_selection');
            }),

            _buildDrawerItem(Icons.book, 'Free eBook Download', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FreeZoneScreen()),
              );
            }),
            _buildDrawerItem(
              Icons.lightbulb_outline,
              'GK & Current Affairs',
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FreeZoneScreen(),
                  ),
                );
              },
            ),

            // MODIFIED: Share button now uses the new _shareApp function
            _buildDrawerItem(Icons.share, 'Share', () {
              Navigator.pop(context);
              _shareApp();
            }),
            _buildDrawerItem(Icons.contact_support, 'Contact Us', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InfoPagesScreen(),
                ),
              );
            }),
            _buildDrawerItem(Icons.star_rate, 'Rate Us', () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Rate Us functionality',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              );
            }),
            _buildDrawerItem(Icons.info_outline, 'About Kadu Academy', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InfoPagesScreen(),
                ),
              );
            }),
            _buildDrawerItem(Icons.description, 'Terms', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InfoPagesScreen(),
                ),
              );
            }),
            _buildDrawerItem(Icons.security, 'Privacy Policy', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InfoPagesScreen(),
                ),
              );
            }),
            _buildDrawerItem(Icons.exit_to_app, 'Logout', () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Logged out successfully!',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error logging out: $e',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
