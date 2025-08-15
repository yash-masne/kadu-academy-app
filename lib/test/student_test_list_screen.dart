// File: lib/screens/student_test_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // NEW: FCM import

// Ensure these paths are correct for your project
import 'package:kadu_academy_app/test/student_take_test_screen.dart';
import 'package:kadu_academy_app/screens/student_test_review_screen.dart';
import 'package:kadu_academy_app/utils/firestore_extensions.dart'; // IMPORTANT: Using the provided QueryExtension

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you use other Firebase services in your background handler,
  // it is recommended to call `initializeApp` before using them.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

// =========================================================================
// SECTION 1: UserProfile Model - Updated for clarity and robustness
// =========================================================================
class UserProfile {
  final String uid;
  final bool isRegistered;
  final String
  studentType; // Now non-nullable, defaults to 'unknown' in factory
  final bool isApprovedByAdminKaduAcademy;
  final bool isApprovedByAdminCollegeStudent;
  final bool isDenied;
  final List<String> courses;
  final List<String> branches;
  final List<String> years;

  UserProfile({
    required this.uid,
    required this.isRegistered,
    required this.studentType,
    required this.isApprovedByAdminKaduAcademy,
    required this.isApprovedByAdminCollegeStudent,
    required this.isDenied,
    required this.courses,
    required this.branches,
    required this.years,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    final String safeStudentType =
        (data['studentType'] as String?) ?? 'unknown';

    final List<String> parsedCourses = (data['courses'] is List)
        ? List<String>.from(data['courses'])
        : [];
    final List<String> parsedBranches = (data['branches'] is List)
        ? List<String>.from(data['branches'])
        : [];
    final List<String> parsedYears = (data['years'] is List)
        ? List<String>.from(data['years'])
        : [];

    return UserProfile(
      uid: doc.id,
      isRegistered: data['isRegistered'] ?? false,
      studentType: safeStudentType,
      isApprovedByAdminKaduAcademy:
          data['isApprovedByAdminKaduAcademy'] ?? false,
      isApprovedByAdminCollegeStudent:
          data['isApprovedByAdminCollegeStudent'] ?? false,
      isDenied: data['isDenied'] ?? false,
      courses: parsedCourses,
      branches: parsedBranches,
      years: parsedYears,
    );
  }
}

// =========================================================================
// SECTION 2: StudentTestListScreen Widget State
// =========================================================================
class StudentTestListScreen extends StatefulWidget {
  const StudentTestListScreen({super.key});

