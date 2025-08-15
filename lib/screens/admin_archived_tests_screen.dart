import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart'
    as http; // Make sure http package is in pubspec.yaml
import 'package:intl/intl.dart'; // Make sure intl package is in pubspec.yaml
import 'package:flutter/foundation.dart'; // For Uint8List in _fetchImageBytes (already there)
import 'package:kadu_academy_app/screens/admin_test_specific_marks_screen.dart';
import 'package:kadu_academy_app/utils/firestore_extensions.dart'; // <--- THIS LINE MUST BE PRESENT

// Import other screens if needed for navigation.
// Currently only admin_test_specific_marks_screen.dart is imported, which is fine.

// --- NEW: Query Extension for Conditional Where Clauses ---

// --- END NEW EXTENSION ---

class AdminArchivedTestsScreen extends StatefulWidget {
  const AdminArchivedTestsScreen({super.key});

  @override
  State<AdminArchivedTestsScreen> createState() =>
      _AdminArchivedTestsScreenState();
}

class _AdminArchivedTestsScreenState extends State<AdminArchivedTestsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _currentFilter = 'All'; // Default filter option

  final List<String> _filterOptions = const [
    'All',
    'Free Test',
    'Kadu Academy Student',
    'College Student',
  ];

  // --- NEW: Helper for SnackBar Styling (consistent with other admin screens) ---
  void _showSnackBar(String message, {int duration = 1}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11), // Smaller font
        ),
        behavior: SnackBarBehavior.floating, // Uplifted
        duration: Duration(seconds: duration),
        margin: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 10.0,
        ), // Slightly uplifted
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ), // Rounded corners
      ),
    );
  }
  // --- END NEW SNACKBAR HELPER ---

  // MODIFIED: Stream to get only archived tests, now with filter and sort
  Stream<QuerySnapshot> _buildArchivedTestsStream() {
    Query query = FirebaseFirestore.instance
        .collection('tests')
        .where(
          'isArchived',
          isEqualTo: true,
        ); // Always filter for archived tests

    if (_searchQuery.isNotEmpty) {
      String lowerCaseSearchQuery = _searchQuery.toLowerCase();
      query = query
          .where(
            'title_lowercase',
            isGreaterThanOrEqualTo: lowerCaseSearchQuery,
          )
          .where(
            'title_lowercase',
            isLessThanOrEqualTo: '$lowerCaseSearchQuery\uf8ff',
          );
    }

    // Apply filtering based on _currentFilter (NEW)
    // --- START CHANGED LINES ---
    query = query
        .when(
          _currentFilter == 'Free Test',
          (q) => q.where('isFree', isEqualTo: true),
        )
        .when(
          _currentFilter == 'Kadu Academy Student',
          (q) => q.where('isPaidKaduAcademy', isEqualTo: true),
        )
        .when(
          _currentFilter == 'College Student',
          (q) => q.where('isPaidCollege', isEqualTo: true),
        );

    // Always order by creation date, most recent at top (NEW)
    query = query.orderBy('createdAt', descending: true); // Default sort

    return query.snapshots();
  }

  Future<void> _unpublishArchivedTest(String testId, String testTitle) async {
    _showSnackBar('Unpublishing archived test "$testTitle"...', duration: 1);

    try {
      await FirebaseFirestore.instance.collection('tests').doc(testId).update({
        'isPublished': false,
        'publishTime': null,
        'globalExpiryTime': null,
        'scheduledPublishTime': null,
        'allowStudentReview': false, // Also turn off review when unpublishing
        'updatedAt': Timestamp.now(),
        // Note: 'isPermanentlyUnpublishable' is managed during archive/unarchive,
        // not directly by this unpublish button.
      });
      _showSnackBar(
        'Archived test "$testTitle" unpublished successfully!',
        duration: 1,
      );
    } catch (e) {
      _showSnackBar('Failed to unpublish archived test: $e');
    }
  }

  // Function to unarchive a test (modified to use _showSnackBar)
  Future<void> _unarchiveTest(String testId, String testTitle) async {
    bool confirmUnarchive =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Unarchive'),
              content: Text(
                'Are you sure you want to unarchive the test "$testTitle"? It will move back to the main active tests list.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  child: const Text('Unarchive'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmUnarchive) {
      return;
    }

    _showSnackBar(
      'Unarchiving test "$testTitle"...',
      duration: 1,
    ); // Use new SnackBar helper

    try {
      await FirebaseFirestore.instance.collection('tests').doc(testId).update({
        'isArchived': false,
        'updatedAt': Timestamp.now(),
        // title_lowercase should generally be updated by admin test management screen,
        // but can be set here as a fallback on unarchive if title changes.
        // 'title_lowercase': testTitle.toLowerCase(),
      });
      _showSnackBar(
        'Test unarchived successfully!',
        duration: 1,
      ); // Use new SnackBar helper
    } catch (e) {
      _showSnackBar('Failed to unarchive test: $e'); // Use new SnackBar helper
    }
  }

  // Function to permanently delete an archived test (modified to use _showSnackBar)
  Future<void> _deleteArchivedTest(String testId, String testTitle) async {
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Permanent Deletion'),
              content: Text(
                'Are you sure you want to PERMANENTLY delete the archived test "$testTitle"? This cannot be undone and will also delete its questions and associated student sessions!',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmDelete) {
      return;
    }

    _showSnackBar(
      'Permanently deleting archived test "$testTitle"...',
      duration: 1,
    ); // Use new SnackBar helper

    try {
      // 1. Delete associated studentTestSessions
      QuerySnapshot sessionsSnapshot = await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .where('testId', isEqualTo: testId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (DocumentSnapshot doc in sessionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 2. Delete all questions in the subcollection first
      QuerySnapshot questionsSnapshot = await FirebaseFirestore.instance
          .collection('tests')
          .doc(testId)
          .collection('questions')
          .get();

      for (DocumentSnapshot doc in questionsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 3. Then delete the test document itself
      await FirebaseFirestore.instance.collection('tests').doc(testId).delete();

      _showSnackBar(
        'Archived test "$testTitle" permanently deleted!',
        duration: 1,
      ); // Use new SnackBar helper
    } catch (e) {
      _showSnackBar(
        'Failed to permanently delete archived test: $e',
      ); // Use new SnackBar helper
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make sure to import intl package (already present based on original code)
    final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Tests'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Topic Name (Case-Insensitive)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: Column(
        // Use Column to stack filter dropdown and test list
        children: [
          // NEW: Filter Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: DropdownButtonFormField<String>(
              value: _currentFilter,
              decoration: const InputDecoration(
                labelText: 'Filter Tests',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_list),
              ),
              items: _filterOptions.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _currentFilter = newValue!;
                });
              },
            ),
          ),
          // StreamBuilder for fetching and displaying tests
          Expanded(
            // Expanded to make ListView take remaining space
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildArchivedTestsStream(), // Use the dynamic stream
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty || _currentFilter != 'All'
                          ? 'No archived tests found matching your criteria.'
                          : 'No archived tests found.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final List<DocumentSnapshot> archivedTests =
                    snapshot.data!.docs;

                // ... (Your existing code before the ListView.builder in the build method)

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: archivedTests.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot testDocument = archivedTests[index];
                    Map<String, dynamic> testData =
                        testDocument.data() as Map<String, dynamic>;
                    String branch = testData['branch'] ?? 'N/A';
                    String year = testData['year'] ?? 'N/A';
                    String testId = testDocument.id;
                    String title =
                        testData['title'] ?? 'Untitled Archived Test';
                    String description =
                        testData['description'] ?? 'No Description';
                    int duration = testData['durationMinutes'] ?? 0;
                    bool isPublished = testData['isPublished'] ?? false;
                    bool allowStudentReview =
                        testData['allowStudentReview'] ?? false;
                    bool isPermanentlyUnpublishable =
                        testData['isPermanentlyUnpublishable'] ?? false;

                    String accessType = testData['accessType'] ?? 'Not Set';
                    List<String> allowedCourses = List<String>.from(
                      testData['allowedCourses'] ?? [],
                    );
                    List<String> allowedBranches = List<String>.from(
                      testData['allowedBranches'] ?? [],
                    );
                    List<String> allowedYears = List<String>.from(
                      testData['allowedYears'] ?? [],
                    );
                    double marksPerQuestion =
                        testData['marksPerQuestion'] ?? 1.0;
                    bool isNegativeMarking =
                        testData['isNegativeMarking'] ?? false;
                    double negativeMarksValue =
                        testData['negativeMarksValue'] ?? 0.0;
                    bool enableOptionE = testData['enableOptionE'] ?? true;

                    Timestamp? createdAt = testData['createdAt'] as Timestamp?;
                    Timestamp? updatedAt = testData['updatedAt'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            // Main row to hold content and action buttons
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                // Content area (title + subtitle details)
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Duration: $duration minutes',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Test Type: $accessType',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo[700],
                                      ),
                                    ),
                                    if (accessType == 'Kadu Academy Student' &&
                                        allowedCourses.isNotEmpty)
                                      Text(
                                        'Courses: ${allowedCourses.join(', ')}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey[700],
                                        ),
                                      ),
                                    if (accessType == 'College Student')
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (allowedBranches.isNotEmpty)
                                            Text(
                                              'Branches: ${allowedBranches.join(', ')}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blueGrey[700],
                                              ),
                                            ),
                                          if (allowedYears.isNotEmpty)
                                            Text(
                                              'Years: ${allowedYears.join(', ')}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blueGrey[700],
                                              ),
                                            ),
                                        ],
                                      ),
                                    Text(
                                      'Marks/Q: ${marksPerQuestion.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Negative Marking: ${isNegativeMarking ? 'Yes (${negativeMarksValue.toStringAsFixed(2)})' : 'No'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Option E Enabled: ${enableOptionE ? 'Yes' : 'No'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (createdAt != null)
                                      Text(
                                        'Created: ${formatter.format(createdAt.toDate().toLocal())}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    if (updatedAt != null)
                                      Text(
                                        'Updated: ${formatter.format(updatedAt.toDate().toLocal())}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    Text(
                                      'Published: ${isPublished ? 'Yes' : 'No'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isPublished
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    Text(
                                      'Review Allowed: ${allowStudentReview ? 'Yes' : 'No'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // --- START ADDED LINE ---
                              const SizedBox(
                                width: 8,
                              ), // Small horizontal spacing between text and buttons
                              // --- END ADDED LINE ---
                              // Action Buttons Column
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  isPublished
                                      ? ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _unpublishArchivedTest(
                                                testId,
                                                title,
                                              ),
                                          child: const Text(
                                            'Unpublish',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        )
                                      : AbsorbPointer(
                                          absorbing: true,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size.zero,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                            onPressed: null,
                                            child: const Text(
                                              'Unpublish',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                  const SizedBox(height: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.unarchive,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'Unarchive Test',
                                    onPressed: () =>
                                        _unarchiveTest(testId, title),
                                    iconSize: 25,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(height: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Permanently Delete Test',
                                    onPressed: () =>
                                        _deleteArchivedTest(testId, title),
                                    iconSize: 25,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
