// File: lib/screens/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadu_academy_app/screens/dashboard_screen.dart';

// Constants for Dropdown Options
const List<String> kBranches = [
  'CSE',
  'IT',
  'ENTC',
  'MECH',
  'CIVIL',
  'ELPO',
  'OTHER',
  'M.E.',
];
const List<String> kYears = [
  'First Year',
  'Second Year',
  'Third Year',
  'Final Year',
  'Other',
];
const List<String> kSubjects = ['Aptitude'];

// Courses list for Kadu Academy Students
const List<String> kKaduCourses = [
  'Banking',
  'MBA CET',
  'BBA CET',
  'BCA CET',
  'MCA CET',
  'Railway',
  'Staff selection commission',
  'MPSC',
  'Police Bharti',
  'Others',
];

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();

  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSubject;

  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailDisplayController = TextEditingController();

  String? _studentTypeSelection;
  String? _selectedKaduCourse;

  User? _currentUser;
  bool _isAlreadyRegistered = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _checkRegistrationStatusAndLoadData();
  }

  void _checkRegistrationStatusAndLoadData() async {
    if (_currentUser == null) {
      _showSnackBar('No active user. Please login again.', duration: 2);
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    _emailDisplayController.text = _currentUser!.email ?? 'Not Available';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _isAlreadyRegistered = userData['isRegistered'] == true;

        if (_isAlreadyRegistered) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showAlreadyRegisteredDialog(); // Otherwise, shows "Already Registered"
          });
          return; // Prevents the form from rendering if already registered/denied
        }

        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';

        String savedPhoneNumber = userData['phoneNumber'] ?? '';
        if (savedPhoneNumber.startsWith('+91')) {
          _phoneNumberController.text = savedPhoneNumber.substring(3);
        } else {
          _phoneNumberController.text = savedPhoneNumber;
        }

        _rollNoController.text = userData['rollNo'] ?? '';
        // Load branch, year, and course data safely, converting from list if necessary
        _selectedBranch =
            (userData['branches'] is List && userData['branches'].isNotEmpty)
            ? userData['branches'][0] as String
            : (userData['branch'] is String && userData['branch'].isNotEmpty)
            ? userData['branch'] as String
            : null;

        _selectedYear =
            (userData['years'] is List && userData['years'].isNotEmpty)
            ? userData['years'][0] as String
            : (userData['year'] is String && userData['year'].isNotEmpty)
            ? userData['year'] as String
            : null;

        _selectedSubject =
            (userData['subject'] == null || userData['subject'] == '')
            ? null
            : userData['subject'];

        _selectedKaduCourse =
            (userData['courses'] is List && userData['courses'].isNotEmpty)
            ? userData['courses'][0] as String
            : (userData['selectedCourse'] is String &&
                  userData['selectedCourse'].isNotEmpty)
            ? userData['selectedCourse'] as String
            : null;

        _studentTypeSelection = userData['studentType'];

        setState(() {});
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .set({
              'uid': _currentUser!.uid,
              'email': _currentUser!.email,
              'createdAt': FieldValue.serverTimestamp(),
              'studentType': 'unknown',
              'isRegistered': false,
              'isApprovedByAdminKaduAcademy': false,
              'isApprovedByAdminCollegeStudent': false,
              'isBasicRegistration': false,
              'firstName': '',
              'lastName': '',
              'phoneNumber': '',
              'rollNo': '',
              'branch':
                  '', // Old string field, still keep for backward compat/display if needed
              'year': '', // Old string field
              'subject': '',
              'selectedCourse': '', // Old string field
              'role': 'student',
              'courses':
                  [], // NEW: Initialize as empty array for Kadu Academy courses
              'branches':
                  [], // NEW: Initialize as empty array for College branches
              'years': [], // NEW: Initialize as empty array for College years
            });
        setState(() {});
      }
    } catch (e) {
      _showSnackBar('Failed to load profile. Please try again.');
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
    }
  }

  void _showDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access Denied'),
          content: const Text(
            'Your registration has been denied. Please contact the Admin for further assistance.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/dashboard',
                  (route) => false,
                ); // Go to dashboard
              },
            ),
          ],
        );
      },
    );
  }

  void _showAlreadyRegisteredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Already Registered'),
          content: const Text(
            'Your profile is already fully registered. To make changes, please contact the Admin.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/dashboard',
                  (route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _rollNoController.dispose();
    _phoneNumberController.dispose();
    _emailDisplayController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {int duration = 1}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _updateDetailedProfile() async {
    if (_currentUser == null) {
      _showSnackBar('No active user. Please login again.', duration: 2);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String phoneNumber = _phoneNumberController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty) {
      _showSnackBar('First Name, Last Name, and Phone Number are required.');
      return;
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber)) {
      _showSnackBar('Please enter a valid 10-digit phone number.');
      return;
    }

    if (_studentTypeSelection == null) {
      _showSnackBar(
        'Please select your student type (Kadu Academy or College Student).',
      );
      return;
    }

    if (_studentTypeSelection == 'college') {
      if (_rollNoController.text.trim().isEmpty) {
        _showSnackBar('Roll Number is required for College Students.');
        return;
      }
      if (_selectedBranch == null || _selectedBranch!.isEmpty) {
        _showSnackBar('Branch is required for College Students.');
        return;
      }
      if (_selectedYear == null || _selectedYear!.isEmpty) {
        _showSnackBar('Year is required for College Students.');
        return;
      }
    } else if (_studentTypeSelection == 'kadu_academy') {
      if (_selectedKaduCourse == null || _selectedKaduCourse!.isEmpty) {
        _showSnackBar('Please select a course you wish to join.');
        return;
      }
    }

    _showSnackBar('Saving detailed profile...', duration: 2);

    try {
      final Map<String, dynamic> updateData = {
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': '+91$phoneNumber',
        'studentType': _studentTypeSelection!,
        'isRegistered': true, // User has completed this registration
        'isApprovedByAdminKaduAcademy': false, // Will be set by Admin
        'isApprovedByAdminCollegeStudent': false, // Will be set by Admin
        'isDenied': false, // Will be set by Admin
        'courses': [], // Initialize as empty list (for Kadu Academy)
        'branches': [], // Initialize as empty list (for College)
        'years': [], // Initialize as empty list (for College)
      };

      if (_studentTypeSelection == 'college') {
        updateData['rollNo'] = _rollNoController.text.trim();
        updateData['branch'] =
            _selectedBranch!; // Keep this for backward compat/display if needed
        updateData['year'] =
            _selectedYear!; // Keep this for backward compat/display if needed
        updateData['branches'] = [
          _selectedBranch!,
        ]; // NEW: Save selected branch as an array
        updateData['years'] = [
          _selectedYear!,
        ]; // NEW: Save selected year as an array
        updateData['subject'] = '';
        updateData['selectedCourse'] = ''; // Clear Kadu Academy field
        updateData['courses'] = []; // Clear Kadu Academy array
      } else if (_studentTypeSelection == 'kadu_academy') {
        updateData['selectedCourse'] =
            _selectedKaduCourse!; // Keep this for backward compat/display if needed
        updateData['courses'] = [
          _selectedKaduCourse!,
        ]; // NEW: Save selected course as an array
        updateData['rollNo'] = '';
        updateData['branch'] = '';
        updateData['year'] = '';
        updateData['branches'] = []; // Clear College arrays
        updateData['years'] = []; // Clear College arrays
        updateData['subject'] = '';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updateData);

      _showSnackBar('Profile updated successfully!', duration: 1);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } catch (e) {
      _showSnackBar('Failed to save profile: $e');
    }
  }

  // --- HELPER METHOD: _buildStudentCard (MOVED INSIDE STATE CLASS) ---
  Widget _buildStudentCard(
    BuildContext context, {
    required String typeValue,
    required String typeLabel,
    required IconData typeIcon,
    required Color typeColor,
  }) {
    final bool isSelected = _studentTypeSelection == typeValue;

    return Card(
      // Removed the outer Padding from here
      elevation: isSelected ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _studentTypeSelection = typeValue;
          });
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0), // Padding inside the card
              child: Column(
                crossAxisAlignment: CrossAxisAlignment
                    .stretch, // <--- NEW: Make Column stretch horizontally
                mainAxisAlignment:
                    MainAxisAlignment.center, // Vertical centering
                children: [
                  Center(
                    // Center the Icon
                    child: Icon(typeIcon, size: 35, color: typeColor),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    // Center the Text
                    child: Text(
                      typeLabel,
                      textAlign: TextAlign
                          .center, // Text will also center within its space
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.check_circle, color: Colors.red, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAlreadyRegistered) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Data for the two student type selection cards (used by _buildStudentCard)
    final List<Map<String, dynamic>> studentTypeOptions = [
      {
        'label': 'Kadu Academy Student',
        'value': 'kadu_academy',
        'icon': Icons.school,
        'color': Colors.blue,
      },
      {
        'label': 'College Student',
        'value': 'college',
        'icon': Icons.account_balance,
        'color': Colors.green,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Detailed Profile'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Register yourself to unlock paid features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  'NOTE: APPROVAL OF ADMIN REQUIRED TO UNLOCK PAID FEATURES',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.red),
                ),
                const SizedBox(height: 30),

                // --- Email Display Field (Non-editable) ---
                TextField(
                  controller: _emailDisplayController,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),

                // --- Basic Details (always visible) ---
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                    prefix: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        '+91',
                        style: TextStyle(
                          fontSize:
                              Theme.of(
                                context,
                              ).textTheme.titleMedium?.fontSize ??
                              16,
                          color:
                              Theme.of(context).textTheme.titleMedium?.color ??
                              Colors.black87,
                          fontWeight:
                              Theme.of(
                                context,
                              ).textTheme.titleMedium?.fontWeight ??
                              FontWeight.normal,
                        ),
                      ),
                    ),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 30),

                // --- Student Type Selection (Row-based for better alignment control) ---
                const Text(
                  'Select your Student Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  // Using Row with Expanded for precise control over 2 items
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center the row itself
                  children: [
                    Expanded(
                      child: _buildStudentCard(
                        context,
                        typeValue: 'kadu_academy',
                        typeLabel: 'Kadu Academy',
                        typeIcon: Icons.school,
                        typeColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16), // Spacing between cards
                    Expanded(
                      child: _buildStudentCard(
                        context,
                        typeValue: 'college',
                        typeLabel: 'College Student',
                        typeIcon: Icons.account_balance,
                        typeColor: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Kadu Academy Specific Fields (Conditionally Visible) ---
                Visibility(
                  visible: _studentTypeSelection == 'kadu_academy',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedKaduCourse,
                        decoration: const InputDecoration(
                          labelText: 'Join Course',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.book),
                        ),
                        hint: const Text('Select a course to join'),
                        items: kKaduCourses.map((String course) {
                          return DropdownMenuItem<String>(
                            value: course,
                            child: Text(course),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedKaduCourse = newValue;
                          });
                        },
                        validator: (value) =>
                            _studentTypeSelection == 'kadu_academy' &&
                                (value == null || value.isEmpty)
                            ? 'Please select a course'
                            : null,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // --- College-Specific Fields (Conditionally Visible) ---
                Visibility(
                  visible: _studentTypeSelection == 'college',
                  child: Column(
                    children: [
                      TextField(
                        controller: _rollNoController,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        decoration: const InputDecoration(
                          labelText: 'Roll Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedBranch,
                        decoration: const InputDecoration(
                          labelText: 'Branch',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_tree),
                        ),
                        hint: const Text('Select your Branch'),
                        items: kBranches.map((String branch) {
                          return DropdownMenuItem<String>(
                            value: branch,
                            child: Text(branch),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedBranch = newValue;
                          });
                        },
                        validator: (value) =>
                            _studentTypeSelection == 'college' &&
                                (value == null || value.isEmpty)
                            ? 'Please select a branch'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        hint: const Text('Select your Year'),
                        items: kYears.map((String year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedYear = newValue;
                          });
                        },
                        validator: (value) =>
                            _studentTypeSelection == 'college' &&
                                (value == null || value.isEmpty)
                            ? 'Please select your year'
                            : null,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // --- Save Button ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _updateDetailedProfile,
                    child: const Text(
                      'Save Detailed Profile',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
