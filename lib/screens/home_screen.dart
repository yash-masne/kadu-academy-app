// File: lib/screens/home_screen.dart

import 'dart:async'; // Required for Timer

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kadu_academy_app/screens/math_animation_widget.dart'; // MathAnimationWidget IMPORTED
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kadu_academy_app/widgets/student_achievement_carousel.dart'; // IMPORTANT: This must exist and be correct!
import 'package:kadu_academy_app/screens/dashboard_screen.dart';
import 'package:kadu_academy_app/screens2/buy_course_screen.dart';
import 'package:kadu_academy_app/screens2/free_zone_screen.dart';
import 'package:kadu_academy_app/screens2/basic_profile_screen.dart'; // Import the new screen
import 'package:kadu_academy_app/screens2/maintenance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentStudentId = 'anonymous_student';
  Map<String, dynamic>? _studentData;

  @override
  void initState() {
    super.initState();
    _initializeUserAndFetchData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // === User Data Fetching Methods (Essential for welcome message) ===
  Future<void> _initializeUserAndFetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _currentStudentId = user.uid);
      await _fetchStudentProfile(_currentStudentId);
    } else {
      await _signInAnonymously();
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      setState(() => _currentStudentId = userCredential.user!.uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get user ID for home: $e',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }
  }

  Future<void> _fetchStudentProfile(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _studentData = userDoc.data() as Map<String, dynamic>;
        });

        // --- NEW LOGIC: Check for missing profile fields and redirect ---
        final String? phoneNumber = _studentData?['phoneNumber'] as String?;
        final String? email = _studentData?['email'] as String?;
        final bool isBasicRegistration =
            _studentData?['isBasicRegistration'] ?? false;

        if (phoneNumber == null ||
            phoneNumber.isEmpty ||
            email == null ||
            email.isEmpty ||
            isBasicRegistration == false) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please complete your profile to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          // Redirect the user to the basic profile screen
          Navigator.pushReplacementNamed(context, '/basic_profile');
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Student profile not found. Please contact support.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load profile data: $e',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a StreamBuilder to listen for real-time changes to the maintenance flag
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('general')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isMaintenanceMode =
            snapshot.data?.get('isMaintenanceMode') ?? false;

        // If in maintenance mode, show the maintenance screen
        if (isMaintenanceMode) {
          return const MaintenanceScreen();
        }

        // If not in maintenance mode, proceed with the original home screen logic
        String studentFullName = 'Student';
        if (_studentData != null) {
          studentFullName =
              '${_studentData!['firstName'] ?? ''} ${_studentData!['lastName'] ?? ''}'
                  .trim();
        }

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User greeting
                  _studentData == null
                      ? const CircularProgressIndicator()
                      : Text.rich(
                          TextSpan(
                            text: 'Welcome, ',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                            children: [
                              TextSpan(
                                text: studentFullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: '!'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your learning journey begins here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // ... (The rest of your home screen content remains unchanged)
                  const Text(
                    'A Thought for Today',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2), // 8:32
                  const MathAnimationWidget(),
                  const SizedBox(height: 8),

                  const StudentAchievementCarousel(),
                  const SizedBox(height: 20),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('advertisements')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading ads: ${snapshot.error}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final ads = snapshot.data!.docs;
                      final adData = ads.first.data() as Map<String, dynamic>;
                      final String imageUrl =
                          adData['imageUrl'] ??
                          'https://placehold.co/600x200/cccccc/ffffff?text=No+Image';

                      final String title = adData['title'] ?? 'Advertisement';
                      final String subtitle = adData['title'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints constraints,
                                  ) {
                                    return AspectRatio(
                                      aspectRatio: 3 / 1,
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: constraints.maxWidth,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.0,
                                                    ),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: Colors.grey[300],
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Image Load Error',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                        fadeOutDuration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        fadeInDuration: const Duration(
                                          milliseconds: 700,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (subtitle.isNotEmpty)
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Howdy! What would you like to do Today?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActivityGrid(),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FREE Tests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFreeLiveTestsList(),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Popular Exams',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPopularExamsList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // === Helper methods (DEFINED ONLY ONCE HERE) ===

  Widget _buildCircularPercentage(
    int score,
    int totalQuestions,
    double radius,
    double fontSize,
  ) {
    if (totalQuestions == 0) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        alignment: Alignment.center,
        child: Text(
          'N/A',
          style: TextStyle(
            fontSize: fontSize * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      );
    }

    final percentage = (score / totalQuestions) * 100;
    final Color color = percentage < 30
        ? Colors.red
        : (percentage < 70 ? Colors.orange : Colors.green);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // Activity grid
  Widget _buildActivityGrid() {
    final activities = [
      {'icon': Icons.assignment, 'label': 'Take a Test'},
      {'icon': Icons.live_tv, 'label': 'Attend a Live'},
      {'icon': Icons.shopping_cart, 'label': 'Buy a Course'},
      {'icon': Icons.card_giftcard, 'label': 'Free Zone'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 0.8,
      ),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        // Determine the icon color based on the label
        Color iconColor;
        switch (activities[index]['label']) {
          case 'Take a Test':
            iconColor = Colors.blueAccent; // Blue
            break;
          case 'Attend a Live':
            iconColor = Colors.red; // YouTube Red
            break;
          case 'Buy a Course':
            iconColor = Colors.amber[700]!; // Rich Amber
            break;
          case 'Free Zone':
            iconColor = Colors.red; // Red for Gift
            break;
          default:
            iconColor = Colors.blueAccent; // Default color
        }

        return InkWell(
          onTap: () {
            try {
              final dashboardState = context
                  .findAncestorStateOfType<State<DashboardScreen>>();

              if (activities[index]['label'] == 'Take a Test') {
                (dashboardState as dynamic).onItemTapped(
                  2,
                ); // Index 2 for 'Tests' tab
              } else if (activities[index]['label'] == 'Attend a Live') {
                (dashboardState as dynamic).onItemTapped(
                  1,
                ); // Index 1 for 'Livestream' tab
              } else if (activities[index]['label'] == 'Buy a Course') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuyCourseScreen(),
                  ),
                );
              } else if (activities[index]['label'] == 'Free Zone') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FreeZoneScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Clicked ${activities[index]['label']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Navigation failed. Please check app configuration.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              );
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                activities[index]['icon'] as IconData,
                size: 30, // Keeping size as 30
                color: iconColor, // <-- APPLIED DYNAMIC COLOR HERE
              ),
              const SizedBox(height: 4),
              Text(
                activities[index]['label'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // Horizontal Free Tests list
  // ... (rest of your HomeScreen code above _buildFreeLiveTestsList)

  // Horizontal Free Tests list
  Widget _buildFreeLiveTestsList() {
    // Define your individual free test data with asset paths for icons
    final List<Map<String, dynamic>> freeTests = [
      {
        'name': 'SSC CGL Test',
        'icon': 'assets/icons/ssc_cgl_icon.png',
      }, // Path to your SSC CGL icon
      {
        'name': 'Banking Test',
        'icon': 'assets/icons/banking_icon.png',
      }, // Path to your Banking icon
      {
        'name': 'Regulatory Bodies',
        'icon': 'assets/icons/regulatory_icon.png',
      }, // Path to your Regulatory Bodies icon
      {
        'name': 'FCI Test',
        'icon': 'assets/icons/fci_icon.png',
      }, // Path to your FCI icon
      {
        'name': 'Scholarship Test',
        'icon': 'assets/icons/scholarship_icon.png',
      }, // Path to your Scholarship icon
      // Add more free tests with their respective asset paths
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: freeTests.length,
        itemBuilder: (context, index) {
          final test = freeTests[index];

          return InkWell(
            onTap: () {
              try {
                final dashboardState = context
                    .findAncestorStateOfType<State<DashboardScreen>>();
                (dashboardState as dynamic).onItemTapped(
                  2,
                ); // Navigate to 'Tests' tab (index 2)
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Failed to go to Tests section. Please try again.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor:
                        Colors.transparent, // <-- CHANGED TO Colors.transparent
                    child: Image.asset(
                      test['icon'] as String,
                      width: 45, // Set the desired width for your image
                      height: 45, // Set the desired height for your image
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    test['name'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ... (rest of your HomeScreen code below _buildFreeLiveTestsList)
  // Horizontal Popular Exams list
  Widget _buildPopularExamsList() {
    // Define your individual popular exam data with asset paths for icons
    final List<Map<String, dynamic>> popularExams = [
      {
        'name': 'Railway Services',
        'icon': 'assets/icons/railway_services_icon.png',
      }, // Path to your Railway Services icon

      {
        'name': 'Banking Services',
        'icon': 'assets/icons/banking_services_icon.png',
      }, // Path to your Banking Services icon
      {
        'name': 'MBA - CET',
        'icon': 'assets/icons/mba_cet_icon.png',
      }, // Path to your MBA - CET icon
      {
        'name': 'HSC Exam',
        'icon': 'assets/icons/hsc_icon.png',
      }, // Path to your HSC icon

      {
        'name': 'Police Services',
        'icon': 'assets/icons/police_services_icon.png',
      }, // Path to your Police Services icon
      // Add more popular exams with their respective asset paths
    ];

    return SizedBox(
      height: 100, // Fixed height for the horizontal list
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularExams.length, // Use the count of your defined exams
        itemBuilder: (context, index) {
          final exam = popularExams[index]; // Get the data for the current exam

          return InkWell(
            child: Container(
              width: 80, // Fixed width for each item
              margin: const EdgeInsets.only(right: 10), // Spacing between items
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor:
                        Colors.transparent, // <-- CHANGED TO Colors.transparent
                    child: Image.asset(
                      // CHANGED TO Image.asset
                      exam['icon'] as String, // Use the asset path string
                      width: 40, // Set the desired width for your image
                      height: 40, // Set the desired height for your image
                      // You might want to add fit: BoxFit.contain or BoxFit.cover depending on your image aspect ratio
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    exam['name'] as String, // Use the name from your data
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9),
                    maxLines: 2, // Allow text to wrap if long
                    overflow: TextOverflow
                        .ellipsis, // Add ellipsis if text is too long
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Simple placeholder banner for other StreamBuilders (not the carousel one)
  Widget _placeholderBanner(String imageUrl) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 5.0),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2.0),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  alignment: Alignment.center,
                  child: const Text(
                    'Image Load Error',
                    style: TextStyle(color: Colors.red, fontSize: 10),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
