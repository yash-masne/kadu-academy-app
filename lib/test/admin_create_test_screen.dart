import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadu_academy_app/test/admin_test_detail_management_screen.dart'; // <--- NEW IMPORT

class AdminCreateTestScreen extends StatefulWidget {
  const AdminCreateTestScreen({super.key});

  @override
  State<AdminCreateTestScreen> createState() => _AdminCreateTestScreenState();
}

class _AdminCreateTestScreenState extends State<AdminCreateTestScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Test'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Test Details',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Test Title (e.g., Math Quiz Chapter 1)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  final String title = _titleController.text.trim();
                  final String description = _descriptionController.text.trim();
                  final int? duration = int.tryParse(
                    _durationController.text.trim(),
                  );

                  if (title.isEmpty ||
                      description.isEmpty ||
                      duration == null ||
                      duration <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all fields correctly.'),
                      ),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saving test details...')),
                  );

                  try {
                    CollectionReference tests = FirebaseFirestore.instance
                        .collection('tests');
                    DocumentReference docRef = await tests.add({
                      'title': title,
                      'description': description,
                      'durationMinutes': duration,
                      'createdAt': Timestamp.now(),
                      'isPublished': false,
                      'isArchived': false, // NEW: Set to false for new tests
                      'title_lowercase': title
                          .toLowerCase(), // NEW: Store lowercase title for search
                    });

                    final String newTestId = docRef.id;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Test "$title" saved! Now manage questions.',
                        ),
                      ),
                    );

                    // --- NAVIGATE TO UNIFIED MANAGEMENT SCREEN ---
                    Navigator.pushReplacementNamed(
                      context,
                      '/admin_test_detail_management',
                      arguments: {
                        'testId': newTestId,
                        'initialTestData': {
                          'title': title,
                          'description': description,
                          'durationMinutes': duration,
                          'createdAt':
                              Timestamp.now(), // Pass initial data for the new screen
                          'isPublished': false, // Initial status for new test
                          'isArchived': false, // Initial status for new test
                          'title_lowercase': title
                              .toLowerCase(), // Pass lowercase title
                        },
                      },
                    );

                    // Clear fields (optional, as we're navigating away)
                    _titleController.clear();
                    _descriptionController.clear();
                    _durationController.clear();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save test: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text(
                  'Save Test Details & Manage Questions',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
