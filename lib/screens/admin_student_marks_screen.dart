import 'dart:math' as math; // ADDED: For math.min
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadu_academy_app/screens/admin_test_specific_marks_screen.dart';
import 'package:kadu_academy_app/utils/firestore_extensions.dart'; // Ensure this is present and functional

// --- Consistent Constants (aligned with AdminTestDetailManagementScreen) ---
const List<String> kBranches = [
  'CSE',
  'IT',
  'ENTC',
  'MECH',
  'CIVIL',
  'ELPO',
  'OTHER',
];
const List<String> kYears = [
  'First Year',
  'Second Year',
  'Third Year',
  'Final Year',
  'Other',
];
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

// Constants for filter dropdowns (include 'All' option explicitly for UI)
const List<String> kDateFilters = [
  'Today',
  'Last 7 days',
  'Last 30 days',
  'Last 6 months',
  'Last year',
  'All Time',
];
const List<String> kTestTypesForFilter = [
  'All',
  'Free Test',
  'Kadu Academy Student',
  'College Student',
];
List<String> get kBranchesForFilter => ['All', ...kBranches];
List<String> get kYearsForFilter => ['All', ...kYears];
List<String> get kKaduCoursesForFilter => ['All', ...kKaduCourses];
// --- END Consistent Constants ---

class AdminStudentMarksScreen extends StatefulWidget {
  const AdminStudentMarksScreen({super.key});

  @override
  State<AdminStudentMarksScreen> createState() =>
      _AdminStudentMarksScreenState();
}

class _AdminStudentMarksScreenState extends State<AdminStudentMarksScreen> {
  // --- Filter State Variables ---
  String _selectedDateFilter = 'Today';
  String _selectedTestTypeFilter = 'All'; // NEW: Default to All
  String _selectedBranchFilter = 'All';
  String _selectedYearFilter = 'All';
  String _selectedCourseFilter = 'All'; // NEW: Default to All

