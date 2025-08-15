import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For current user UID

class StudentAllTestsScreen extends StatefulWidget {
  const StudentAllTestsScreen({super.key});

  @override
  State<StudentAllTestsScreen> createState() => _StudentAllTestsScreenState();
}

class _StudentAllTestsScreenState extends State<StudentAllTestsScreen> {
  String? _currentStudentId;

  // Helper to fetch user data for display (with caching)
  final Map<String, Map<String, dynamic>> _cachedUsers = {};
  Future<Map<String, dynamic>> _fetchUserData(String uid) async {
    if (_cachedUsers.containsKey(uid)) {
      return _cachedUsers[uid]!;
    }
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (userDoc.exists) {
      _cachedUsers[uid] = userDoc.data() as Map<String, dynamic>;
      return _cachedUsers[uid]!;
    }
    return {}; // Return empty map if user not found
  }

  // Helper to fetch test data for display (with caching)
  final Map<String, Map<String, dynamic>> _cachedTests = {};
  Future<Map<String, dynamic>> _fetchTestData(String testId) async {
    if (_cachedTests.containsKey(testId)) {
      return _cachedTests[testId]!;
    }
    DocumentSnapshot testDoc = await FirebaseFirestore.instance
        .collection('tests')
        .doc(testId)
        .get();
    if (testDoc.exists) {
      _cachedTests[testId] = testDoc.data() as Map<String, dynamic>;
      return _cachedTests[testId]!;
    }
    return {'title': 'Unknown Test'}; // Return default if test not found
  }

  @override
  void initState() {
    super.initState();
    _currentStudentId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentStudentId == null) {
      // Handle case where user is not logged in (should not happen if main.dart works)
      // Optionally navigate back to login
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStudentId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Previous Tests'),
          centerTitle: true,
        ),
        body: const Center(child: Text('User not logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Previous Tests'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('studentTestSessions')
            .where('studentId', isEqualTo: _currentStudentId)
            .where('status', isEqualTo: 'completed')
            .orderBy('submissionTime', descending: true) // Order by most recent
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('You have not completed any tests yet.'),
            );
          }

          final List<DocumentSnapshot> allTestSessions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: allTestSessions.length,
            itemBuilder: (context, index) {
              DocumentSnapshot sessionDoc = allTestSessions[index];
              Map<String, dynamic> sessionData =
                  sessionDoc.data() as Map<String, dynamic>;

              String testId = sessionData['testId'] ?? 'N/A';
              int score = sessionData['score'] ?? 0;
              int totalQuestions = sessionData['totalQuestions'] ?? 0;
              Timestamp submissionTime =
                  sessionData['submissionTime'] as Timestamp;

              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchTestData(testId), // Fetch test title
                builder: (context, testSnapshot) {
                  String testTitle = 'Unknown Test';
                  if (testSnapshot.hasData && testSnapshot.data!.isNotEmpty) {
                    testTitle = testSnapshot.data!['title'] ?? 'Unknown Test';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test: $testTitle',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Score: $score / $totalQuestions',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted: ${submissionTime.toDate().toLocal().toString().split('.')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
