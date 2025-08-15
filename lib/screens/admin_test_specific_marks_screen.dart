import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:math'
    as math; // Used for math.min for chunking, although not strictly needed in final version of _fetchFilteredTestsWithSubmissions, it's good practice.

// --- Consistent Constants (aligned with AdminTestDetailManagementScreen, for dropdown options) ---
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

const List<String> kDateFilters = [
  // Date filters passed from previous screen
  'Today',
  'Last 7 days',
  'Last 30 days',
  'Last 6 months',
  'Last year',
  'All Time',
];

// Options for new filters/sorting on this screen
const List<String> kStudentSortOptions = [
  'Submission Time (Latest First)', // Default
  'Roll Number (Ascending)',
];
List<String> get kStudentBranchesForFilter => ['All', ...kBranches];
List<String> get kStudentYearsForFilter => ['All', ...kYears];
List<String> get kStudentCoursesForFilter => ['All', ...kKaduCourses];
// --- END Consistent Constants ---

class AdminTestSpecificMarksScreen extends StatefulWidget {
  final String testId;
  final String testTitle;
  final String
  dateFilter; // Date filter selected on previous screen (for sessions)

  // Actual test audience properties (passed from AdminStudentMarksScreen)
  final bool isFreeTest;
  final bool isPaidCollegeTest;
  final bool isPaidKaduAcademyTest;
  final List<String> allowedBranches; // Actual allowed branches for THIS test
  final List<String> allowedYears; // Actual allowed years for THIS test
  final List<String> allowedCourses; // Actual allowed courses for THIS test

  const AdminTestSpecificMarksScreen({
    super.key,
    required this.testId,
    required this.testTitle,
    required this.dateFilter,
    required this.isFreeTest,
    required this.isPaidCollegeTest,
    required this.isPaidKaduAcademyTest,
    required this.allowedBranches,
    required this.allowedYears,
    required this.allowedCourses,
  });

  @override
  State<AdminTestSpecificMarksScreen> createState() =>
      _AdminTestSpecificMarksScreenState();
}

