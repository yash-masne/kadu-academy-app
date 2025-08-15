import 'package:flutter/material.dart';
// You might need these for logout functionality if it's handled here directly
import 'package:firebase_auth/firebase_auth.dart';
// Import other admin screens for navigation
import 'package:kadu_academy_app/test/admin_test_list_screen.dart'; // Example import
import 'package:kadu_academy_app/screens/admin_user_management_screen.dart'; // Example import
import 'package:kadu_academy_app/screens/admin_student_marks_screen.dart'; // Example import
import 'package:kadu_academy_app/screens2/dashboard_setting_screen.dart'; // Example import

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontSize: 16, // Smaller font
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            tooltip: 'Logout Admin',
            onPressed: () async {
              // Made onPressed async
              await FirebaseAuth.instance.signOut(); // Perform logout
              if (context.mounted) {
                // Check mounted before navigation
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        // <--- ADDED SafeArea
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Reduced outer padding
          child: SingleChildScrollView(
            // <--- ADDED SingleChildScrollView
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 80, // Reduced icon size
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 15), // Reduced spacing
                const Text(
                  'Welcome, Administrator!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ), // Reduced font size
                ),
                const SizedBox(height: 25), // Reduced spacing
                // Manage Tests Button
                SizedBox(
                  width: double.infinity,
                  height: 45, // Reduced button height
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/admin_test_management');
                    },
                    icon: const Icon(
                      Icons.assignment,
                      size: 20,
                    ), // Smaller icon
                    label: const Text(
                      'Manage Tests',
                      style: TextStyle(fontSize: 16), // Reduced font size
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Reduced padding
                    ),
                  ),
                ),
                const SizedBox(height: 15), // Reduced spacing
                // Manage Users Button
                SizedBox(
                  width: double.infinity,
                  height: 45, // Reduced button height
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/admin_user_management');
                    },
                    icon: const Icon(Icons.people, size: 20), // Smaller icon
                    label: const Text(
                      'Manage Users',
                      style: TextStyle(fontSize: 16), // Reduced font size
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Reduced padding
                    ),
                  ),
                ),
                const SizedBox(height: 15), // Reduced spacing
                // View Student Marks Button
                SizedBox(
                  width: double.infinity,
                  height: 45, // Reduced button height
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/admin_student_marks');
                    },
                    icon: const Icon(Icons.score, size: 20), // Smaller icon
                    label: const Text(
                      'View Student Marks',
                      style: TextStyle(fontSize: 16), // Reduced font size
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Reduced padding
                    ),
                  ),
                ),
                const SizedBox(height: 15), // Reduced spacing
                // NEW: Dashboard Setting Button
                SizedBox(
                  width: double.infinity,
                  height: 45, // Reduced button height
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/dashboard_setting');
                    },
                    icon: const Icon(Icons.settings, size: 20), // Smaller icon
                    label: const Text(
                      'Dashboard Setting',
                      style: TextStyle(fontSize: 16), // Reduced font size
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Reduced padding
                    ),
                  ),
                ),
                const SizedBox(height: 20), // Final spacing at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }
}