  @override
  State<StudentTestListScreen> createState() => _StudentTestListScreenState();
}

class _StudentTestListScreenState extends State<StudentTestListScreen> {
  // =========================================================================
  // SECTION 2.1: Initialization and Authentication Logic
  // =========================================================================
  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser == null) {
      _signInAnonymously();
    } else {
      _setupFCM(); // NEW: Call FCM setup after a user is authenticated
    }
  }

  // This is a top-level function, so it can't be a method of a class.

  // NEW: Function to set up Firebase Cloud Messaging
  Future<void> _setupFCM() async {
    final fcm = FirebaseMessaging.instance;
    // Request permission from the user
    final settings = await fcm.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the FCM token
      final token = await fcm.getToken();

      if (token != null && FirebaseAuth.instance.currentUser != null) {
        // Save the token to the user's Firestore profile
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.notification!.body!),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });

      // NEW: Handle user tapping on a notification when the app is in the background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        if (message.data.containsKey('testId')) {
          // Navigate to the tests screen or a specific test
          Navigator.pushNamed(context, '/test_list');
        }
      });

      // NEW: Handle notification when the app is terminated
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        if (initialMessage.data.containsKey('testId')) {
          Navigator.pushNamed(context, '/test_list');
        }
      }
    } else {}
  }

  Future<void> _signInAnonymously() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInAnonymously();
      _setupFCM(); // NEW: Call FCM setup after successful anonymous sign-in
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${e.message}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred during sign-in: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
          ),
        );
      }
    }
  }

  // =========================================================================
  // SECTION 2.2: Test Session Management Logic (retained from previous working versions)
  // =========================================================================
  Future<void> _startTestSession(
    BuildContext context,
    String testId,
    String testTitle,
    int testDurationMinutes,
    bool allowStudentReview,
    String currentStudentId,
  ) async {
    DocumentSnapshot testDoc = await FirebaseFirestore.instance
        .collection('tests')
        .doc(testId)
        .get();
    if (!testDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test not found or no longer exists.')),
        );
      }
      return;
    }
    Map<String, dynamic> currentTestData =
        testDoc.data() as Map<String, dynamic>;
    final Timestamp? scheduledPublishTime =
        currentTestData['scheduledPublishTime'] as Timestamp?;
    final Timestamp? globalExpiryTime =
        currentTestData['globalExpiryTime'] as Timestamp?;
    final bool isPublished = currentTestData['isPublished'] ?? false;
    final bool isArchived = currentTestData['isArchived'] ?? false;

    final DateTime now = DateTime.now();

    bool isActuallyAvailableToStart =
        isPublished &&
        !isArchived &&
        (scheduledPublishTime == null ||
            now.isAfter(scheduledPublishTime.toDate())) &&
        (globalExpiryTime == null || now.isBefore(globalExpiryTime.toDate()));

    if (!isActuallyAvailableToStart) {
      String message = 'This test is not currently available to start.';
      if (scheduledPublishTime != null &&
          now.isBefore(scheduledPublishTime.toDate())) {
        message =
            'This test is scheduled to start on ${DateFormat('MMM d, yyyy hh:mm a').format(scheduledPublishTime.toDate().toLocal())}.';
      } else if (isArchived) {
        message = 'This test has been archived and is unavailable.';
      } else if (globalExpiryTime != null &&
          now.isAfter(globalExpiryTime.toDate())) {
        message = 'This test has already expired.';
      } else if (!isPublished) {
        message = 'This test is not currently published by the admin.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    QuerySnapshot existingSessions = await FirebaseFirestore.instance
        .collection('studentTestSessions')
        .where('studentId', isEqualTo: currentStudentId)
        .where('testId', isEqualTo: testId)
        .where('status', isNotEqualTo: 'completed')
        .get();

    if (existingSessions.docs.isNotEmpty) {
      DocumentSnapshot existingSessionDoc = existingSessions.docs.first;
      String existingSessionId = existingSessionDoc.id;

      // FIX: Immediately navigate to the pre-test screen with the existing session ID.
      // This correctly handles both 'pre_test' and 'in_progress' sessions.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resuming existing session for "$testTitle"...'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
          ),
        );
        Navigator.pushNamed(
          context,
          '/pre_test_instructions',
          arguments: {
            'testId': testId,
            'studentTestSessionId': existingSessionId,
            'testDurationMinutes': testDurationMinutes,
            'testTitle': testTitle,
            'allowStudentReview': allowStudentReview,
          },
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Starting new test session for "$testTitle"...'),
          // --- MODIFIED PROPERTIES BELOW ---
          duration: const Duration(seconds: 1), // Sets the duration to 1 second
          behavior: SnackBarBehavior
              .floating, // Allows for margin and rounded corners
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Adds rounded corners
          ),
          margin: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 10.0,
          ), // Adds margin
          padding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ), // Makes the content area smaller
        ),
      );
    }

    try {
      DocumentReference sessionDocRef = await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .add({
            'studentId': currentStudentId,
            'testId': testId,
            'status': 'pre_test', // Set a new status to indicate pre-test phase
            'answers': {},
            'score': null,
            'totalQuestions': 0,
          });
      final String studentTestSessionId = sessionDocRef.id;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test "$testTitle" session started!'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
          ),
        );

        Navigator.pushNamed(
          context,
          '/pre_test_instructions',
          arguments: {
            'testId': testId,
            'studentTestSessionId': studentTestSessionId,
            'testDurationMinutes': testDurationMinutes,
            'testTitle': testTitle,
            'allowStudentReview': allowStudentReview,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start test session: $e')),
        );
      }
    }
  }

  // MODIFIED: Pass currentUid (studentId) to the review screen
  void _navigateToReviewScreen(
    BuildContext context,
    String testId,
    String testTitle,
    String currentStudentId,
  ) {
    Navigator.pushNamed(
      context,
      '/student_test_review',
      arguments: {
        'testId': testId,
        'testTitle': testTitle,
        'studentId': currentStudentId, // Pass the studentId
      },
    );
  }

  // Helper function to map internal test types to user-friendly display labels
  // This uses the new boolean flags in test documents.
  String _mapInternalTestTypeToDisplay(
    bool isFree,
    bool isPaidCollege,
    bool isPaidKaduAcademy,
  ) {
    if (isFree) return 'Free Test';
    if (isPaidCollege && isPaidKaduAcademy) return 'Paid (College & Kadu)';
    if (isPaidCollege) return 'Paid (College)';
    if (isPaidKaduAcademy) return 'Paid (Kadu Academy)';
    return 'Undefined Type'; // Should not happen if data is well-formed
  }

  // =========================================================================
  // SECTION 3: Main Widget Build Method - Core Logic for Displaying Tests
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('dd-MMM-yy hh:mm a'); // MODIFIED

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Available Tests', // Smaller title text
          style: TextStyle(fontSize: 16), // Make it smaller
        ),
        centerTitle: true, // Center the title if desired
        actions: [
          // Subscribed status/logo on the rightmost corner
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(
                  FirebaseAuth.instance.currentUser?.uid,
                ) // Use current user UID
                .snapshots(),
            builder: (context, userProfileSnapshot) {
              if (userProfileSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              // If there's an error, no data, or user doc doesn't exist, treat as Not Subscribed/Free
              if (userProfileSnapshot.hasError ||
                  !userProfileSnapshot.hasData ||
                  !userProfileSnapshot.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Chip(
                    label: Text(
                      'Not Subscribed',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: Colors.grey,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact, // Make it smaller
                  ),
                );
              }

              final UserProfile userProfile = UserProfile.fromFirestore(
                userProfileSnapshot.data!,
              );
              bool isKaduApproved =
                  userProfile.studentType == 'kadu_academy' &&
                  userProfile.isApprovedByAdminKaduAcademy;
              bool isCollegeApproved =
                  userProfile.studentType == 'college' &&
                  userProfile.isApprovedByAdminCollegeStudent;

              Widget statusChip;
              if (isKaduApproved || isCollegeApproved) {
                statusChip = const Chip(
                  label: Text(
                    'Subscribed',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.green, // Aesthetic color
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact, // Make it smaller
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ), // Adjust padding for smaller size
                );
              } else {
                statusChip = const Chip(
                  label: Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.blueGrey, // Aesthetic color
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact, // Make it smaller
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ), // Adjust padding for smaller size
                );
              }
              return Padding(
                padding: const EdgeInsets.only(
                  right: 8.0,
                ), // Padding to keep it from edge
                child: Center(
                  child: statusChip,
                ), // Center vertically within the app bar height
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!authSnapshot.hasData || authSnapshot.data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Please sign in to view tests. If this persists, restart the app.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final String currentUid = authSnapshot.data!.uid;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid)
                .snapshots(),
            builder: (context, userProfileSnapshot) {
              if (userProfileSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                );
              }

              if (userProfileSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading your profile: ${userProfileSnapshot.error}\nCannot determine test access.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              UserProfile currentUserProfile = UserProfile(
                uid: currentUid,
                isRegistered: false,
                studentType: 'unknown',
                isApprovedByAdminKaduAcademy: false,
                isApprovedByAdminCollegeStudent: false,
                isDenied: false,
                courses: [],
                branches: [],
                years: [],
              );

              if (userProfileSnapshot.hasData &&
                  userProfileSnapshot.data!.exists) {
                currentUserProfile = UserProfile.fromFirestore(
                  userProfileSnapshot.data!,
                );
              } else {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .set({
                      'uid': currentUid,
                      'email': authSnapshot.data!.email,
                      'createdAt': FieldValue.serverTimestamp(),
                      'studentType': 'unknown',
                      'isRegistered': false,
                      'isApprovedByAdminKaduAcademy': false,
                      'isApprovedByAdminCollegeStudent': false,
                      'isDenied': false,
                      'courses': [],
                      'branches': [],
                      'years': [],
                      'role': 'student',
                    }, SetOptions(merge: true));
              }

              Query testsQuery = FirebaseFirestore.instance.collection('tests');

              // --- MODIFIED: Query is now a simple fetch of non-archived tests.
              // We will perform all complex filtering on the client side to correctly
              // handle 'published' OR 'scheduled' tests. ---
              testsQuery = testsQuery
                  .where('isArchived', isEqualTo: false)
                  .orderBy('createdAt', descending: false);

              return StreamBuilder<QuerySnapshot>(
                stream: testsQuery.snapshots(),
                builder: (context, testSnapshot) {
                  if (testSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (testSnapshot.hasError) {
                    return Center(child: Text('Error: ${testSnapshot.error}'));
                  }

                  if (!testSnapshot.hasData ||
                      testSnapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'There are no tests available at the moment. Please check back soon.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final DateTime now = DateTime.now();
                  final List<DocumentSnapshot>
                  availableTests = testSnapshot.data!.docs.where((testDoc) {
                    final testData = testDoc.data() as Map<String, dynamic>;
                    final String testTitle = testData['title'] ?? 'No Title';

                    final Timestamp? globalExpiryTime =
                        testData['globalExpiryTime'] as Timestamp?;
                    final Timestamp? scheduledPublishTime =
                        testData['scheduledPublishTime'] as Timestamp?;

                    bool isGloballyExpired =
                        globalExpiryTime != null &&
                        now.isAfter(globalExpiryTime.toDate());
                    bool isScheduledForFuture =
                        scheduledPublishTime != null &&
                        now.isBefore(scheduledPublishTime.toDate());

                    final bool isPublished = testData['isPublished'] ?? false;
                    final bool isArchived = testData['isArchived'] ?? false;

                    final bool isDisplayable =
                        (isPublished && !isArchived) ||
                        (isScheduledForFuture && !isArchived) ||
                        (isGloballyExpired && !isArchived);
                    if (!isDisplayable) {
                      return false;
                    }

                    // The rest of the user filtering logic remains untouched
                    bool isAccessible = false;
                    bool testIsFree = (testData['isFree'] ?? false);
                    bool testIsPaidCollege =
                        (testData['isPaidCollege'] ?? false);
                    bool testIsPaidKaduAcademy =
                        (testData['isPaidKaduAcademy'] ?? false);
                    bool userIsDenied = currentUserProfile.isDenied;
                    bool userIsRegistered = currentUserProfile.isRegistered;
                    String userStudentType = currentUserProfile.studentType;
                    bool userIsApprovedCollege =
                        currentUserProfile.isApprovedByAdminCollegeStudent;
                    bool userIsApprovedKaduAcademy =
                        currentUserProfile.isApprovedByAdminKaduAcademy;
                    List<String> userCourses = currentUserProfile.courses;
                    List<String> userBranches = currentUserProfile.branches;
                    List<String> userYears = currentUserProfile.years;

                    // --- ACCESSIBILITY LOGIC (Updated to hide Free tests from paid users) ---
                    if (userIsDenied ||
                        !userIsRegistered ||
                        userStudentType == 'unknown' ||
                        (userStudentType == 'college' &&
                            !userIsApprovedCollege) ||
                        (userStudentType == 'kadu_academy' &&
                            !userIsApprovedKaduAcademy)) {
                      // Denied, Unregistered, Unknown type, or Unapproved: ONLY Free tests
                      isAccessible = testIsFree;
                    } else if (userStudentType == 'college' &&
                        userIsApprovedCollege) {
                      // Approved College Student: Can ONLY see Paid College tests that match criteria
                      if (testIsPaidCollege) {
                        final List<String> testAllowedBranches =
                            (testData['allowedBranches'] is List)
                            ? List<String>.from(testData['allowedBranches'])
                            : [];
                        final List<String> testAllowedYears =
                            (testData['allowedYears'] is List)
                            ? List<String>.from(testData['allowedYears'])
                            : [];
                        final List<String> testAllowedCourses =
                            (testData['allowedCourses'] is List)
                            ? List<String>.from(testData['allowedCourses'])
                            : [];

                        bool isBranchMatch = true;
                        if (testAllowedBranches.isNotEmpty) {
                          isBranchMatch = userBranches.any(
                            (userB) => testAllowedBranches.contains(userB),
                          );
                        }

                        bool isYearMatch = true;
                        if (testAllowedYears.isNotEmpty) {
                          isYearMatch = userYears.any(
                            (userY) => testAllowedYears.contains(userY),
                          );
                        }

                        bool isCourseMatch = true;
                        if (testAllowedCourses.isNotEmpty) {
                          isCourseMatch = userCourses.any(
                            (userC) => testAllowedCourses.contains(userC),
                          );
                        }

                        isAccessible =
                            isBranchMatch && isYearMatch && isCourseMatch;
                      } else {
                        isAccessible =
                            false; // Not a paid college test, so not accessible.
                      }
                    } else if (userStudentType == 'kadu_academy' &&
                        userIsApprovedKaduAcademy) {
                      // Approved Kadu Academy Student: Can ONLY see Paid Kadu Academy tests that match courses
                      if (testIsPaidKaduAcademy) {
                        final List<String> testAllowedCourses =
                            (testData['allowedCourses'] is List)
                            ? List<String>.from(testData['allowedCourses'])
                            : [];

                        bool isCourseMatch = true;
                        if (testAllowedCourses.isNotEmpty) {
                          isCourseMatch = userCourses.any(
                            (userC) => testAllowedCourses.contains(userC),
                          );
                        }

                        isAccessible = isCourseMatch;
                      } else {
                        isAccessible =
                            false; // Not a paid Kadu test, so not accessible.
                      }
                    } else {
                      // Fallback for any other unhandled student type / state combination: Only Free tests
                      isAccessible = testIsFree;
                    }

                    return isAccessible &&
                        isDisplayable; // Final check for both conditions
                  }).toList();

                  // Sort the filtered tests (prioritize scheduled, then active, then by title)
                  availableTests.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aScheduled =
                        aData['scheduledPublishTime'] as Timestamp?;
                    final bScheduled =
                        bData['scheduledPublishTime'] as Timestamp?;

                    // Prioritize scheduled tests at the top
                    bool aIsScheduledForFuture =
                        aScheduled != null && now.isBefore(aScheduled.toDate());
                    bool bIsScheduledForFuture =
                        bScheduled != null && now.isBefore(bScheduled.toDate());

                    // Published, scheduled, and expired tests all get a spot.
                    final aIsPublished = aData['isPublished'] ?? false;
                    final bIsPublished = bData['isPublished'] ?? false;
                    final aIsExpired =
                        (aData['globalExpiryTime'] as Timestamp?)
                            ?.toDate()
                            .isBefore(now) ??
                        false;
                    final bIsExpired =
                        (bData['globalExpiryTime'] as Timestamp?)
                            ?.toDate()
                            .isBefore(now) ??
                        false;

                    // Sort order: Scheduled (by time) -> Published (by creation time) -> Expired (by expiry time)
                    if (aIsScheduledForFuture &&
                        !bIsScheduledForFuture &&
                        !bIsExpired)
                      return -1;
                    if (!aIsScheduledForFuture &&
                        bIsScheduledForFuture &&
                        !aIsExpired)
                      return 1;
                    if (aIsScheduledForFuture && bIsScheduledForFuture) {
                      return aScheduled!.toDate().compareTo(
                        bScheduled!.toDate(),
                      );
                    }

                    if (aIsPublished && !bIsPublished && !bIsExpired) return -1;
                    if (!aIsPublished && bIsPublished && !aIsExpired) return 1;

                    if (aIsExpired && !bIsExpired) return 1;
                    if (!aIsExpired && bIsExpired) return -1;
                    if (aIsExpired && bIsExpired) {
                      return (aData['globalExpiryTime'] as Timestamp)
                          .toDate()
                          .compareTo(
                            (bData['globalExpiryTime'] as Timestamp).toDate(),
                          );
                    }

                    return (aData['title'] as String? ?? '').compareTo(
                      bData['title'] as String? ?? '',
                    );
                  });

                  // 3.4.3. Handle Empty Test List after Client-Side Filtering (Simplified messages)
                  if (availableTests.isEmpty) {
                    // Generic message, as requested
                    String message =
                        'No tests available for your profile at the moment.';

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(message, textAlign: TextAlign.center),
                      ),
                    );
                  }

                  // 3.5. StreamBuilder for student test sessions (to determine individual test status)
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('studentTestSessions')
                        .where('studentId', isEqualTo: currentUid)
                        .snapshots(),
                    builder: (context, sessionSnapshot) {
                      if (sessionSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (sessionSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading your test status: ${sessionSnapshot.error}',
                          ),
                        );
                      }

                      // Map testId to its session data for quick lookup
                      final Map<String, Map<String, dynamic>> studentSessions =
                          {};
                      for (var doc in sessionSnapshot.data!.docs) {
                        studentSessions[doc['testId']] = {
                          ...(doc.data() as Map<String, dynamic>),
                          'id': doc.id,
                        };
                      }

                      // 3.6. Build the ListView of tests
                      return ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: availableTests.length,
                        itemBuilder: (context, index) {
                          DocumentSnapshot testDocument = availableTests[index];
                          Map<String, dynamic> testData =
                              testDocument.data() as Map<String, dynamic>;

                          String accessTypeDisplay =
                              _mapInternalTestTypeToDisplay(
                                testData['isFree'] ?? false,
                                testData['isPaidCollege'] ?? false,
                                testData['isPaidKaduAcademy'] ?? false,
                              );

                          String testId = testDocument.id;
                          String title = testData['title'] ?? 'No Title';
                          String description =
                              testData['description'] ?? 'No Description';
                          int duration = testData['durationMinutes'] ?? 0;
                          Timestamp? globalExpiryTime =
                              testData['globalExpiryTime'] as Timestamp?;
                          Timestamp? scheduledPublishTime =
                              testData['scheduledPublishTime'] as Timestamp?;
                          bool allowStudentReview =
                              testData['allowStudentReview'] ?? false;
                          bool isPublishedByAdmin =
                              testData['isPublished'] ?? false;
                          bool isArchived = testData['isArchived'] ?? false;
                          int totalQuestions =
                              testData['totalQuestions'] ??
                              0; // Get total questions from test data
                          double marksPerQuestion =
                              (testData['marksPerQuestion'] as num?)
                                  ?.toDouble() ??
                              1.0;
                          // MODIFIED: Retrieve negativeMarksValue
                          final double negativeMarksValue =
                              (testData['negativeMarksValue'] as num?)
                                  ?.toDouble() ??
                              0.0;
                          double totalPossibleMarks =
                              totalQuestions * marksPerQuestion;

                          String buttonText = 'Start Test';
                          Color buttonColor = Colors.blue;
                          VoidCallback? onPressedAction;
                          bool showReviewButton = false;

                          Map<String, dynamic>? studentSession =
                              studentSessions[testId];

                          bool hasSession = studentSession != null;
                          String sessionStatus = hasSession
                              ? studentSession['status'] ?? 'no_session'
                              : 'no_session';
                          Timestamp? sessionEndTime = hasSession
                              ? studentSession['studentEndTime'] as Timestamp?
                              : null;

                          // Define hasCompletedSession and isStudentAttemptExpired locally
                          final bool hasCompletedSession =
                              (hasSession && sessionStatus == 'completed');
                          final bool isStudentAttemptExpired =
                              (hasSession &&
                              sessionStatus == 'in_progress' &&
                              sessionEndTime != null &&
                              now.isAfter(sessionEndTime.toDate()));

                          bool isScheduledForFuture =
                              scheduledPublishTime != null &&
                              now.isBefore(scheduledPublishTime.toDate());
                          bool isGloballyExpired =
                              globalExpiryTime != null &&
                              now.isAfter(globalExpiryTime.toDate());

                          bool isCurrentlyAvailableToStart =
                              isPublishedByAdmin &&
                              !isScheduledForFuture &&
                              !isGloballyExpired &&
                              !isArchived;

                          // MODIFIED: Calculate percentage here, before the Card widget
                          double? calculatedPercentage;
                          double studentScore =
                              (studentSession?['score'] as num?)?.toDouble() ??
                              0.0;
                          if (hasCompletedSession && studentSession != null) {
                            calculatedPercentage =
                                (studentScore / totalPossibleMarks) * 100;
                          }

                          if (hasCompletedSession) {
                            buttonText = 'Completed';
                            buttonColor = Colors.green;
                            onPressedAction = null;
                            showReviewButton = allowStudentReview;
                          } else if (isStudentAttemptExpired) {
                            buttonText = 'Attempt Expired';
                            buttonColor = Colors.red;
                            onPressedAction = null;
                            showReviewButton = allowStudentReview;
                          } else if (sessionStatus == 'in_progress' ||
                              sessionStatus == 'pre_test') {
                            // New condition for an ongoing session
                            buttonText = 'Resume Test';
                            buttonColor = Colors.orange;
                            onPressedAction = () => _startTestSession(
                              context,
                              testId,
                              title,
                              duration,
                              allowStudentReview,
                              currentUid,
                            );
                          } else if (isScheduledForFuture) {
                            // --- NEW LOGIC for scheduled tests ---
                            buttonText = 'Scheduled';
                            buttonColor = Colors.grey;
                            onPressedAction = null; // Cannot be pressed yet
                          } else if (isGloballyExpired) {
                            // MODIFIED: Logic for expired tests
                            buttonText = 'Unavailable';
                            buttonColor = Colors.red;
                            onPressedAction = null;
                            if (hasCompletedSession) {
                              showReviewButton = allowStudentReview;
                            }
                          } else if (isCurrentlyAvailableToStart) {
                            buttonText = 'Start Test';
                            buttonColor = Colors.blue;
                            onPressedAction = () => _startTestSession(
                              context,
                              testId,
                              title,
                              duration,
                              allowStudentReview,
                              currentUid,
                            );
                          } else {
                            buttonText = 'Unavailable';
                            buttonColor = Colors.grey;
                            onPressedAction = null;
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18, // Slightly smaller
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 14, // Slightly smaller
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Display Test Type
                                  Text(
                                    'Test Type: $accessTypeDisplay',
                                    style: TextStyle(
                                      fontSize: 11, // Smaller
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo[700],
                                    ),
                                  ),

                                  // --- NEW: Universal display of global expiry time ---
                                  const SizedBox(height: 8),
                                  // Display Duration, Total Questions, Total Marks, and Negative Marking status
                                  Text(
                                    'Duration: $duration minutes | Questions: $totalQuestions | Total Marks: ${totalPossibleMarks.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 12, // Smaller
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  // MODIFIED: Show Negative Marks if value is > 0
                                  if (negativeMarksValue > 0)
                                    Text(
                                      'NOTE : Negative Marking (-${negativeMarksValue.toStringAsFixed(2)} per wrong answer)',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  // Display Branches and Years for College Tests
                                  if (testData['isPaidCollege'] == true &&
                                      (testData['allowedBranches'] is List &&
                                              (testData['allowedBranches']
                                                      as List)
                                                  .isNotEmpty ||
                                          testData['allowedYears'] is List &&
                                              (testData['allowedYears'] as List)
                                                  .isNotEmpty))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'For: ${((testData['allowedBranches'] as List?)?.join(', ') ?? '')}'
                                        '${(testData['allowedBranches'] is List && (testData['allowedBranches'] as List).isNotEmpty && testData['allowedYears'] is List && (testData['allowedYears'] as List).isNotEmpty ? ' - ' : '')}'
                                        '${((testData['allowedYears'] as List?)?.join(', ') ?? '')}',
                                        style: const TextStyle(
                                          fontSize: 10, // Smaller
                                          fontStyle: FontStyle.italic,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ),
                                  // Display Courses for Kadu Academy Tests (and potentially College if allowedCourses used)
                                  if ((testData['isPaidKaduAcademy'] == true ||
                                          (testData['isPaidCollege'] == true &&
                                              testData['allowedCourses']
                                                  is List &&
                                              (testData['allowedCourses']
                                                      as List)
                                                  .isNotEmpty)) &&
                                      testData['allowedCourses'] is List &&
                                      (testData['allowedCourses'] as List)
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Courses: ${((testData['allowedCourses'] as List?)?.join(', ') ?? '')}',
                                        style: const TextStyle(
                                          fontSize: 10, // Smaller
                                          fontStyle: FontStyle.italic,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  if (globalExpiryTime != null)
                                    Text(
                                      'Expires On: ${formatter.format(globalExpiryTime.toDate().toLocal())}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  // --- END NEW ---
                                  const SizedBox(height: 8),
                                  if (isScheduledForFuture)
                                    Text(
                                      'Test Status: Coming Soon at ${formatter.format(scheduledPublishTime!.toDate().toLocal())}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (isPublishedByAdmin &&
                                      !isScheduledForFuture)
                                    Text(
                                      'Test Status: Published',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (isGloballyExpired) // MODIFIED: New condition for expired tests
                                    Text(
                                      'Test Status: Expired', // Display the expiry date
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (hasCompletedSession)
                                    Builder(
                                      builder: (context) {
                                        // Calculate percentage and determine color
                                        final int roundedPercentage =
                                            calculatedPercentage?.round() ?? 0;
                                        Color percentageColor;
                                        if (roundedPercentage >= 75) {
                                          percentageColor = Colors.green;
                                        } else if (roundedPercentage >= 50) {
                                          percentageColor = Colors.blueAccent;
                                        } else if (roundedPercentage >= 35) {
                                          percentageColor = Colors.orange;
                                        } else {
                                          percentageColor = Colors.red;
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Status: COMPLETED  |  Marks Obtained: ${studentScore.toStringAsFixed(2) ?? 'N/A'} out of ${totalPossibleMarks.toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (calculatedPercentage != null)
                                              Text(
                                                'Total Obtained Percentage: ${roundedPercentage}%',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: percentageColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    )
                                  else if (isStudentAttemptExpired)
                                    const Text(
                                      'Your Status: ATTEMPT EXPIRED',
                                      style: TextStyle(
                                        fontSize: 12, // Smaller
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else if (sessionStatus == 'in_progress')
                                    const Text(
                                      'Your Status: IN PROGRESS',
                                      style: TextStyle(
                                        fontSize: 12, // Smaller
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else if (sessionStatus == 'pre_test')
                                    const Text(
                                      'Your Status: PRE-TEST',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (showReviewButton)
                                        ElevatedButton(
                                          onPressed: () =>
                                              _navigateToReviewScreen(
                                                context,
                                                testId,
                                                title,
                                                currentUid, // Pass currentUid
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 16,
                                            ), // Slightly smaller padding
                                            textStyle: const TextStyle(
                                              fontSize: 14,
                                            ), // Smaller font
                                          ),
                                          child: const Text('Review'),
                                        ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: onPressedAction,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: buttonColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 16,
                                          ), // Slightly smaller padding
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                          ), // Smaller font
                                        ),
                                        child: Text(buttonText),
                                      ),
                                    ],
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
              );
            },
          );
        },
      ),
    );
  }
}
