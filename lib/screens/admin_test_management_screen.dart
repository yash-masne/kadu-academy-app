import 'package:flutter/material.dart';

class AdminTestManagementScreen extends StatelessWidget {
  const AdminTestManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tests'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Stretch buttons horizontally
          children: [
            const Text(
              'Test Management Panel',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/admin_create_test');
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Create New Test',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to a screen for viewing/editing existing tests
                Navigator.pushNamed(context, '/admin_test_list');
              },
              icon: const Icon(Icons.list_alt),
              label: const Text(
                'View/Edit Tests',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            // Add more management options here later, e.g., "View Submissions"
          ],
        ),
      ),
    );
  }
}