class _AdminTestSpecificMarksScreenState
    extends State<AdminTestSpecificMarksScreen> {
  // --- State Variables for NEW Filters/Sorting ---
  String _selectedStudentSortOption =
      'Submission Time (Latest First)'; // Default sort
  String _selectedStudentBranchFilter = 'All'; // Default branch filter
  String _selectedStudentYearFilter = 'All'; // Default year filter
  String _selectedStudentCourseFilter = 'All'; // Default course filter

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
      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;
      // Correctly map `selectedCourse` to `course`
      userData['course'] = userData['course'] ?? userData['selectedCourse'];
      _cachedUsers[uid] = userData;
      return _cachedUsers[uid]!;
    }
    return {};
  }

  // Method to calculate start date based on selected filter
  DateTime? _getStartDate(String filter) {
    DateTime now = DateTime.now();
    switch (filter) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
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
        ).subtract(const Duration(days: 182));
      case 'Last year':
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 364));
      case 'All Time':
        return null;
      default:
        return DateTime(1970); // Fallback
    }
  }

  // Method to calculate end date (exclusive) for 'Today' filter
  DateTime? _getEndDate(String filter, DateTime? startDate) {
    if (filter == 'Today' && startDate != null) {
      return startDate.add(const Duration(days: 1));
    }
    return null;
  }

  // --- NEW: Core data processing function (Filter by test audience, then student filters, then sort) ---
  Future<List<DocumentSnapshot>>
  _processAndFilterAndSortStudentSessions() async {
    // 1. Fetch initial student sessions for this test within the date range
    final DateTime? startDate = _getStartDate(widget.dateFilter);
    final Timestamp? startTimestamp = startDate != null
        ? Timestamp.fromDate(startDate)
        : null;
    final DateTime? endDate = _getEndDate(widget.dateFilter, startDate);

    Query sessionsQuery = FirebaseFirestore.instance
        .collection('studentTestSessions')
        .where('testId', isEqualTo: widget.testId)
        .where('status', isEqualTo: 'completed');

    if (startTimestamp != null) {
      sessionsQuery = sessionsQuery.where(
        'submissionTime',
        isGreaterThanOrEqualTo: startTimestamp,
      );
    }
    if (endDate != null) {
      sessionsQuery = sessionsQuery.where(
        'submissionTime',
        isLessThan: Timestamp.fromDate(endDate),
      );
    }

    // Always order by submissionTime initially for efficient fetching
    sessionsQuery = sessionsQuery.orderBy('submissionTime', descending: true);
    QuerySnapshot snapshot = await sessionsQuery.get();
    List<DocumentSnapshot> studentSessions = snapshot.docs;

    // 2. Filter students by the Test's audience rules (based on test.allowedBranches/Years/Courses)
    List<DocumentSnapshot> filteredByTestAudience = [];
    if (widget.isFreeTest) {
      filteredByTestAudience =
          studentSessions; // No audience filtering for free tests
    } else {
      for (var sessionDoc in studentSessions) {
        final String studentId = sessionDoc['studentId'] ?? '';
        if (studentId == 'N/A' || studentId.isEmpty) continue;

        // Ensure user data is cached for this student
        final Map<String, dynamic> userData = await _fetchUserData(studentId);
        final String studentBranch = userData['branch'] ?? '';
        final String studentYear = userData['year'] ?? '';
        final String studentCourse = userData['course'] ?? '';

        bool matchesAudience = false;
        if (widget.isPaidCollegeTest) {
          // If 'All' is in test's allowedBranches/Years, it means all students in that category match.
          // Otherwise, check if student's branch/year is in the test's allowed lists.
          final bool branchMatches =
              widget.allowedBranches.contains('All') ||
              widget.allowedBranches.contains(studentBranch);
          final bool yearMatches =
              widget.allowedYears.contains('All') ||
              widget.allowedYears.contains(studentYear);
          matchesAudience = branchMatches && yearMatches;
        } else if (widget.isPaidKaduAcademyTest) {
          final bool courseMatches =
              widget.allowedCourses.contains('All') ||
              widget.allowedCourses.contains(studentCourse);
          matchesAudience = courseMatches;
        }

        if (matchesAudience) {
          filteredByTestAudience.add(sessionDoc);
        }
      }
    }

    // 3. Apply student-specific filters (Branch, Year, Course from UI dropdowns)
    List<DocumentSnapshot> finalFilteredStudents = [];
    for (var sessionDoc in filteredByTestAudience) {
      final String studentId = sessionDoc['studentId'] ?? '';
      if (studentId == 'N/A' || studentId.isEmpty) continue;

      // User data should already be cached from step 2, retrieve from cache
      final Map<String, dynamic> userData = _cachedUsers[studentId] ?? {};
      final String studentBranch = userData['branch'] ?? '';
      final String studentYear = userData['year'] ?? '';
      final String studentCourse = userData['course'] ?? '';

      bool matchesStudentBranchFilter = true;
      bool matchesStudentYearFilter = true;
      bool matchesStudentCourseFilter = true;

      // Apply these filters only if they are relevant to the test type
      if (widget.isPaidCollegeTest) {
        if (_selectedStudentBranchFilter != 'All' &&
            _selectedStudentBranchFilter.isNotEmpty) {
          matchesStudentBranchFilter =
              (studentBranch == _selectedStudentBranchFilter);
        }
        if (_selectedStudentYearFilter != 'All' &&
            _selectedStudentYearFilter.isNotEmpty) {
          matchesStudentYearFilter =
              (studentYear == _selectedStudentYearFilter);
        }
      } else if (widget.isPaidKaduAcademyTest) {
        if (_selectedStudentCourseFilter != 'All' &&
            _selectedStudentCourseFilter.isNotEmpty) {
          matchesStudentCourseFilter =
              (studentCourse == _selectedStudentCourseFilter);
        }
      }

      if (matchesStudentBranchFilter &&
          matchesStudentYearFilter &&
          matchesStudentCourseFilter) {
        finalFilteredStudents.add(sessionDoc);
      }
    }

    // 4. Apply Sorting based on selected option
    if (_selectedStudentSortOption == 'Roll Number (Ascending)') {
      finalFilteredStudents.sort((a, b) {
        final Map<String, dynamic> userDataA =
            _cachedUsers[a['studentId']] ?? {};
        final Map<String, dynamic> userDataB =
            _cachedUsers[b['studentId']] ?? {};
        final String rollNoA =
            userDataA['rollNo'] ??
            'ZZZ'; // Fallback for sorting (Z ensures it comes last)
        final String rollNoB = userDataB['rollNo'] ?? 'ZZZ';
        return rollNoA.compareTo(rollNoB);
      });
    } else {
      // Default: Submission Time (Latest First)
      finalFilteredStudents.sort((a, b) {
        final Timestamp submissionTimeA =
            a['submissionTime'] as Timestamp? ??
            Timestamp.fromMicrosecondsSinceEpoch(0);
        final Timestamp submissionTimeB =
            b['submissionTime'] as Timestamp? ??
            Timestamp.fromMicrosecondsSinceEpoch(0);
        return submissionTimeB.compareTo(submissionTimeA); // Descending
      });
    }

    return finalFilteredStudents;
  }

  // --- PDF Generation Logic ---
  Future<void> _generatePdfReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PDF report...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
        margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
    );

    final pdf = pw.Document();

    final List<DocumentSnapshot> studentSessionDocs =
        await _processAndFilterAndSortStudentSessions();
    if (studentSessionDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export to PDF.')),
      );
      return;
    }

    // --- Dynamic Headers for PDF ---
    List<String> headers = ['S.No.', 'Student Name', 'Score', 'Percentage'];
    if (widget.isPaidCollegeTest) {
      headers.addAll(['Roll No', 'Branch', 'Year']);
    }
    if (widget.isPaidKaduAcademyTest) {
      headers.add('Course');
    }
    // --- End Dynamic Headers ---

    List<List<String>> tableData = [];
    tableData.add(headers);

    int serialNumber = 1;
    for (var sessionDoc in studentSessionDocs) {
      Map<String, dynamic> sessionData =
          sessionDoc.data() as Map<String, dynamic>;
      String studentId = sessionData['studentId'] ?? 'N/A';
      double score = (sessionData['score'] as num? ?? 0.0).toDouble();
      double totalQuestions = (sessionData['totalQuestions'] as num? ?? 0.0)
          .toDouble();

      Map<String, dynamic> userData = await _fetchUserData(
        studentId,
      ); // Already cached, quick access
      String studentName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      double totalScore = totalQuestions * _marksPerQuestion;

      List<String> row = [
        '${serialNumber++}',
        studentName,
        '${score.toStringAsFixed(2)} / ${totalScore.toStringAsFixed(2)}',
        totalScore > 0
            ? '${((score / totalScore) * 100).round()}%'
            : 'N/A', // Add % here
      ];
      if (widget.isPaidCollegeTest) {
        row.addAll([
          userData['rollNo'] ?? 'N/A',
          userData['branch'] ?? 'N/A',
          userData['year'] ?? 'N/A',
        ]);
      }
      if (widget.isPaidKaduAcademyTest) {
        row.add(userData['course'] ?? 'N/A');
      }

      tableData.add(row);
    }

    // Create a filter string for the header
    String filterText = '';
    if (widget.isPaidCollegeTest) {
      if (_selectedStudentBranchFilter != 'All') {
        filterText += 'Branch: $_selectedStudentBranchFilter';
      }
      if (_selectedStudentYearFilter != 'All') {
        filterText +=
            '${filterText.isNotEmpty ? ', ' : ''}Year: $_selectedStudentYearFilter';
      }
    } else if (widget.isPaidKaduAcademyTest) {
      if (_selectedStudentCourseFilter != 'All') {
        filterText += 'Course: $_selectedStudentCourseFilter';
      }
    }
    if (filterText.isEmpty) {
      filterText = 'All Students';
    }

    pdf.addPage(
      pw.MultiPage(
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Kadu Academy - Student Test Results Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Test: ${widget.testTitle}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$filterText', // Add selected student filters
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Report Generated: ${DateTime.now().toLocal().toString().split('.')[0]}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            if (tableData.isNotEmpty)
              pw.Table.fromTextArray(
                headers: tableData.first,
                data: tableData.sublist(1),
                border: pw.TableBorder.all(color: PdfColors.grey700),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.all(6),
                columnWidths: {
                  0: const pw.FractionColumnWidth(0.08), // S.No.
                  1: const pw.FractionColumnWidth(0.24), // Student Name
                  2: const pw.FractionColumnWidth(0.12), // Score
                  3: const pw.FractionColumnWidth(0.1), // Percentage
                  4: const pw.FractionColumnWidth(0.1), // Roll No / Branch
                  5: const pw.FractionColumnWidth(0.1), // Branch / Year
                  6: const pw.FractionColumnWidth(0.1), // Year / Course
                },
              )
            else
              pw.Text('No results found for this test and filter criteria.'),
          ];
        },
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
            ),
          );
        },
      ),
    );

    try {
      final String dir = (await getTemporaryDirectory()).path;
      final String path = '$dir/${widget.testTitle}_Marks_Report.pdf';
      final List<int> pdfBytes = await pdf.save();

      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(pdfBytes);

      await OpenFilex.open(path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated and opened!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
          margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate/open PDF: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        ),
      );
    }
  }

  // --- Excel Generation Logic ---
  Future<void> _generateExcelReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating Excel report...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
        margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
    );

    final excel = Excel.createExcel();
    Sheet sheetObject = excel['Test Results'];

    // --- Dynamic Headers for Excel ---
    List<String> headers = ['S.No.', 'Student Name', 'Score'];
    if (widget.isPaidCollegeTest) {
      headers.addAll(['Roll No', 'Branch', 'Year']);
    }
    if (widget.isPaidKaduAcademyTest) {
      headers.add('Course');
    }
    headers.add('Submitted At');
    // --- End Dynamic Headers ---

    sheetObject.insertRowIterables(
      headers.map((e) => TextCellValue(e)).toList(),
      0,
    );

    final List<DocumentSnapshot> studentSessionDocs =
        await _processAndFilterAndSortStudentSessions();

    int serialNumber = 1;
    for (var sessionDoc in studentSessionDocs) {
      Map<String, dynamic> sessionData =
          sessionDoc.data() as Map<String, dynamic>;
      String studentId = sessionData['studentId'] ?? 'N/A';
      double score = (sessionData['score'] as num? ?? 0.0).toDouble();
      double totalQuestions = (sessionData['totalQuestions'] as num? ?? 0.0)
          .toDouble();
      double totalScore = totalQuestions * _marksPerQuestion;
      Timestamp submissionTime = sessionData['submissionTime'] as Timestamp;

      Map<String, dynamic> userData = await _fetchUserData(studentId);
      String studentName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();

      List<CellValue> rowData = [
        IntCellValue(serialNumber++),
        TextCellValue(studentName),
        TextCellValue(
          '${score.toStringAsFixed(2)} / ${totalScore.toStringAsFixed(2)}',
        ),
      ];
      if (widget.isPaidCollegeTest) {
        rowData.addAll([
          TextCellValue(userData['rollNo'] ?? 'N/A'),
          TextCellValue(userData['branch'] ?? 'N/A'),
          TextCellValue(userData['year'] ?? 'N/A'),
        ]);
      }
      if (widget.isPaidKaduAcademyTest) {
        rowData.add(TextCellValue(userData['course'] ?? 'N/A'));
      }
      rowData.add(
        TextCellValue(
          submissionTime.toDate().toLocal().toString().split('.')[0],
        ),
      );

      sheetObject.insertRowIterables(rowData, sheetObject.maxRows);
    }

    try {
      final String dir = (await getTemporaryDirectory()).path;
      final String path = '$dir/${widget.testTitle}_Marks_Report.xlsx';
      final List<int>? excelBytes = excel.encode();

      if (excelBytes != null) {
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(excelBytes);

        await OpenFilex.open(path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel generated and opened!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
            margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      } else {
        throw Exception("Failed to encode Excel file.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate/open Excel: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        ),
      );
    }
  }

  // Add this new state variable
  double _marksPerQuestion = 1.0; // Default value, will be updated

  @override
  void initState() {
    super.initState();
    _fetchTestDetails();
  }

  Future<void> _fetchTestDetails() async {
    try {
      DocumentSnapshot testDoc = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (testDoc.exists) {
        final testData = testDoc.data() as Map<String, dynamic>;
        setState(() {
          _marksPerQuestion =
              (testData['marksPerQuestion'] as num?)?.toDouble() ?? 1.0;
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    String testAudienceDisplay = '';
    if (widget.isFreeTest) {
      testAudienceDisplay = 'Free Test';
    } else if (widget.isPaidCollegeTest) {
      testAudienceDisplay =
          'College Test (Branches: ${widget.allowedBranches.join(', ')}, Years: ${widget.allowedYears.join(', ')})';
    } else if (widget.isPaidKaduAcademyTest) {
      testAudienceDisplay =
          'Kadu Academy Test (Courses: ${widget.allowedCourses.join(', ')})';
    }

    final List<String> availableSortOptions = widget.isPaidCollegeTest
        ? kStudentSortOptions
        : kStudentSortOptions
              .where((option) => option != 'Roll Number (Ascending)')
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Results'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdfReport,
            tooltip: 'Export to PDF',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.grid_on),
            onPressed: _generateExcelReport,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test: ${widget.testTitle}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Audience: $testAudienceDisplay',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStudentSortOption,
                  decoration: const InputDecoration(
                    labelText: 'Sort Students By',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sort),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: availableSortOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedStudentSortOption = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 10),
                if (widget.isPaidCollegeTest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedStudentBranchFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter Students by Branch',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_tree),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: kStudentBranchesForFilter.map((String branch) {
                        return DropdownMenuItem<String>(
                          value: branch,
                          child: Text(branch),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStudentBranchFilter = newValue!;
                        });
                      },
                    ),
                  ),
                if (widget.isPaidCollegeTest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedStudentYearFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter Students by Year',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: kStudentYearsForFilter.map((String year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(year),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStudentYearFilter = newValue!;
                        });
                      },
                    ),
                  ),
                if (widget.isPaidKaduAcademyTest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedStudentCourseFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter Students by Course',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: kStudentCoursesForFilter.map((String course) {
                        return DropdownMenuItem<String>(
                          value: course,
                          child: Text(course),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStudentCourseFilter = newValue!;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Student Results:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _processAndFilterAndSortStudentSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final List<DocumentSnapshot> studentSessionDocs =
                    snapshot.data ?? [];
                final int totalStudentsCount = studentSessionDocs.length;

                if (totalStudentsCount == 0) {
                  return const Center(
                    child: Text(
                      'No student results found matching the selected criteria.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Total Students: $totalStudentsCount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(0.0),
                        itemCount: totalStudentsCount,
                        itemBuilder: (context, index) {
                          DocumentSnapshot sessionDoc =
                              studentSessionDocs[index];
                          Map<String, dynamic> sessionData =
                              sessionDoc.data() as Map<String, dynamic>;

                          String studentId = sessionData['studentId'] ?? 'N/A';
                          double score = (sessionData['score'] as num? ?? 0.0)
                              .toDouble();
                          double totalQuestions =
                              (sessionData['totalQuestions'] as num? ?? 0.0)
                                  .toDouble();
                          double totalScore =
                              totalQuestions * _marksPerQuestion;
                          Timestamp submissionTime =
                              sessionData['submissionTime'] as Timestamp;

                          return FutureBuilder<Map<String, dynamic>>(
                            future: _fetchUserData(studentId),
                            builder: (context, userSnapshot) {
                              String studentName = 'Loading...';
                              String rollNo = 'N/A';
                              String studentBranch = 'N/A';
                              String studentYear = 'N/A';
                              String studentCourse = 'N/A';
                              String studentType = 'N/A';

                              final Map<String, dynamic> userData =
                                  userSnapshot.data ?? {};
                              if (userData.isNotEmpty) {
                                studentName =
                                    '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                                        .trim();
                                rollNo = userData['rollNo'] ?? 'N/A';
                                studentBranch = userData['branch'] ?? 'N/A';
                                studentYear = userData['year'] ?? 'N/A';
                                studentCourse = userData['course'] ?? 'N/A';
                                studentType = userData['studentType'] ?? 'N/A';
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (studentType == 'college')
                                        Text(
                                          'Roll No: $rollNo, Branch: $studentBranch, Year: $studentYear',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        )
                                      else if (studentType == 'kadu_academy')
                                        Text(
                                          'Course: $studentCourse',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Score: ${score.toStringAsFixed(2)} / ${totalScore.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        'Submitted: ${submissionTime.toDate().toLocal().toString().split('.')[0]}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