  // Method to calculate start date based on selected filter
  DateTime? _getStartDate(String filter) {
    DateTime now = DateTime.now();
    switch (filter) {
      case 'Today':
        return DateTime(now.year, now.month, now.day); // Start of today
      case 'Last 7 days':
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
      case 'Last 30 days':
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
      case 'Last 6 months':
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 182)); // Approx
      case 'Last year':
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 364)); // Approx
      case 'All Time':
        return null; // No start date filter
      default:
        return DateTime(1970); // Very old date for safety
    }
  }

  // Method to calculate end date (exclusive) for 'Today' filter
  DateTime? _getEndDate(String filter, DateTime? startDate) {
    if (filter == 'Today' && startDate != null) {
      return startDate.add(
        const Duration(days: 1),
      ); // End of today (start of tomorrow)
    }
    return null; // No specific end date for other filters (Firestore handles ranges automatically)
  }

  // --- NEW: Core function to fetch and filter tests with submissions ---
  Future<List<DocumentSnapshot>> _fetchFilteredTestsWithSubmissions() async {
    // 1. Get relevant testIds from studentTestSessions based on date filter
    final DateTime? startDate = _getStartDate(_selectedDateFilter);
    final DateTime? endDate = _getEndDate(
      _selectedDateFilter,
      startDate,
    ); // Exclusive end date for 'Today'

    Query sessionsQuery = FirebaseFirestore.instance
        .collection('studentTestSessions')
        .where('status', isEqualTo: 'completed');

    if (startDate != null) {
      sessionsQuery = sessionsQuery.where(
        'submissionTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      // Only used for 'Today' to define exclusive upper bound
      sessionsQuery = sessionsQuery.where(
        'submissionTime',
        isLessThan: Timestamp.fromDate(endDate),
      );
    }

    // Sort by submissionTime to ensure latest submissions are processed first (if multiple for same test)
    sessionsQuery = sessionsQuery.orderBy('submissionTime', descending: true);

    final QuerySnapshot sessionsSnapshot = await sessionsQuery.get();
    final Set<String> relevantTestIds = {};
    for (var doc in sessionsSnapshot.docs) {
      relevantTestIds.add(doc['testId']);
    }

    if (relevantTestIds.isEmpty) {
      return []; // No tests with submissions found for the date filter
    }

    // 2. Fetch tests based on relevantTestIds and other filters
    List<DocumentSnapshot> allFilteredTests = [];
    final List<String> testIdsList = relevantTestIds.toList();

    // Firestore `whereIn` allows max 10 values, so chunk if necessary
    const int chunkSize = 10;
    for (int i = 0; i < testIdsList.length; i += chunkSize) {
      final List<String> chunk = testIdsList.sublist(
        i,
        math.min(i + chunkSize, testIdsList.length),
      );

      Query testsQuery = FirebaseFirestore.instance.collection('tests');
      testsQuery = testsQuery.where(FieldPath.documentId, whereIn: chunk);

      // Apply Test Type filter
      if (_selectedTestTypeFilter == 'Free Test') {
        testsQuery = testsQuery.where('isFree', isEqualTo: true);
      } else if (_selectedTestTypeFilter == 'Kadu Academy Student') {
        testsQuery = testsQuery.where('isPaidKaduAcademy', isEqualTo: true);
      } else if (_selectedTestTypeFilter == 'College Student') {
        testsQuery = testsQuery.where('isPaidCollege', isEqualTo: true);
      }
      // If 'All', no test type filter is applied at this stage.

      // Apply Branch/Year/Course filters if selected and relevant test type
      if (_selectedTestTypeFilter == 'College Student') {
        if (_selectedBranchFilter != 'All' &&
            _selectedBranchFilter.isNotEmpty) {
          testsQuery = testsQuery.where(
            'allowedBranches',
            arrayContains: _selectedBranchFilter,
          );
        }
        if (_selectedYearFilter != 'All' && _selectedYearFilter.isNotEmpty) {
          if (_selectedBranchFilter == 'All') {
            // Apply year in query if branch is 'All'
            testsQuery = testsQuery.where(
              'allowedYears',
              arrayContains: _selectedYearFilter,
            );
          }
        }
      } else if (_selectedTestTypeFilter == 'Kadu Academy Student') {
        if (_selectedCourseFilter != 'All' &&
            _selectedCourseFilter.isNotEmpty) {
          testsQuery = testsQuery.where(
            'allowedCourses',
            arrayContains: _selectedCourseFilter,
          );
        }
      }

      final QuerySnapshot testsSnapshot = await testsQuery.get();
      allFilteredTests.addAll(testsSnapshot.docs);
    }

    // Post-process for complex array filters (e.g., if both Branch AND Year were selected for College test)
    List<DocumentSnapshot> finalDisplayTests = [];
    for (var testDoc in allFilteredTests) {
      bool matchesBranch = true;
      bool matchesYear = true;
      bool matchesCourse = true;

      // This handles cases where Firestore query limitations prevent full combination (e.g. two arrayContains)
      // or if 'All' was selected for a filter, but we still need to check if the test is indeed of that type.
      if (_selectedTestTypeFilter == 'College Student') {
        final List<String> testBranches = List<String>.from(
          testDoc['allowedBranches'] ?? [],
        );
        final List<String> testYears = List<String>.from(
          testDoc['allowedYears'] ?? [],
        );

        // Only client-side filter if a specific filter is selected OR if it was the second array filter
        if (_selectedBranchFilter != 'All' &&
            _selectedBranchFilter.isNotEmpty) {
          matchesBranch = testBranches.contains(_selectedBranchFilter);
        }
        if (_selectedYearFilter != 'All' && _selectedYearFilter.isNotEmpty) {
          matchesYear = testYears.contains(_selectedYearFilter);
        }
      } else if (_selectedTestTypeFilter == 'Kadu Academy Student') {
        final List<String> testCourses = List<String>.from(
          testDoc['allowedCourses'] ?? [],
        );
        if (_selectedCourseFilter != 'All' &&
            _selectedCourseFilter.isNotEmpty) {
          matchesCourse = testCourses.contains(_selectedCourseFilter);
        }
      }
      // If _selectedTestTypeFilter is 'All' or 'Free Test', no specific audience filter is applied here.
      // The Firestore query already ensures the test type match.

      if (matchesBranch && matchesYear && matchesCourse) {
        finalDisplayTests.add(testDoc);
      }
    }

    // Sort the final list by createdAt descending (latest tests first among relevant ones)
    finalDisplayTests.sort((a, b) {
      final Timestamp aCreated =
          a['createdAt'] as Timestamp? ??
          Timestamp.fromMicrosecondsSinceEpoch(0);
      final Timestamp bCreated =
          b['createdAt'] as Timestamp? ??
          Timestamp.fromMicrosecondsSinceEpoch(0);
      return bCreated.compareTo(aCreated); // Descending order
    });

    return finalDisplayTests;
  }

  // Helper to count submissions for a specific test within a date range
  Future<int> _countSubmissionsForTest(String testId, String dateFilter) async {
    final DateTime? startDate = _getStartDate(dateFilter);
    final Timestamp? startTimestamp = startDate != null
        ? Timestamp.fromDate(startDate)
        : null;
    final DateTime? endDate = _getEndDate(dateFilter, startDate);

    Query query = FirebaseFirestore.instance
        .collection('studentTestSessions')
        .where('testId', isEqualTo: testId)
        .where('status', isEqualTo: 'completed');

    if (startTimestamp != null) {
      query = query.where(
        'submissionTime',
        isGreaterThanOrEqualTo: startTimestamp,
      );
    }
    if (endDate != null) {
      query = query.where(
        'submissionTime',
        isLessThan: Timestamp.fromDate(endDate),
      );
    }

    AggregateQuerySnapshot aggregateQuery = await query.count().get();
    return aggregateQuery.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // These date calculations are for the _countSubmissionsForTest helper,
    // not directly used by the main _fetchFilteredTestsWithSubmissions FutureBuilder.
    // They are passed into the helper when building the UI for each test card.
    final DateTime? startDate = _getStartDate(_selectedDateFilter);
    final Timestamp? startTimestamp = startDate != null
        ? Timestamp.fromDate(startDate)
        : null;
    final DateTime? endDate = _getEndDate(_selectedDateFilter, startDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Marks Overview'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- Date Filter Dropdown ---
                DropdownButtonFormField<String>(
                  value: _selectedDateFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter Results By Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.date_range),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: kDateFilters.map((String filter) {
                    return DropdownMenuItem<String>(
                      value: filter,
                      child: Text(filter),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDateFilter = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // --- NEW: Test Type Filter Dropdown ---
                DropdownButtonFormField<String>(
                  value: _selectedTestTypeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter By Test Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: kTestTypesForFilter.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTestTypeFilter = newValue!;
                      // Reset other filters when test type changes
                      _selectedBranchFilter = 'All';
                      _selectedYearFilter = 'All';
                      _selectedCourseFilter = 'All';
                    });
                  },
                ),
                const SizedBox(height: 10),

                // --- Conditional Branch Filter Dropdown (for College Students) ---
                if (_selectedTestTypeFilter == 'College Student')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedBranchFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter by College Branch',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_tree),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: kBranchesForFilter.map((String branch) {
                        return DropdownMenuItem<String>(
                          value: branch,
                          child: Text(branch),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedBranchFilter = newValue!;
                        });
                      },
                    ),
                  ),

                // --- Conditional Year Filter Dropdown (for College Students) ---
                if (_selectedTestTypeFilter == 'College Student')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedYearFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter by College Year',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: kYearsForFilter.map((String year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(year),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedYearFilter = newValue!;
                        });
                      },
                    ),
                  ),

                // --- Conditional Course Filter Dropdown (for Kadu Academy Students) ---
                if (_selectedTestTypeFilter == 'Kadu Academy Student')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCourseFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Kadu Academy Course',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: kKaduCoursesForFilter.map((String course) {
                        return DropdownMenuItem<String>(
                          value: course,
                          child: Text(course),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCourseFilter = newValue!;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _fetchFilteredTestsWithSubmissions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final List<DocumentSnapshot> finalDisplayedTests =
                    snapshot.data ?? [];
                final int totalDisplayedTests = finalDisplayedTests.length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Total Tests with Results: $totalDisplayedTests',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (totalDisplayedTests == 0)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No tests with results found for this filter combination.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 0.0,
                          ),
                          itemCount: totalDisplayedTests,
                          itemBuilder: (context, index) {
                            DocumentSnapshot testDocument =
                                finalDisplayedTests[index];
                            Map<String, dynamic> testData =
                                testDocument.data() as Map<String, dynamic>;

                            String testId = testDocument.id;
                            String title = testData['title'] ?? 'Untitled Test';

                            // --- Determine displayed branch/year/course details ---
                            String displayedDetails = 'N/A';
                            final bool isFreeTest = testData['isFree'] ?? false;
                            final bool isPaidCollegeTest =
                                testData['isPaidCollege'] ?? false;
                            final bool isPaidKaduAcademyTest =
                                testData['isPaidKaduAcademy'] ?? false;

                            if (isPaidCollegeTest) {
                              final List<String> branches = List<String>.from(
                                testData['allowedBranches'] ?? [],
                              );
                              final List<String> years = List<String>.from(
                                testData['allowedYears'] ?? [],
                              );
                              displayedDetails =
                                  'Branch(es): ${branches.isNotEmpty ? branches.join(', ') : 'N/A'}, Year(s): ${years.isNotEmpty ? years.join(', ') : 'N/A'}';
                            } else if (isPaidKaduAcademyTest) {
                              final List<String> courses = List<String>.from(
                                testData['allowedCourses'] ?? [],
                              );
                              displayedDetails =
                                  'Course(s): ${courses.isNotEmpty ? courses.join(', ') : 'N/A'}';
                            } else {
                              // Free test
                              displayedDetails = 'Type: Free';
                            }
                            // --- END displayed details logic ---

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10.0),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: InkWell(
                                onTap: () {
                                  // Navigate to the test-specific marks screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AdminTestSpecificMarksScreen(
                                            testId: testId,
                                            testTitle: title,
                                            dateFilter: _selectedDateFilter,
                                            // --- START CORRECTED PARAMETERS ---
                                            isFreeTest: isFreeTest,
                                            isPaidCollegeTest:
                                                isPaidCollegeTest,
                                            isPaidKaduAcademyTest:
                                                isPaidKaduAcademyTest,
                                            allowedBranches: List<String>.from(
                                              testData['allowedBranches'] ?? [],
                                            ),
                                            allowedYears: List<String>.from(
                                              testData['allowedYears'] ?? [],
                                            ),
                                            allowedCourses: List<String>.from(
                                              testData['allowedCourses'] ?? [],
                                            ),
                                            // --- END CORRECTED PARAMETERS ---
                                          ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(displayedDetails),
                                      const SizedBox(height: 4),
                                      FutureBuilder<int>(
                                        future: _countSubmissionsForTest(
                                          testId,
                                          _selectedDateFilter,
                                        ),
                                        builder: (context, countSnapshot) {
                                          if (countSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Text(
                                              'Submissions: Loading...',
                                            );
                                          }
                                          if (countSnapshot.hasError) {
                                            return const Text(
                                              'Submissions: Error',
                                            );
                                          }
                                          return Text(
                                            'Total Submissions: ${countSnapshot.data ?? 0}',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
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
    );
  }
}
