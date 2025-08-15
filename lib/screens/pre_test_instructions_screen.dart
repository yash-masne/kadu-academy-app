import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import for Firestore
import 'package:kadu_academy_app/test/student_take_test_screen.dart';

class PreTestInstructionsScreen extends StatelessWidget {
  final String testId;
  final String studentTestSessionId;
  final int testDurationMinutes;
  final String testTitle;
  final bool allowStudentReview;

  const PreTestInstructionsScreen({
    super.key,
    required this.testId,
    required this.studentTestSessionId,
    required this.testDurationMinutes,
    required this.testTitle,
    required this.allowStudentReview,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Allow popping back to the test list
      onPopInvoked: (didPop) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Instructions & Warnings'),
          centerTitle: true,
          // Removed: automaticallyImplyLeading: false, // Re-enable default back button for convenience
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please Read Carefully Before Starting:',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildWarningRow(
                Icons.no_photography,
                'DO NOT take screenshots.',
              ), // Using corrected icon
              _buildWarningRow(
                Icons.exit_to_app,
                'DO NOT exit or minimize the app.',
              ),
              _buildWarningRow(
                Icons.volume_off,
                'Silence your phone for a better experience.',
              ),
              _buildWarningRow(
                Icons.swap_horiz,
                'DO NOT switch to other applications.',
              ),
              const SizedBox(height: 20),
              const Text(
                'Failing to adhere to these rules WILL result in automatic test termination and submission of your current progress.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 30),

              // --- MODIFIED SECTION: Buttons placed higher ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton.icon(
                      // MODIFIED: The onPressed handler now updates the Firestore document with the start time
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('studentTestSessions')
                              .doc(studentTestSessionId)
                              .update({
                                'studentStartTime': Timestamp.now(),
                                'studentEndTime': Timestamp.fromDate(
                                  DateTime.now().add(
                                    Duration(minutes: testDurationMinutes),
                                  ),
                                ),
                                'status': 'in_progress',
                              });

                          // Proceed to the test screen after updating the session
                          Navigator.pushReplacementNamed(
                            context,
                            '/student_take_test',
                            arguments: {
                              'testId': testId,
                              'studentTestSessionId': studentTestSessionId,
                              'testDurationMinutes': testDurationMinutes,
                              'testTitle': testTitle,
                              'allowStudentReview': allowStudentReview,
                            },
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to start test session: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Start Test',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // --- END MODIFIED SECTION ---
              const Spacer(), // This spacer will now push *all* content (including buttons) upwards
              // Add some explicit padding at the very bottom if you want more space
              // const SizedBox(height: 16), // Optional: Add extra space from screen bottom if needed
            ],
          ),
        ),
      ),
    );
  }

  // Moved to be a top-level function as previously discussed
  Widget _buildWarningRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber[700], size: 30), // Warning icon color
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
