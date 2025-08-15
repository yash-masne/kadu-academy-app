import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kadu_academy_app/utils/firestore_extensions.dart'; // Import the QueryExtension

// Constants for Filter Dropdown Options (Re-using kBranches/kYears from registration_screen)
const List<String> kStudentTypeFilterOptions = [
  'All',
  'Kadu Academy Student',
  'College Student',
];
const List<String> kApprovalStatusFilterOptions = [
  'All',
  'Approved', // Means isApprovedByAdminKaduAcademy OR isApprovedByAdminCollegeStudent is true
  'Unapproved', // Means both isApprovedByAdminKaduAcademy AND isApprovedByAdminCollegeStudent are false
  'Denied', // Means isDenied is true (overrides all approvals)
];
// kBranches and kYears are still used for the conditional filters below
const List<String> kBranches = [
  'All',
  'CSE',
  'IT',
  'ENTC',
  'MECH',
  'CIVIL',
  'ELPO',
  'OTHER',
];
const List<String> kYears = [
  'All',
  'First Year',
  'Second Year',
  'Third Year',
  'Final Year',
  'Other',
];

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  // State for Filters
  String _currentStudentTypeFilter = 'All';
  String _currentApprovalStatusFilter = 'All';
  String? _selectedBranchFilter = 'All';
  String? _selectedYearFilter = 'All';

  bool _isAdmin = false;
  bool _isLoadingAdminStatus = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  // Helper for SnackBar Styling
  void _showSnackBar(String message, {int duration = 1}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _checkAdminStatus() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isLoadingAdminStatus = false;
        });
      }
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _isAdmin = userData['isAdmin'] == true;
            _isLoadingAdminStatus = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _isLoadingAdminStatus = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isLoadingAdminStatus = false;
        });
        _showSnackBar('Failed to verify admin status: $e');
      }
    }
  }

  // --- Functions to Toggle User Approval Flags ---

  // Toggle Kadu Academy Approval
  Future<void> _toggleKaduApproval(
    String userId,
    String userName,
    bool currentStatus,
  ) async {
    if (!_isAdmin) {
      _showSnackBar('Permission denied: Not authorized.');
      return;
    }
    _showSnackBar('Updating Kadu Academy approval for "$userName"...');
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isApprovedByAdminKaduAcademy': !currentStatus,
      });
      _showSnackBar('Kadu Academy approval for "$userName" updated!');
    } catch (e) {
      _showSnackBar('Failed to update approval: $e');
    }
  }

  // Toggle College Student Approval
  Future<void> _toggleCollegeApproval(
    String userId,
    String userName,
    bool currentStatus,
  ) async {
    if (!_isAdmin) {
      _showSnackBar('Permission denied: Not authorized.');
      return;
    }
    _showSnackBar('Updating College approval for "$userName"...');
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isApprovedByAdminCollegeStudent': !currentStatus,
      });
      _showSnackBar('College approval for "$userName" updated!');
    } catch (e) {
      _showSnackBar('Failed to update approval: $e');
    }
  }

  // Toggle Denied Status
  Future<void> _toggleDeniedStatus(
    String userId,
    String userName,
    bool currentStatus,
  ) async {
    if (!_isAdmin) {
      _showSnackBar('Permission denied: Not authorized.');
      return;
    }
    _showSnackBar('Updating denied status for "$userName"...');
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isDenied': !currentStatus, // Toggle denied status
      });
      _showSnackBar('Denied status for "$userName" updated!');
    } catch (e) {
      _showSnackBar('Failed to update denied status: $e');
    }
  }

  // Function to delete a user (Firestore + Auth via Cloud Function) - LOGIC REMAINS THE SAME
  Future<void> _deleteUser(String userId, String userName) async {
    if (!_isAdmin) {
      _showSnackBar(
        'Permission denied: You are not authorized to delete users.',
      );
      return;
    }
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == userId) {
      _showSnackBar('You cannot delete your own admin account from here.');
      return;
    }

    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm User Deletion'),
              content: Text(
                'Are you sure you want to permanently delete "$userName" from the database AND Firebase Authentication? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmDelete) return;

    _showSnackBar('Deleting "$userName"...');
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserAccount',
      );
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'uid': userId,
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      _showSnackBar('User "$userName" and their account deleted successfully!');
    } on FirebaseFunctionsException catch (e) {
      String errorMessage = 'Error from Cloud Function: ${e.message}';
      if (e.code == 'unauthenticated') {
        errorMessage =
            'Authentication required to delete user. Please log in as admin again.';
      } else if (e.code == 'permission-denied') {
        errorMessage = 'You do not have permission to delete users.';
      } else if (e.code == 'not-found') {
        errorMessage = 'User not found in Authentication: ${e.message}';
      }
      _showSnackBar('Failed to delete user "$userName": $errorMessage');
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred deleting user "$userName": $e',
      );
    }
  }

  // Method to build the Firestore stream dynamically based on filters
  Stream<QuerySnapshot> _buildUsersStream() {
    Query query = FirebaseFirestore.instance.collection('users');

    // Filter by isRegistered: true (only show fully registered users)
    query = query.where('isRegistered', isEqualTo: true);

    // Apply filter based on _currentStudentTypeFilter
    query = query.when(
      _currentStudentTypeFilter != 'All',
      (q) => q.where(
        'studentType',
        isEqualTo: _currentStudentTypeFilter == 'Kadu Academy Student'
            ? 'kadu_academy'
            : 'college',
      ),
    );

    // Apply filter based on _currentApprovalStatusFilter
    query = query.when(_currentApprovalStatusFilter != 'All', (q) {
      if (_currentApprovalStatusFilter == 'Approved') {
        // Filter in Dart after fetching if both isApproved flags.
        // Query by isDenied: false, then filter for approved in Dart.
        return q.where(
          'isDenied',
          isEqualTo: false,
        ); // Query non-denied, then filter approved in Dart
      } else if (_currentApprovalStatusFilter == 'Denied') {
        return q.where('isDenied', isEqualTo: true);
      } else if (_currentApprovalStatusFilter == 'Unapproved') {
        // Filter in Dart after fetching. Firestore does not support OR queries directly
        // or NOT EXISTS queries. So fetch non-denied and filter unapproved in Dart.
        return q.where('isDenied', isEqualTo: false); // Fetch non-denied
      }
      return q; // Return original query if 'All' or other filters
    });

    // Apply conditional branch and year filters only if StudentType is 'College Student'
    query = query.when(
      _currentStudentTypeFilter == 'College Student' &&
          _selectedBranchFilter != 'All' &&
          _selectedBranchFilter != null,
      (q) => q.where('branch', isEqualTo: _selectedBranchFilter),
    );
    query = query.when(
      _currentStudentTypeFilter == 'College Student' &&
          _selectedYearFilter != 'All' &&
          _selectedYearFilter != null,
      (q) => q.where('year', isEqualTo: _selectedYearFilter),
    );

    query = query.orderBy('createdAt', descending: true);
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAdminStatus) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Access Denied. You are not an admin.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('User Management'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Filter by Student Type
                  DropdownButtonFormField<String>(
                    value: _currentStudentTypeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Student Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: kStudentTypeFilterOptions.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _currentStudentTypeFilter = newValue!;
                        _selectedBranchFilter =
                            'All'; // Reset on student type change
                        _selectedYearFilter =
                            'All'; // Reset on student type change
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Filter by Approval Status
                  DropdownButtonFormField<String>(
                    value: _currentApprovalStatusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Approval Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.verified_user),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: kApprovalStatusFilterOptions.map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(
                          status,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _currentApprovalStatusFilter = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Conditional Branch and Year Filters for College Students
                  Visibility(
                    visible: _currentStudentTypeFilter == 'College Student',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedBranchFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Branch',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_tree),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: kBranches.map((String branch) {
                            return DropdownMenuItem<String>(
                              value: branch,
                              child: Text(
                                branch,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedBranchFilter = newValue!;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedYearFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Year',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: kYears.map((String year) {
                            return DropdownMenuItem<String>(
                              value: year,
                              child: Text(
                                year,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedYearFilter = newValue!;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No registered users found.'),
                    );
                  }

                  // Filter in Dart for 'Approved' and 'Unapproved' as Firestore OR queries are complex
                  List<DocumentSnapshot> filteredUserDocs = snapshot.data!.docs;

                  if (_currentApprovalStatusFilter == 'Approved') {
                    filteredUserDocs = filteredUserDocs.where((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      // User is approved if Kadu OR College approved, AND NOT denied
                      return (userData['isApprovedByAdminKaduAcademy'] ==
                                  true ||
                              userData['isApprovedByAdminCollegeStudent'] ==
                                  true) &&
                          (userData['isDenied'] != true);
                    }).toList();
                  } else if (_currentApprovalStatusFilter == 'Unapproved') {
                    filteredUserDocs = filteredUserDocs.where((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      // User is unapproved if NOT approved (Kadu AND College) AND NOT denied
                      return (userData['isApprovedByAdminKaduAcademy'] !=
                                  true &&
                              userData['isApprovedByAdminCollegeStudent'] !=
                                  true) &&
                          (userData['isDenied'] != true);
                    }).toList();
                  }
                  // 'Denied' is handled directly in the Firestore query for efficiency

                  if (filteredUserDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users found for this filter combination.',
                      ),
                    );
                  }

                  final int totalFilteredUsers = filteredUserDocs.length;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Text(
                          'Total Users: $totalFilteredUsers',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 0.0,
                          ),
                          itemCount: totalFilteredUsers,
                          itemBuilder: (context, index) {
                            DocumentSnapshot userDocument =
                                filteredUserDocs[index];
                            Map<String, dynamic> userData =
                                userDocument.data() as Map<String, dynamic>;

                            String userId = userDocument.id;
                            String firstName = userData['firstName'] ?? 'N/A';
                            String lastName = userData['lastName'] ?? 'N/A';
                            String fullName = '$firstName $lastName'.trim();
                            String email = userData['email'] ?? 'N/A';
                            String phoneNumber =
                                userData['phoneNumber'] ?? 'N/A';
                            String studentType =
                                userData['studentType'] ?? 'N/A';
                            bool isRegistered =
                                userData['isRegistered'] ?? false;
                            bool isApprovedKadu =
                                userData['isApprovedByAdminKaduAcademy'] ??
                                false;
                            bool isApprovedCollege =
                                userData['isApprovedByAdminCollegeStudent'] ??
                                false;
                            bool isDenied = userData['isDenied'] ?? false;
                            bool isListedUserAdmin =
                                userData['isAdmin'] == true;

                            String approvalStatus = 'Unapproved';
                            Color approvalColor = Colors.orange;
                            if (isApprovedKadu || isApprovedCollege) {
                              approvalStatus = 'Approved';
                              approvalColor = Colors.green;
                            }
                            if (isDenied) {
                              approvalStatus = 'Denied';
                              approvalColor = Colors.red;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      phoneNumber,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Student Type: $studentType',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Registered: ${isRegistered ? 'Yes' : 'No'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isRegistered
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    Text(
                                      'Overall Status: $approvalStatus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: approvalColor,
                                      ),
                                    ),
                                    if (isListedUserAdmin)
                                      const Text(
                                        'ROLE: ADMIN',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    if (_isAdmin)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (studentType == 'kadu_academy')
                                            SwitchListTile(
                                              title: const Text(
                                                'Kadu Academy Approved',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              value: isApprovedKadu,
                                              onChanged: isListedUserAdmin
                                                  ? null
                                                  : (value) =>
                                                        _toggleKaduApproval(
                                                          userId,
                                                          fullName,
                                                          isApprovedKadu,
                                                        ),
                                              activeColor: Colors.green,
                                              dense: true,
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .leading,
                                            ),
                                          if (studentType == 'college')
                                            SwitchListTile(
                                              title: const Text(
                                                'College Approved',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              value: isApprovedCollege,
                                              onChanged: isListedUserAdmin
                                                  ? null
                                                  : (value) =>
                                                        _toggleCollegeApproval(
                                                          userId,
                                                          fullName,
                                                          isApprovedCollege,
                                                        ),
                                              activeColor: Colors.green,
                                              dense: true,
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .leading,
                                            ),
                                          SwitchListTile(
                                            title: const Text(
                                              'Denied Access (Override)',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            value: isDenied,
                                            onChanged: isListedUserAdmin
                                                ? null
                                                : (value) =>
                                                      _toggleDeniedStatus(
                                                        userId,
                                                        fullName,
                                                        isDenied,
                                                      ),
                                            activeColor: Colors.red,
                                            dense: true,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: isListedUserAdmin
                                                  ? null
                                                  : () => _deleteUser(
                                                      userId,
                                                      fullName,
                                                    ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Delete User',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
