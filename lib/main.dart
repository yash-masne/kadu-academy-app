import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Import your custom screens
import 'package:kadu_academy_app/screens/admin_test_management_screen.dart';
import 'package:kadu_academy_app/screens/dashboard_screen.dart';
import 'package:kadu_academy_app/screens/login_screen.dart';
import 'package:kadu_academy_app/screens/admin_login_screen.dart';
import 'package:kadu_academy_app/screens/admin_dashboard_screen.dart';
import 'package:kadu_academy_app/screens/admin_user_management_screen.dart';
import 'package:kadu_academy_app/test/admin_create_test_screen.dart';
import 'package:kadu_academy_app/test/admin_test_list_screen.dart';
import 'package:kadu_academy_app/test/admin_test_detail_management_screen.dart';
import 'package:kadu_academy_app/test/student_take_test_screen.dart';
import 'package:kadu_academy_app/screens/registration_screen.dart';
import 'package:kadu_academy_app/screens/admin_student_marks_screen.dart';
import 'package:kadu_academy_app/screens/admin_test_specific_marks_screen.dart';
import 'package:kadu_academy_app/screens/student_all_tests_screen.dart';
import 'package:kadu_academy_app/screens/student_test_review_screen.dart';
import 'package:kadu_academy_app/screens/pre_test_instructions_screen.dart';
import 'package:kadu_academy_app/screens2/exam_selection_screen.dart';
import 'package:kadu_academy_app/screens2/dashboard_setting_screen.dart';
import 'package:kadu_academy_app/screens2/basic_profile_screen.dart';
import 'package:kadu_academy_app/screens2/phone_login_screen.dart';
import 'package:kadu_academy_app/screens2/phone_password_login_screen.dart';

// === ADDED FOR LIVESTREAM SCREEN ROUTING ===
import 'package:kadu_academy_app/screens/livestream_screen.dart';
// ==========================================

