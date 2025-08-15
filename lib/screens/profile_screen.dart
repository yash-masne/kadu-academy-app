import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/percent_indicator.dart'; // For circular percentage indicator

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _currentStudentId;
  Map<String, dynamic>? _studentData;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _initializeUserProfile();
  }

  Future<void> _initializeUserProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentStudentId = user.uid;
        _isLoadingProfile = true;
      });
      await _fetchStudentProfile(_currentStudentId!);
    } else {
      setState(() {
        _isLoadingProfile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in to view profile.')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  Future<void> _fetchStudentProfile(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _studentData = userDoc.data() as Map<String, dynamic>;
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Student profile data not found. Please contact support.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingProfile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile data: $e')),
        );
      }
    }
  }

  // Helper to build circular percentage indicator with corrected logic
  Widget _buildCircularPercentageIndicator(
    double averageScore,
    double radius,
    double lineWidth,
  ) {
    String percentageText = (averageScore.isNaN)
        ? 'N/A'
        : '${(averageScore).toStringAsFixed(0)}%';

    Color progressColor;
    if (averageScore < 35) {
      progressColor = Colors.red;
    } else if (averageScore < 50) {
      progressColor = Colors.orange;
    } else if (averageScore < 75) {
      progressColor = Colors.blueAccent;
    } else {
      progressColor = Colors.green;
    }

    return CircularPercentIndicator(
      radius: radius,
      lineWidth: lineWidth,
      percent: averageScore / 100, // Use score directly as percentage
      center: Text(
        percentageText,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.4,
          color: progressColor,
        ),
      ),
      progressColor: progressColor,
      backgroundColor: Colors.grey[300]!,
      circularStrokeCap: CircularStrokeCap.round,
      animation: true,
      animateFromLastPercent: true,
    );
  }

  // Helper widget to build a consistent detail row
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigo, size: 24),
          const SizedBox(width: 15),
          Text(
            '$label $value',
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String fullName = 'Loading...';
    String rollNo = 'Loading...';
    String phoneNumberDisplay = 'Loading...';
    String studentType = 'Loading...';
    String branch = 'Loading...';
    String year = 'Loading...';
    List<String> courses = [];
    bool isApproved = false;

    if (!_isLoadingProfile && _studentData != null) {
      fullName =
          '${_studentData!['firstName'] ?? ''} ${_studentData!['lastName'] ?? ''}'
              .trim();
      rollNo = _studentData!['rollNo'] ?? 'N/A';
      studentType = _studentData!['studentType'] ?? 'N/A';

      // Dynamically assign branch/year or courses based on student type
      if (studentType == 'college') {
        branch = _studentData!['branch'] ?? 'N/A';
        year = _studentData!['year'] ?? 'N/A';
        isApproved = _studentData!['isApprovedByAdminCollegeStudent'] ?? false;
      } else if (studentType == 'kadu_academy') {
        courses = List<String>.from(_studentData!['courses'] ?? []);
        isApproved = _studentData!['isApprovedByAdminKaduAcademy'] ?? false;
      }

      String rawPhoneNumber = _studentData!['phoneNumber'] ?? 'N/A';
      if (rawPhoneNumber.startsWith('+91')) {
        phoneNumberDisplay = '+91 ${rawPhoneNumber.substring(3)}';
      } else {
        phoneNumberDisplay = rawPhoneNumber;
      }
    } else if (!_isLoadingProfile && _studentData == null) {
      fullName = 'N/A (Profile Not Found)';
      rollNo = 'N/A';
      phoneNumberDisplay = 'N/A';
      studentType = 'N/A';
    }

    // New logic to display student type
    String studentTypeDisplay;
    if (studentType == 'college') {
      studentTypeDisplay = 'College Student';
    } else if (studentType == 'kadu_academy') {
      studentTypeDisplay = 'Kadu Academy Student';
    } else {
      studentTypeDisplay = 'Not Applicable';
    }

    return Scaffold(
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo + Name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.blueGrey,
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Student Details List
                    _buildDetailRow(
                      Icons.account_circle,
                      'Student Type:',
                      studentTypeDisplay,
                    ),
                    _buildDetailRow(Icons.phone, 'Phone:', phoneNumberDisplay),

                    // Display details based on student type
                    if (studentType == 'college') ...[
                      _buildDetailRow(Icons.badge, 'Roll No:', rollNo),
                      _buildDetailRow(Icons.account_tree, 'Branch:', branch),
                      _buildDetailRow(Icons.calendar_today, 'Year:', year),
                    ],
                    if (studentType == 'kadu_academy')
                      _buildDetailRow(
                        Icons.school,
                        'Courses:',
                        courses.join(', '),
                      ),
                    const SizedBox(height: 30),
                    const Divider(thickness: 1),
                    const SizedBox(height: 20),

                    // Overall Test Performance Section
                    const Text(
                      'Overall Test Performance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: _currentStudentId == null
                          ? const Text('Login to view your performance.')
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('studentTestSessions')
                                  .where(
                                    'studentId',
                                    isEqualTo: _currentStudentId,
                                  )
                                  .where('status', isEqualTo: 'completed')
                                  .snapshots(),
                              builder: (context, sessionSnapshot) {
                                if (sessionSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildCircularPercentageIndicator(
                                    0,
                                    80,
                                    10,
                                  );
                                }
                                if (sessionSnapshot.hasError) {
                                  return _buildCircularPercentageIndicator(
                                    0,
                                    80,
                                    10,
                                  );
                                }
                                if (!sessionSnapshot.hasData ||
                                    sessionSnapshot.data!.docs.isEmpty) {
                                  return Column(
                                    children: [
                                      _buildCircularPercentageIndicator(
                                        0,
                                        80,
                                        10,
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'No completed tests found.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // FIX: Use FutureBuilder to correctly fetch marksPerQuestion
                                return FutureBuilder<List<DocumentSnapshot>>(
                                  future: Future.wait(
                                    sessionSnapshot.data!.docs.map((
                                      sessionDoc,
                                    ) {
                                      final testId = sessionDoc['testId'];
                                      return FirebaseFirestore.instance
                                          .collection('tests')
                                          .doc(testId)
                                          .get();
                                    }),
                                  ),
                                  builder: (context, testSnapshot) {
                                    if (testSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const CircularProgressIndicator();
                                    }
                                    if (testSnapshot.hasError) {
                                      return const Text(
                                        'Error calculating percentage.',
                                      );
                                    }

                                    double totalOverallScore = 0.0;
                                    double totalPossibleMarks = 0.0;

                                    if (testSnapshot.hasData) {
                                      for (
                                        int i = 0;
                                        i < sessionSnapshot.data!.docs.length;
                                        i++
                                      ) {
                                        final sessionData =
                                            sessionSnapshot.data!.docs[i].data()
                                                as Map<String, dynamic>;
                                        final testData =
                                            testSnapshot.data![i].data()
                                                as Map<String, dynamic>;

                                        final score =
                                            (sessionData['score'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        final totalQuestions =
                                            (testData['totalQuestions']
                                                as int?) ??
                                            0; // Use testData
                                        final marksPerQuestion =
                                            (testData['marksPerQuestion']
                                                    as num?)
                                                ?.toDouble() ??
                                            1.0;

                                        totalOverallScore += score;
                                        totalPossibleMarks +=
                                            totalQuestions * marksPerQuestion;
                                      }
                                    }

                                    double clampedPercentage =
                                        (totalPossibleMarks > 0)
                                        ? (totalOverallScore /
                                                      totalPossibleMarks)
                                                  .clamp(0.0, 1.0) *
                                              100
                                        : 0.0;

                                    return _buildCircularPercentageIndicator(
                                      clampedPercentage, // Pass the clamped value
                                      80,
                                      10,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
