import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import 'package:kadu_academy_app/screens/admin_archived_tests_screen.dart';
import 'package:kadu_academy_app/test/admin_test_detail_management_screen.dart';
import 'package:kadu_academy_app/utils/firestore_extensions.dart'; // <--- MUST BE PRESENT
import 'package:cloud_functions/cloud_functions.dart'; //

// --- Query Extension for Conditional Where Clauses ---

// --- END NEW EXTENSION ---

class AdminTestListScreen extends StatefulWidget {
  const AdminTestListScreen({super.key});

  @override
  State<AdminTestListScreen> createState() => _AdminTestListScreenState();
}

class _AdminTestListScreenState extends State<AdminTestListScreen> {
  String _currentFilter = 'All';

  final List<String> _filterOptions = const [
    'All',
    'Free Test',
    'Kadu Academy Student',
    'College Student',
  ];

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

  Future<String?> _duplicateImageAndGetUrl(String? sourceUrl) async {
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return null;
    }
    try {
      final response = await http.get(Uri.parse(sourceUrl));
      if (response.statusCode == 200) {
        final Uint8List imageBytes = response.bodyBytes;
        final String fileName =
            'question_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putData(imageBytes);
        final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
        return await snapshot.ref.getDownloadURL();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("Failed to duplicate image: $e");
      }
      return null;
    }
  }

  Future<void> _cancelScheduledPublish(String testId, String testTitle) async {
    bool confirmCancel =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Cancel Schedule'),
              content: Text(
                'Are you sure you want to cancel the scheduled publication for "$testTitle"? It will revert to Draft status.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Yes, Cancel'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmCancel) {
      return;
    }

    _showSnackBar('Cancelling schedule for "$testTitle"...');

    try {
      await FirebaseFirestore.instance.collection('tests').doc(testId).update({
        'isPublished': false, // Ensure it's not published
        'publishTime': null, // Clear immediate publish time
        'scheduledPublishTime': null, // Clear scheduled publish time
        'globalExpiryTime': null, // Clear global expiry time
        'updatedAt': Timestamp.now(), // Update timestamp
      });

      _showSnackBar('Schedule for "$testTitle" cancelled!');
    } catch (e) {
      _showSnackBar('Failed to cancel schedule: $e');
    }
  }

  // --- Function to Archive a Test ---
  Future<void> _archiveTest(String testId, String testTitle) async {
    bool confirmArchive =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Archive'),
              content: Text(
                'Are you sure you want to archive the test "$testTitle"? Archived tests will not appear in this main list.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  child: const Text('Archive'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmArchive) {
      return;
    }

    _showSnackBar('Archiving test "$testTitle"...');

    try {
      await FirebaseFirestore.instance.collection('tests').doc(testId).update({
        'isArchived': true,
        'isPublished': false,
        'publishTime': null,
        'globalExpiryTime': null,
        'scheduledPublishTime': null,
        'updatedAt': Timestamp.now(),
      });

      ;
      _showSnackBar('Test "$testTitle" archived successfully!');
    } catch (e) {
      _showSnackBar('Failed to archive test "$testTitle": $e');
    }
  }

  // --- Function to delete a test and its subcollection (questions) ---
  Future<void> _deleteTest(String testId, String testTitle) async {
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete the test "$testTitle"? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmDelete) {
      return;
    }

    _showSnackBar('Deleting test "$testTitle"...');

    try {
      QuerySnapshot questionsSnapshot = await FirebaseFirestore.instance
          .collection('tests')
          .doc(testId)
          .collection('questions')
          .get();

      for (DocumentSnapshot doc in questionsSnapshot.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance.collection('tests').doc(testId).delete();

      _showSnackBar('Test "$testTitle" deleted successfully!');
    } catch (e) {
      _showSnackBar('Failed to delete test "$testTitle": $e');
    }
  }

  // --- Function to Duplicate a Test ---
  // Replace your existing _duplicateTest function with this one.
  Future<void> _duplicateTest(
    String testId,
    String testTitle,
    Map<String, dynamic> testData,
  ) async {
    bool confirmDuplicate =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Duplicate Test'),
              content: Text(
                'Are you sure you want to duplicate the test "$testTitle" and all its questions?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Duplicate'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmDuplicate) {
      return;
    }

    _showSnackBar('Duplicating test "$testTitle"...');

    try {
      // 1. Create a new test document reference first
      final newTestDocRef = FirebaseFirestore.instance
          .collection('tests')
          .doc();

      // 2. Fetch all questions from the original test
      QuerySnapshot originalQuestionsSnapshot = await FirebaseFirestore.instance
          .collection('tests')
          .doc(testId)
          .collection('questions')
          .orderBy('order', descending: false)
          .get();

      // 3. Prepare the new test data
      final Map<String, dynamic> newTestData = {
        'title': '${testData['title'] ?? 'Untitled'} (Copy)',
        'description': testData['description'] ?? '',
        'durationMinutes': testData['durationMinutes'] ?? 0,
        'isFree': testData['isFree'] ?? false,
        'isPaidCollege': testData['isPaidCollege'] ?? false,
        'isPaidKaduAcademy': testData['isPaidKaduAcademy'] ?? false,
        'allowedCourses': List<String>.from(testData['allowedCourses'] ?? []),
        'allowedBranches': List<String>.from(testData['allowedBranches'] ?? []),
        'allowedYears': List<String>.from(testData['allowedYears'] ?? []),
        'marksPerQuestion': testData['marksPerQuestion'] ?? 1.0,
        'isNegativeMarking': testData['isNegativeMarking'] ?? false,
        'negativeMarksValue': testData['negativeMarksValue'] ?? 0.0,
        'enableOptionE': testData['enableOptionE'] ?? true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'isPublished': false,
        'publishTime': null,
        'globalExpiryTime': null,
        'scheduledPublishTime': null,
        'isArchived': false,
        'allowStudentReview': false,
        'totalQuestions': originalQuestionsSnapshot.docs.length,
      };

      // 4. Create a batch for all write operations
      final batch = FirebaseFirestore.instance.batch();

      // Set the new test document data
      batch.set(newTestDocRef, newTestData);

      // 5. Loop through original questions, duplicate images, and add to batch
      for (int i = 0; i < originalQuestionsSnapshot.docs.length; i++) {
        final questionDoc = originalQuestionsSnapshot.docs[i];
        final Map<String, dynamic> originalQuestionData =
            questionDoc.data() as Map<String, dynamic>;

        final newQuestionRef = newTestDocRef.collection('questions').doc();
        final Map<String, dynamic> newQuestionData = Map.from(
          originalQuestionData,
        );

        // Duplicate the main question image
        newQuestionData['imageUrl'] = await _duplicateImageAndGetUrl(
          originalQuestionData['imageUrl'],
        );

        // Duplicate images for options
        final options = newQuestionData['options'] as List<dynamic>;
        for (int j = 0; j < options.length; j++) {
          final option = options[j] as Map<String, dynamic>;
          if (option['imageUrl'] != null) {
            option['imageUrl'] = await _duplicateImageAndGetUrl(
              option['imageUrl'],
            );
          }
        }

        newQuestionData['createdAt'] = Timestamp.now();
        newQuestionData['updatedAt'] = Timestamp.now();
        newQuestionData['order'] = i + 1; // Correctly re-index the questions

        batch.set(newQuestionRef, newQuestionData);
      }

      // 6. Commit the batch to perform all writes atomically
      await batch.commit();

      _showSnackBar('Test "$testTitle" duplicated successfully!');
    } catch (e) {
      _showSnackBar('Failed to duplicate test "$testTitle": $e');
      if (kDebugMode) {
        print("Duplication error: $e");
      }
    }
  }

  Future<Uint8List?> _fetchImageBytes(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _toggleAllowStudentReviewStatus(
    String testId,
    String testTitle,
    bool isCurrentlyAllowed,
  ) async {
    _showSnackBar(
      '${isCurrentlyAllowed ? "Disabling" : "Enabling"} student review for "$testTitle"...',
    );
    try {
      await FirebaseFirestore.instance.collection('tests').doc(testId).update({
        'allowStudentReview': !isCurrentlyAllowed,
        'updatedAt': Timestamp.now(),
      });
      _showSnackBar(
        'Student review for "$testTitle" ${isCurrentlyAllowed ? "disabled" : "enabled"}!',
      );
    } catch (e) {
      _showSnackBar('Failed to toggle student review: $e');
    }
  }

  // --- Function to toggle Test Publish Status ---
  Future<void> _toggleTestPublishStatus(
    String testId,
    String testTitle,
    bool isCurrentlyPublished,
  ) async {
    DateTime? selectedScheduledDateTime;
    TextEditingController scheduledTimeController = TextEditingController();
    bool publishNow = true;
    DateTime? selectedExpiryDateTime;
    TextEditingController expiryController = TextEditingController();

    try {
      if (!isCurrentlyPublished) {
        bool? confirmedPublishChoice = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setInnerState) {
                return AlertDialog(
                  title: Text('Publish Test: "$testTitle"'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('How do you want to publish this test?'),
                      const SizedBox(height: 10),
                      RadioListTile<bool>(
                        title: const Text('Publish Now'),
                        value: true,
                        groupValue: publishNow,
                        onChanged: (bool? value) {
                          setInnerState(() {
                            publishNow = value!;
                            scheduledTimeController.clear();
                            selectedScheduledDateTime = null;
                          });
                        },
                      ),
                      RadioListTile<bool>(
                        title: const Text('Schedule Publish Time'),
                        value: false,
                        groupValue: publishNow,
                        onChanged: (bool? value) {
                          setInnerState(() {
                            publishNow = value!;
                          });
                        },
                      ),
                      if (!publishNow)
                        Column(
                          children: [
                            const SizedBox(height: 10),
                            TextField(
                              controller: scheduledTimeController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Schedule Time',
                                hintText: 'Tap to select date and time',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              onTap: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(minutes: 5),
                                  ),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (pickedDate != null) {
                                  TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (pickedTime != null) {
                                    DateTime finalDateTime = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                    if (finalDateTime.isBefore(
                                      DateTime.now().subtract(
                                        const Duration(seconds: 5),
                                      ),
                                    )) {
                                      _showSnackBar(
                                        'Scheduled time must be in the future.',
                                        duration: 3,
                                      );
                                      return;
                                    }
                                    setInnerState(() {
                                      selectedScheduledDateTime = finalDateTime;
                                      scheduledTimeController.text = DateFormat(
                                        'dd MMM yyyy, hh:mm a',
                                      ).format(finalDateTime.toLocal());
                                    });
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Set an optional global expiry date and time for this test.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: expiryController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Global Expiry (Optional)',
                          hintText: 'Tap to select date and time',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (pickedDate != null) {
                            TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setInnerState(() {
                                DateTime tempSelectedExpiryDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                                selectedExpiryDateTime =
                                    tempSelectedExpiryDateTime;
                                expiryController.text = DateFormat(
                                  'dd MMM yyyy, hh:mm a',
                                ).format(selectedExpiryDateTime!.toLocal());
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        DateTime effectivePublishTime = publishNow
                            ? DateTime.now()
                            : selectedScheduledDateTime ??
                                  DateTime.now().add(
                                    const Duration(days: 9999),
                                  );

                        if (selectedExpiryDateTime != null &&
                            effectivePublishTime.isAfter(
                              selectedExpiryDateTime!,
                            )) {
                          _showSnackBar(
                            'Publish time cannot be after expiry time.',
                            duration: 3,
                          );
                          return;
                        }

                        if (effectivePublishTime.isBefore(
                          DateTime.now().subtract(const Duration(seconds: 10)),
                        )) {
                          _showSnackBar(
                            'Publish time must be in the future.',
                            duration: 3,
                          );
                          return;
                        }

                        Navigator.of(context).pop(true);
                      },
                      child: const Text('Confirm Publish'),
                    ),
                  ],
                );
              },
            );
          },
        );
        if (confirmedPublishChoice == false || confirmedPublishChoice == null) {
          return;
        }

        bool isPublishedOnSubmit;
        Timestamp? publishTimeOnSubmit;
        Timestamp? scheduledPublishTimestampForDb;

        if (publishNow) {
          isPublishedOnSubmit = true;
          publishTimeOnSubmit = Timestamp.now();
          scheduledPublishTimestampForDb = null;
        } else {
          isPublishedOnSubmit = false;
          publishTimeOnSubmit = null;
          scheduledPublishTimestampForDb = selectedScheduledDateTime != null
              ? Timestamp.fromDate(selectedScheduledDateTime!)
              : null;
        }

        Timestamp? selectedGlobalExpiryTimeTimestamp =
            selectedExpiryDateTime != null
            ? Timestamp.fromDate(selectedExpiryDateTime!)
            : null;

        DocumentReference testDocRef = FirebaseFirestore.instance
            .collection('tests')
            .doc(testId);
        await testDocRef.update({
          'isPublished': isPublishedOnSubmit,
          'publishTime': publishTimeOnSubmit,
          'globalExpiryTime': selectedGlobalExpiryTimeTimestamp,
          'scheduledPublishTime': scheduledPublishTimestampForDb,
          'updatedAt': Timestamp.now(),
        });

        // --- NEW: Call the Cloud Function for scheduled tests ---
        if (!publishNow && scheduledPublishTimestampForDb != null) {
          try {
            final HttpsCallable callable = FirebaseFunctions.instance
                .httpsCallable('sendScheduledTestNotification');
            final result = await callable.call(<String, dynamic>{
              'testId': testId,
              'testTitle': testTitle,
              'scheduledTime': scheduledPublishTimestampForDb
                  .toDate()
                  .toIso8601String(), // Pass as ISO string
            });
          } on FirebaseFunctionsException catch (e) {
            _showSnackBar(
              'Failed to send scheduled notification: ${e.message}',
            );
          } catch (e) {
            ;
            _showSnackBar('Failed to send scheduled notification: $e');
          }
        }
        // --- END NEW ---

        _showSnackBar(
          'Test "$testTitle" ${isPublishedOnSubmit ? "published!" : "scheduled."}',
        );
      } else {
        // ... (rest of unpublish logic - no changes needed here)
        bool? confirmedUnpublish = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            TextEditingController unpublishDummyController =
                TextEditingController();
            return AlertDialog(
              title: Text('Unpublish Test: "$testTitle"'),
              content: const Text(
                'Are you sure you want to unpublish this test? Students will no longer see it.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    unpublishDummyController.dispose();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    unpublishDummyController.dispose();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Unpublish'),
                ),
              ],
            );
          },
        );
        if (confirmedUnpublish == false || confirmedUnpublish == null) {
          return;
        }

        DocumentReference testDocRef = FirebaseFirestore.instance
            .collection('tests')
            .doc(testId);
        await testDocRef.update({
          'isPublished': false,
          'publishTime': null,
          'globalExpiryTime': null,
          'scheduledPublishTime': null,
          'updatedAt': Timestamp.now(),
        });

        _showSnackBar('Test "$testTitle" unpublished.');
      }
    } finally {
      scheduledTimeController.dispose();
      expiryController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Test Management',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // NEW: Filter Dropdown (no change here)
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
          // NEW: Button to View Archived Tests (no change here)
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminArchivedTestsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.archive),
                label: const Text(
                  'View Archived Tests',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          // StreamBuilder for fetching and displaying tests
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tests')
                  .where('isArchived', isEqualTo: false)
                  // --- START CHANGED LINES ---
                  .when(
                    _currentFilter == 'Free Test',
                    (query) => query.where('isFree', isEqualTo: true),
                  )
                  .when(
                    _currentFilter == 'Kadu Academy Student',
                    (query) =>
                        query.where('isPaidKaduAcademy', isEqualTo: true),
                  )
                  .when(
                    _currentFilter == 'College Student',
                    (query) => query.where('isPaidCollege', isEqualTo: true),
                  )
                  .orderBy('createdAt', descending: true)
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
                    child: Text(
                      'No active tests found for selected filter. Create one or check archived tests.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 0.0,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot testDocument = snapshot.data!.docs[index];
                    Map<String, dynamic> testData =
                        testDocument.data() as Map<String, dynamic>;

                    String testId = testDocument.id;
                    String title = testData['title'] ?? 'No Title';
                    String description =
                        testData['description'] ?? 'No Description';
                    int duration = testData['durationMinutes'] ?? 0;
                    bool isPublished = testData['isPublished'] ?? false;
                    bool isArchived = testData['isArchived'] ?? false;

                    Timestamp? publishTime =
                        testData['publishTime'] as Timestamp?;
                    Timestamp? globalExpiryTime =
                        testData['globalExpiryTime'] as Timestamp?;
                    Timestamp? scheduledPublishTime =
                        testData['scheduledPublishTime'] as Timestamp?;
                    bool allowStudentReview =
                        testData['allowStudentReview'] ?? false;

                    // --- START CHANGED LINES ---
                    bool isFreeTest = testData['isFree'] ?? false;
                    bool isPaidCollegeTest = testData['isPaidCollege'] ?? false;
                    bool isPaidKaduAcademyTest =
                        testData['isPaidKaduAcademy'] ?? false;

                    String displayedTestType;
                    if (isFreeTest) {
                      displayedTestType = 'Free';
                    } else if (isPaidKaduAcademyTest) {
                      displayedTestType = 'Kadu Academy Student';
                    } else if (isPaidCollegeTest) {
                      displayedTestType = 'College Student';
                    } else {
                      displayedTestType =
                          'Undefined'; // Fallback if no type is set
                    }
                    // --- END CHANGED LINES ---

                    List<String> allowedCourses = List<String>.from(
                      testData['allowedCourses'] ?? [],
                    );
                    List<String> allowedBranches = List<String>.from(
                      testData['allowedBranches'] ?? [],
                    );
                    List<String> allowedYears = List<String>.from(
                      testData['allowedYears'] ?? [],
                    );
                    final dynamic marksPerQuestionRaw =
                        testData['marksPerQuestion'];
                    double marksPerQuestion = marksPerQuestionRaw is int
                        ? marksPerQuestionRaw.toDouble()
                        : marksPerQuestionRaw ?? 1.0;
                    bool isNegativeMarking =
                        testData['isNegativeMarking'] ?? false;
                    final dynamic negativeMarksValueRaw =
                        testData['negativeMarksValue'];
                    double negativeMarksValue = negativeMarksValueRaw is int
                        ? negativeMarksValueRaw.toDouble()
                        : negativeMarksValueRaw ?? 0.0;
                    bool enableOptionE = testData['enableOptionE'] ?? true;

                    String statusText;
                    Color statusColor;
                    String publishButtonLabel;
                    Color publishButtonColor;
                    VoidCallback? publishButtonOnPressed;

                    final DateTime now = DateTime.now();

                    if (isPublished) {
                      statusText = 'Status: Published';
                      statusColor = Colors.green;
                      publishButtonLabel = 'Unpublish Test';
                      publishButtonColor = Colors.orange;
                      publishButtonOnPressed = () =>
                          _toggleTestPublishStatus(testId, title, isPublished);
                    } else if (scheduledPublishTime != null &&
                        now.isBefore(scheduledPublishTime.toDate())) {
                      statusText = 'Status: Scheduled';
                      statusColor = Colors.blue[800]!;
                      publishButtonLabel = 'Scheduled';
                      publishButtonColor = Colors.blueGrey;
                      publishButtonOnPressed = null;
                    } else if (globalExpiryTime != null &&
                        now.isAfter(globalExpiryTime.toDate())) {
                      statusText = 'Status: Expired';
                      statusColor = Colors.red;
                      publishButtonLabel = 'Publish Test';
                      publishButtonColor = Colors.green;
                      publishButtonOnPressed = () =>
                          _toggleTestPublishStatus(testId, title, isPublished);
                    } else {
                      statusText = 'Status: Draft';
                      statusColor = Colors.orange;
                      publishButtonLabel = 'Publish Test';
                      publishButtonColor = Colors.green;
                      publishButtonOnPressed = () =>
                          _toggleTestPublishStatus(testId, title, isPublished);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // --- START CHANGED LINES ---
                            // Display the determined Test Type
                            Text(
                              'Test Type: $displayedTestType',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo[700],
                              ),
                            ),
                            // Display Conditional Access Details based on new boolean flags
                            if (isPaidKaduAcademyTest &&
                                allowedCourses.isNotEmpty)
                              Text(
                                'Courses: ${allowedCourses.join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey[700],
                                ),
                              ),
                            if (isPaidCollegeTest)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (allowedBranches.isNotEmpty)
                                    Text(
                                      'Branches: ${allowedBranches.join(', ')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey[700],
                                      ),
                                    ),
                                  if (allowedYears.isNotEmpty)
                                    Text(
                                      'Years: ${allowedYears.join(', ')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey[700],
                                      ),
                                    ),
                                ],
                              ),
                            // --- END CHANGED LINES ---
                            // NEW: Display Marking Scheme (no change here)
                            Text(
                              'Marks/Q: ${marksPerQuestion.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Negative Marking: ${isNegativeMarking ? 'Yes (${negativeMarksValue.toStringAsFixed(2)})' : 'No'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            // NEW: Display Option E Status (no change here)
                            Text(
                              'Option E Enabled: ${enableOptionE ? 'Yes' : 'No'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isPublished && publishTime != null)
                              Text(
                                'Published On: ${formatter.format(publishTime.toDate().toLocal())}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            if (scheduledPublishTime != null && !isPublished)
                              Text(
                                'Scheduled For: ${formatter.format(scheduledPublishTime.toDate().toLocal())}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue[800],
                                ),
                              ),
                            if (globalExpiryTime != null)
                              Text(
                                'Global Expiry: ${formatter.format(globalExpiryTime.toDate().toLocal())}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                ),
                              ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: [
                                Switch(
                                  value: allowStudentReview,
                                  onChanged: isPublished
                                      ? (bool value) {
                                          _toggleAllowStudentReviewStatus(
                                            testId,
                                            title,
                                            allowStudentReview,
                                          );
                                        }
                                      : null,
                                  activeColor: Colors.blueAccent,
                                ),
                                Text(
                                  allowStudentReview
                                      ? 'Review ON'
                                      : 'Review OFF',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPublished
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _duplicateTest(testId, title, testData),
                                  child: const Text(
                                    'Duplicate',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/admin_test_detail_management',
                                      arguments: {
                                        'testId': testId,
                                        'initialTestData': testData,
                                      },
                                    );
                                  },
                                  child: const Text(
                                    'Edit',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _deleteTest(testId, title),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _archiveTest(testId, title),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blueGrey[700],
                                  ),
                                  child: const Text(
                                    'Archive',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                if (!isPublished &&
                                    scheduledPublishTime != null &&
                                    now.isBefore(scheduledPublishTime.toDate()))
                                  TextButton(
                                    onPressed: () =>
                                        _cancelScheduledPublish(testId, title),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                    ), // A distinct color
                                    child: const Text(
                                      'Cancel Schedule',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ElevatedButton(
                                  onPressed: publishButtonOnPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: publishButtonColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    publishButtonLabel,
                                    style: const TextStyle(fontSize: 12),
                                  ),
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/admin_create_test');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