// ** NEW: Import the MaintenanceScreen **
import 'package:kadu_academy_app/screens2/maintenance_screen.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kadu Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 16.0),
          titleMedium: TextStyle(fontSize: 14.0),
          titleSmall: TextStyle(fontSize: 12.0),
          bodyLarge: TextStyle(fontSize: 14.0),
          bodyMedium: TextStyle(fontSize: 12.0),
          bodySmall: TextStyle(fontSize: 10.0),
          labelLarge: TextStyle(fontSize: 12.0),
          labelMedium: TextStyle(fontSize: 10.0),
          labelSmall: TextStyle(fontSize: 8.0),
        ).apply(bodyColor: Colors.black87, displayColor: Colors.black87),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          backgroundColor: Colors.blue,
        ),
      ),
      // ** NEW: Outer StreamBuilder to check for maintenance mode **
      home: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app_settings')
            .doc('general')
            .snapshots(),
        builder: (context, snapshot) {
          // Show a loading indicator while fetching the maintenance flag
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final isMaintenanceMode =
              snapshot.data?.get('isMaintenanceMode') ?? false;

          // If maintenance mode is ON, show the maintenance screen
          if (isMaintenanceMode) {
            return const MaintenanceScreen();
          }

          // If maintenance mode is OFF, proceed with the original authentication check
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              } else if (authSnapshot.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text('Error loading app. Please restart.'),
                  ),
                );
              } else if (authSnapshot.hasData && authSnapshot.data != null) {
                final User user = authSnapshot.data!;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get(),
                  builder: (context, userDocSnapshot) {
                    if (userDocSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    } else if (userDocSnapshot.hasError) {
                      FirebaseAuth.instance.signOut();
                      return const LoginScreen();
                    } else if (userDocSnapshot.hasData &&
                        userDocSnapshot.data!.exists) {
                      final userData =
                          userDocSnapshot.data!.data() as Map<String, dynamic>;
                      if (userData['isAdmin'] == true) {
                        return const AdminDashboardScreen();
                      }
                      final String? phoneNumber =
                          userData['phoneNumber'] as String?;
                      final String? email = userData['email'] as String?;
                      final bool isBasicRegistration =
                          userData['isBasicRegistration'] ?? false;
                      if (isBasicRegistration == false ||
                          phoneNumber == null ||
                          email == null ||
                          phoneNumber.isEmpty ||
                          email.isEmpty) {
                        return const BasicProfileScreen(isInitialLogin: true);
                      } else {
                        return const DashboardScreen();
                      }
                    } else {
                      return const BasicProfileScreen(isInitialLogin: true);
                    }
                  },
                );
              } else {
                return const LoginScreen();
              }
            },
          );
        },
      ),

      onGenerateRoute: (settings) {
        if (settings.name == '/phone_password_login') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) {
              return PhonePasswordLoginScreen(
                phoneNumber: args['phoneNumber'] as String,
              );
            },
          );
        } else if (settings.name == '/pre_test_instructions') {
          final args = settings.arguments as Map<String, dynamic>;
          final String testId = args['testId'] as String;
          final String studentTestSessionId =
              args['studentTestSessionId'] as String;
          final int testDurationMinutes = args['testDurationMinutes'] as int;
          final String testTitle = args['testTitle'] as String;
          final bool allowStudentReview = args['allowStudentReview'] as bool;
          return MaterialPageRoute(
            builder: (context) {
              return PreTestInstructionsScreen(
                testId: testId,
                studentTestSessionId: studentTestSessionId,
                testDurationMinutes: testDurationMinutes,
                testTitle: testTitle,
                allowStudentReview: allowStudentReview,
              );
            },
          );
        } else if (settings.name == '/student_take_test') {
          final args = settings.arguments as Map<String, dynamic>;
          final String testId = args['testId'] as String;
          final String studentTestSessionId =
              args['studentTestSessionId'] as String;
          final int testDurationMinutes = args['testDurationMinutes'] as int;
          final String testTitle = args['testTitle'] as String;
          final bool allowStudentReview = args['allowStudentReview'] as bool;
          return MaterialPageRoute(
            builder: (context) {
              return StudentTakeTestScreen(
                testId: testId,
                studentTestSessionId: studentTestSessionId,
                testDurationMinutes: testDurationMinutes,
                testTitle: testTitle,
                allowStudentReview: allowStudentReview,
              );
            },
          );
        } else if (settings.name == '/student_test_review') {
          final args = settings.arguments as Map<String, dynamic>;
          final String testId = args['testId'] as String;
          final String testTitle = args['testTitle'] as String;
          final String studentId = args['studentId'] as String;
          return MaterialPageRoute(
            builder: (context) {
              return StudentTestReviewScreen(
                testId: testId,
                testTitle: testTitle,
                studentId: studentId,
              );
            },
          );
        } else if (settings.name == '/admin_test_detail_management') {
          final args = settings.arguments as Map<String, dynamic>;
          final String testId = args['testId'] as String;
          final Map<String, dynamic> initialTestData =
              args['initialTestData'] as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) {
              return AdminTestDetailManagementScreen(
                testId: testId,
                initialTestData: initialTestData,
              );
            },
          );
        } else if (settings.name == '/admin_test_specific_marks') {
          final args = settings.arguments as Map<String, dynamic>;
          final String testId = args['testId'] as String;
          final String testTitle = args['testTitle'] as String;
          final String dateFilter = args['dateFilter'] as String;
          final bool isFreeTest = args['isFreeTest'] as bool;
          final bool isPaidCollegeTest = args['isPaidCollegeTest'] as bool;
          final bool isPaidKaduAcademyTest =
              args['isPaidKaduAcademyTest'] as bool;
          final List<String> allowedBranches =
              (args['allowedBranches'] as List<dynamic>)
                  .map((e) => e as String)
                  .toList();
          final List<String> allowedYears =
              (args['allowedYears'] as List<dynamic>)
                  .map((e) => e as String)
                  .toList();
          final List<String> allowedCourses =
              (args['allowedCourses'] as List<dynamic>)
                  .map((e) => e as String)
                  .toList();
          return MaterialPageRoute(
            builder: (context) {
              return AdminTestSpecificMarksScreen(
                testId: testId,
                testTitle: testTitle,
                dateFilter: dateFilter,
                isFreeTest: isFreeTest,
                isPaidCollegeTest: isPaidCollegeTest,
                isPaidKaduAcademyTest: isPaidKaduAcademyTest,
                allowedBranches: allowedBranches,
                allowedYears: allowedYears,
                allowedCourses: allowedCourses,
              );
            },
          );
        } else if (settings.name == '/basic_profile') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) {
              return BasicProfileScreen(
                isInitialLogin: args?['isInitialLogin'] as bool? ?? false,
                phoneNumber: args?['phoneNumber'] as String? ?? '',
              );
            },
          );
        }
        return null;
      },
      routes: {
        '/login': (context) => const LoginScreen(),
        '/phone_login': (context) => const PhoneLoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/dashboard_setting': (context) => const DashboardSettingScreen(),
        '/admin_test_management': (context) => AdminTestManagementScreen(),
        '/admin_create_test': (context) => const AdminCreateTestScreen(),
        '/admin_test_list': (context) => const AdminTestListScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/admin_user_management': (context) => AdminUserManagementScreen(),
        '/admin_student_marks': (context) => const AdminStudentMarksScreen(),
        '/student_all_tests': (context) => const StudentAllTestsScreen(),
        '/exam_selection': (context) => const ExamSelectionScreen(),
        '/livestream_test_carousel': (context) => const LivestreamScreen(),
      },
    );
  }
}
