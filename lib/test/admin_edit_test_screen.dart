import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminEditTestScreen extends StatefulWidget {
  final String testId;
  // Removed initialTestData from constructor as we'll fetch it directly
  const AdminEditTestScreen({super.key, required this.testId});

  @override
  State<AdminEditTestScreen> createState() => _AdminEditTestScreenState();
}

class _AdminEditTestScreenState extends State<AdminEditTestScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  DateTime? _scheduledPublishTime;
  DateTime? _globalExpiryTime;
  bool _isPublished = false;

  bool _isLoading = true; // NEW: To show a loading indicator
  String _errorMessage = ''; // NEW: To show error if data fetch fails

  @override
  void initState() {
    super.initState();
    _loadTestData(); // NEW: Call a method to load data
  }

  // NEW: Method to load test data from Firestore
  Future<void> _loadTestData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> testData = doc.data() as Map<String, dynamic>;

        _titleController.text = testData['title'] ?? '';
        _descriptionController.text = testData['description'] ?? '';
        _durationController.text = (testData['durationMinutes'] ?? 0)
            .toString();

        if (testData.containsKey('scheduledPublishTime') &&
            testData['scheduledPublishTime'] is Timestamp) {
          _scheduledPublishTime =
              (testData['scheduledPublishTime'] as Timestamp).toDate();
        } else {
          _scheduledPublishTime =
              null; // Ensure it's null if not present or wrong type
        }

        if (testData.containsKey('globalExpiryTime') &&
            testData['globalExpiryTime'] is Timestamp) {
          _globalExpiryTime = (testData['globalExpiryTime'] as Timestamp)
              .toDate();
        } else {
          _globalExpiryTime =
              null; // Ensure it's null if not present or wrong type
        }
        _isPublished = testData['isPublished'] ?? false;
      } else {
        _errorMessage = 'Test data not found.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load test data: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // Function to pick date and time
  Future<void> _pickDateTime({
    required BuildContext context,
    required Function(DateTime) onDateTimeSelected,
    DateTime? initialDate,
    DateTime? firstDate,
  }) async {
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5), // Default 5 years back
      lastDate: DateTime(now.year + 5), // 5 years future
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialDate != null
            ? TimeOfDay.fromDateTime(initialDate)
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        onDateTimeSelected(selectedDateTime);
      }
    }
  }

  void _updateTest() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final int? duration = int.tryParse(_durationController.text.trim());

    if (title.isEmpty ||
        description.isEmpty ||
        duration == null ||
        duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.')),
      );
      return;
    }

    if (_scheduledPublishTime != null && _globalExpiryTime != null) {
      if (_scheduledPublishTime!.isAfter(_globalExpiryTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Scheduled publish time cannot be after expiry time.',
            ),
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Updating test details...')));

    try {
      DocumentReference testDocRef = FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId);

      bool finalIsPublished = _isPublished;
      final DateTime now = DateTime.now();

      if (_scheduledPublishTime != null &&
          now.isBefore(_scheduledPublishTime!)) {
        finalIsPublished = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test will be unpublished until scheduled publish time.',
            ),
          ),
        );
      } else if (_globalExpiryTime != null && now.isAfter(_globalExpiryTime!)) {
        finalIsPublished = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test has expired and will be unpublished.'),
          ),
        );
      }

      Map<String, dynamic> updateData = {
        'title': title,
        'description': description,
        'durationMinutes': duration,
        'updatedAt': Timestamp.now(),
        'isPublished': finalIsPublished,
        'scheduledPublishTime': _scheduledPublishTime != null
            ? Timestamp.fromDate(_scheduledPublishTime!)
            : null,
        'globalExpiryTime': _globalExpiryTime != null
            ? Timestamp.fromDate(_globalExpiryTime!)
            : null,
      };

      await testDocRef.update(updateData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test "$title" updated successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update test: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Test...'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadTestData, // Retry loading
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Test'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editing Test ID: ${widget.testId}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Test Title',
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

              // Scheduled Publish Time Picker
              ListTile(
                title: const Text('Scheduled Publish Time (Optional)'),
                subtitle: Text(
                  _scheduledPublishTime == null
                      ? 'Not set'
                      : DateFormat(
                          'MMM d, yyyy HH:mm',
                        ).format(_scheduledPublishTime!.toLocal()),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _scheduledPublishTime = null;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _pickDateTime(
                        context: context,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _scheduledPublishTime = dateTime;
                          });
                        },
                        initialDate: _scheduledPublishTime,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ), // Can't schedule too far back
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Global Expiry Time Picker
              ListTile(
                title: const Text('Global Expiry Time (Optional)'),
                subtitle: Text(
                  _globalExpiryTime == null
                      ? 'Not set'
                      : DateFormat(
                          'MMM d, yyyy HH:mm',
                        ).format(_globalExpiryTime!.toLocal()),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _globalExpiryTime = null;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _pickDateTime(
                        context: context,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _globalExpiryTime = dateTime;
                          });
                        },
                        initialDate: _globalExpiryTime,
                        firstDate:
                            _scheduledPublishTime ??
                            DateTime.now().subtract(
                              const Duration(days: 365),
                            ), // Expiry must be after publish time
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Is Published Switch
              SwitchListTile(
                title: const Text('Publish Test Now'),
                subtitle: const Text(
                  'Manually make this test visible to students immediately.',
                ),
                value: _isPublished,
                onChanged: (bool value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _updateTest,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
