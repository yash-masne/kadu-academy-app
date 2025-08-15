// File: lib/screens/student_take_test_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kadu_academy_app/widgets/question_content_widget.dart';
import 'package:kadu_academy_app/utils/text_formatter.dart';
import 'package:kadu_academy_app/screens/student_test_review_screen.dart';

class StudentTakeTestScreen extends StatefulWidget {
  final String testId;
  final String studentTestSessionId;
  final int testDurationMinutes;
  final String testTitle;
  final bool allowStudentReview;

  const StudentTakeTestScreen({
    super.key,
    required this.testId,
    required this.studentTestSessionId,
    required this.testDurationMinutes,
    required this.testTitle,
    required this.allowStudentReview,
  });

  @override
  State<StudentTakeTestScreen> createState() => _StudentTakeTestScreenState();
}

class _StudentTakeTestScreenState extends State<StudentTakeTestScreen>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('com.kaduacademy.app/secure_screen');

  // MODIFIED: We now store question IDs and a map to hold fetched content.
  List<String> _questionIds = [];
  Map<String, Map<String, dynamic>> _fetchedQuestionsData = {};
  int _currentQuestionIndex = 0;
  Map<String, int> _selectedAnswers = {};
  bool _isLoading = true;
  bool _testSubmitted = false;

  List<Map<String, dynamic>> _sections = [];
  String? _selectedSection;

  // NEW: Filtered question IDs based on the selected section
  List<String> _filteredQuestionIds = [];
  Timer? _timer;
  int _remainingSeconds = 0;
  Timestamp? _sessionEndTime;

  double _marksPerQuestion = 1.0;
  bool _isNegativeMarking = false;
  double _negativeMarksValue = 0.0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _fetchQuestionsAndSession();
    _setSecureScreen();
    _setKeepScreenOn();
    _setSystemUiMode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _clearSecureScreen();
    _clearKeepScreenOn();
    _clearSystemUiMode();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_testSubmitted) {
        _autoSubmitTest(isBackground: true);
      }
    }
  }

  Future<void> _setSecureScreen() async {
    try {
      await platform.invokeMethod('setSecureScreen');
    } on PlatformException catch (e) {}
  }

  Future<void> _clearSecureScreen() async {
    try {
      await platform.invokeMethod('clearSecureScreen');
    } on PlatformException catch (e) {}
  }

  Future<void> _setKeepScreenOn() async {
    try {
      await platform.invokeMethod('setKeepScreenOn');
    } on PlatformException catch (e) {}
  }

  Future<void> _clearKeepScreenOn() async {
    try {
      await platform.invokeMethod('clearKeepScreenOn');
    } on PlatformException catch (e) {}
  }

  Future<void> _setSystemUiMode() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  // NEW: Function to filter questions based on the selected section
  void _filterQuestionsBySection() {
    if (_selectedSection == null) {
      _filteredQuestionIds = _questionIds;
    } else {
      _filteredQuestionIds = _questionIds.where((questionId) {
        final questionData = _fetchedQuestionsData[questionId];
        return questionData != null &&
            questionData['sectionName'] == _selectedSection;
      }).toList();
    }
  }

  Color _getColorForSection(String sectionName) {
    // Use a hash code to generate a unique, but consistent, color.
    final int hash = sectionName.hashCode;
    final red = (hash & 0xFF0000) >> 16;
    final green = (hash & 0x00FF00) >> 8;
    final blue = (hash & 0x0000FF);
    return Color.fromARGB(255, red, green, blue);
  }

  Future<void> _clearSystemUiMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // MODIFIED: This function now fetches only question IDs initially.
  Future<void> _fetchQuestionsAndSession() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Step 1: Fetch the session and test configuration documents first.
      DocumentSnapshot sessionDoc = await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .doc(widget.studentTestSessionId)
          .get();

      DocumentSnapshot testConfigDoc = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (!testConfigDoc.exists || !sessionDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Test configuration or session not found.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              margin: EdgeInsets.only(bottom: 180.0),
            ),
          );
        }
        Navigator.pop(context);
        return;
      }
      Map<String, dynamic> testConfigData =
          testConfigDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> sessionData =
          sessionDoc.data() as Map<String, dynamic>;
      final List<dynamic> fetchedSections =
          testConfigData['sections'] as List<dynamic>? ?? [];
      _sections = List<Map<String, dynamic>>.from(fetchedSections);

      if (sessionData['status'] == 'completed') {
        _testSubmitted = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This test has already been completed. Your score: ${(sessionData['score'] as num?)?.toStringAsFixed(2) ?? 'N/A'} out of ${sessionData['totalQuestions'] ?? 'N/A'}.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              margin: const EdgeInsets.only(bottom: 180.0),
            ),
          );
        }
        Navigator.pop(context);
        return;
      }

      // Step 2: Extract test config and session state.
      _sessionEndTime = sessionData['studentEndTime'] as Timestamp;
      _selectedAnswers = Map<String, int>.from(sessionData['answers'] ?? {});
      _marksPerQuestion =
          (testConfigData['marksPerQuestion'] as num?)?.toDouble() ?? 1.0;
      _isNegativeMarking = testConfigData['isNegativeMarking'] ?? false;
      _negativeMarksValue =
          (testConfigData['negativeMarksValue'] as num?)?.toDouble() ?? 0.0;
      _remainingSeconds = _sessionEndTime!
          .toDate()
          .difference(DateTime.now())
          .inSeconds;

      if (_remainingSeconds <= 0) {
        _testSubmitted = true;
        _autoSubmitTest();
        return;
      }

      // Step 3: Fetch only the list of question IDs.
      // Step 3: Fetch all questions and their data at once for initial load
      QuerySnapshot questionsSnapshot = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('questions')
          .orderBy('order', descending: false)
          .get();

      final allQuestions = questionsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add the question ID to the data
        _fetchedQuestionsData[doc.id] = data; // Cache the data
        return data;
      }).toList();

      setState(() {
        _questionIds = allQuestions.map((q) => q['id'] as String).toList();
        _isLoading = false;

        // Apply the initial filter
        _filterQuestionsBySection();
      });

      // Step 4: The timer is started after fetching all questions
      if (!_testSubmitted && _questionIds.isNotEmpty) {
        _startTimer();
        await _fetchQuestionData(_questionIds.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load test: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            margin: const EdgeInsets.only(bottom: 180.0),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      _timer?.cancel();
      Navigator.pop(context);
    }
  }

  // NEW: Function to fetch a single question's data on demand.
  Future<void> _fetchQuestionData(String questionId) async {
    // Check if the question is already in memory.
    if (_fetchedQuestionsData.containsKey(questionId)) {
      return;
    }

    try {
      DocumentSnapshot questionDoc = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('questions')
          .doc(questionId)
          .get();

      if (questionDoc.exists) {
        setState(() {
          _fetchedQuestionsData[questionId] =
              questionDoc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      // Handle the error gracefully without crashing.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load question: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            margin: const EdgeInsets.only(bottom: 180.0),
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          if (!_testSubmitted) {
            _autoSubmitTest();
          }
        }
      });
    });
  }

  double _calculateScore() {
    double score = 0.0;

    for (var questionId in _questionIds) {
      final questionData = _fetchedQuestionsData[questionId];
      if (questionData == null) continue;

      List<dynamic> options = questionData['options'] ?? [];
      int? studentSelectedOptionIndex = _selectedAnswers[questionId];

      if (studentSelectedOptionIndex != null &&
          studentSelectedOptionIndex >= 0 &&
          studentSelectedOptionIndex < options.length) {
        if (options[studentSelectedOptionIndex]['isCorrect'] == true) {
          score += _marksPerQuestion;
        } else {
          if (_isNegativeMarking) {
            score -= _negativeMarksValue;
          }
        }
      }
    }
    return score;
  }

  Future<void> _confirmAndSubmitTest() async {
    if (_testSubmitted) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Submit Test?'),
        content: Text(
          'You have ${_formatTime(_remainingSeconds)} remaining. Are you sure you want to submit the test?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _submitTest();
    }
  }

  // ADDED: New function to show section selection in a modal.
  void _showSectionSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Section',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    // NEW: Add a list tile for "All" sections
                    ListTile(
                      title: const Text('All'),
                      selected: _selectedSection == null,
                      onTap: () {
                        setState(() {
                          _selectedSection = null;
                          _filterQuestionsBySection();
                          _pageController.jumpToPage(0);
                        });
                        Navigator.pop(context);
                      },
                    ),
                    // ADDED: Map the existing sections to list tiles
                    ..._sections.map((section) {
                      return ListTile(
                        title: Text(section['name']),
                        selected: _selectedSection == section['name'],
                        onTap: () {
                          setState(() {
                            _selectedSection = section['name'];
                            _filterQuestionsBySection();
                            _pageController.jumpToPage(0);
                          });
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitTest() async {
    if (_testSubmitted) return;
    _testSubmitted = true;
    _timer?.cancel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submitting test...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          margin: EdgeInsets.only(bottom: 180.0),
        ),
      );
    }

    double finalScore = _calculateScore();

    try {
      await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .doc(widget.studentTestSessionId)
          .update({
            'status': 'completed',
            'submissionTime': Timestamp.now(),
            'score': finalScore,
            'totalQuestions': _questionIds.length,
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            margin: const EdgeInsets.only(bottom: 180.0),
          ),
        );
      }
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } finally {
      _clearSecureScreen();
      _clearKeepScreenOn();
    }
  }

  Future<void> _autoSubmitTest({bool isBackground = false}) async {
    if (_testSubmitted) return;
    _testSubmitted = true;
    _timer?.cancel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBackground
                ? 'Exiting test! Submitting automatically...'
                : 'Time\'s up! Submitting test automatically!',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          margin: const EdgeInsets.only(bottom: 180.0),
        ),
      );
    }

    double finalScore = _calculateScore();

    try {
      await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .doc(widget.studentTestSessionId)
          .update({
            'status': 'completed',
            'submissionTime': Timestamp.now(),
            'score': finalScore,
            'totalQuestions': _questionIds.length,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-submission failed: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            margin: const EdgeInsets.only(bottom: 180.0),
          ),
        );
      }
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } finally {
      _clearSecureScreen();
      _clearKeepScreenOn();
    }
  }

  Future<void> _saveAnswerToFirestore(
    String questionId,
    int optionIndex,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .doc(widget.studentTestSessionId)
          .update({'answers.$questionId': optionIndex});
    } catch (e) {}
  }

  void _onOptionSelected(String questionId, int optionIndex) {
    if (_testSubmitted) return;
    setState(() {
      _selectedAnswers[questionId] = optionIndex;
    });
    _saveAnswerToFirestore(questionId, optionIndex);
  }

  Future<void> _clearResponseForCurrentQuestion() async {
    if (_testSubmitted) return;
    final currentQuestionId = _questionIds[_currentQuestionIndex];
    setState(() {
      _selectedAnswers.remove(currentQuestionId);
    });
    try {
      await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .doc(widget.studentTestSessionId)
          .update({'answers.$currentQuestionId': FieldValue.delete()});
    } catch (e) {}
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showQuestionPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.only(
            top: 40.0,
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 16.0),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Questions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12.0,
                runSpacing: 8.0,
                children: [
                  _buildLegendItem(
                    Icons.check_circle,
                    Colors.green,
                    'Answered',
                  ),
                  _buildLegendItem(
                    Icons.radio_button_unchecked,
                    Colors.grey,
                    'Not Answered',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _questionIds.length,
                  itemBuilder: (context, index) {
                    final questionId = _questionIds[index];
                    Color bgColor = Colors.grey[300]!;
                    Color textColor = Colors.black;

                    final bool isAnswered = _selectedAnswers.containsKey(
                      questionId,
                    );

                    if (isAnswered) {
                      bgColor = Colors.green;
                      textColor = Colors.white;
                    }

                    return GestureDetector(
                      onTap: () async {
                        final fullQuestionIndex = _questionIds.indexOf(
                          questionId,
                        );
                        if (fullQuestionIndex != -1) {
                          setState(() {
                            _selectedSection = null; // Reset the filter
                            _filterQuestionsBySection(); // Re-filter to show all questions
                            _currentQuestionIndex = fullQuestionIndex;
                            _pageController.jumpToPage(fullQuestionIndex);
                          });
                          Navigator.pop(context);
                          await _fetchQuestionData(questionId);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currentQuestionIndex == index
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.only(
                  top: 10.0,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _testSubmitted
                        ? null
                        : () {
                            Navigator.pop(context);
                            _confirmAndSubmitTest();
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16 + 2),
                    ),
                    child: const Text('Submit Test'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14 + 2),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questionIds.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No questions available for this test. Please contact admin.',
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Back button disabled.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            duration: const Duration(milliseconds: 800),
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
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Container(
                  color: Theme.of(context).primaryColor,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              widget.testTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Chip(
                            label: Text(
                              'Time left: ${_formatTime(_remainingSeconds)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: _remainingSeconds <= 60
                                ? Colors.redAccent
                                : Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8), // Add a small gap

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Question No. ${_currentQuestionIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              // Get the current question's section name, if available
                              if (_currentQuestionIndex <
                                  _filteredQuestionIds.length) ...[
                                const SizedBox(width: 8),
                                Builder(
                                  builder: (context) {
                                    final currentQuestionId =
                                        _filteredQuestionIds[_currentQuestionIndex];
                                    final questionData =
                                        _fetchedQuestionsData[currentQuestionId];
                                    final sectionName =
                                        questionData?['sectionName'] as String?;

                                    if (sectionName != null &&
                                        sectionName.isNotEmpty) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getColorForSection(
                                            sectionName,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          sectionName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ],
                          ),
                          Builder(
                            builder: (context) {
                              String marksText =
                                  'Marks: +${_marksPerQuestion.toStringAsFixed(1)}';
                              if (_isNegativeMarking &&
                                  _negativeMarksValue > 0) {
                                marksText +=
                                    ' | -${_negativeMarksValue.toStringAsFixed(2)}';
                              }
                              return Text(
                                marksText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _filteredQuestionIds.length,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) async {
                      setState(() {
                        _currentQuestionIndex = index;
                        // We get the section name of the current question for display
                        if (_currentQuestionIndex <
                            _filteredQuestionIds.length) {
                          final questionId =
                              _filteredQuestionIds[_currentQuestionIndex];
                          final questionData =
                              _fetchedQuestionsData[questionId];
                          _selectedSection =
                              questionData?['sectionName'] as String?;
                        }
                      });

                      // Pre-fetch data for the next question
                      if (index + 1 < _filteredQuestionIds.length) {
                        await _fetchQuestionData(
                          _filteredQuestionIds[index + 1],
                        );
                      }
                    },
                    itemBuilder: (context, index) {
                      final questionId = _filteredQuestionIds[index];
                      // MODIFIED: Check if question data is available in the cache.
                      final questionData = _fetchedQuestionsData[questionId];

                      // NEW: Display a loading indicator if question data is not yet available.
                      if (questionData == null) {
                        // NEW: Fetch data for the current question if not already in memory.
                        _fetchQuestionData(questionId);
                        return const Center(child: CircularProgressIndicator());
                      }

                      final options =
                          questionData['options'] as List<dynamic>? ?? [];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            QuestionContentWidget(
                              questionData: questionData,
                              questionNumber: index + 1,
                            ),
                            const SizedBox(height: 16),
                            ...options.asMap().entries.map((entry) {
                              final int optionIndex = entry.key;
                              final option = entry.value;
                              final String? optionImageUrl = option['imageUrl'];
                              final bool isOptionLatex =
                                  option['isLatexOption'] ?? false;
                              final String optionText =
                                  option['text'] ?? 'Option Text Missing';

                              Widget optionTextWidget;
                              if (isOptionLatex) {
                                optionTextWidget = Math.tex(
                                  optionText,
                                  textStyle: const TextStyle(fontSize: 17),
                                  onErrorFallback: (FlutterMathException e) =>
                                      Text(
                                        '$optionText (Math Error)',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          color: Colors.red,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.fade,
                                      ),
                                );
                              } else {
                                optionTextWidget = RichText(
                                  text: TextSpan(
                                    style: DefaultTextStyle.of(
                                      context,
                                    ).style.copyWith(fontSize: 12),
                                    children: formatTextWithBold(optionText),
                                  ),
                                );
                              }

                              if (isOptionLatex) {
                                optionTextWidget = SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: optionTextWidget,
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      listTileTheme: const ListTileThemeData(
                                        horizontalTitleGap: 2.0,
                                      ),
                                    ),
                                    child: RadioListTile<int>(
                                      title: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${String.fromCharCode(65 + optionIndex)}.',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(child: optionTextWidget),
                                        ],
                                      ),
                                      value: optionIndex,
                                      groupValue: _selectedAnswers[questionId],
                                      onChanged: _testSubmitted
                                          ? null
                                          : (value) => _onOptionSelected(
                                              questionId,
                                              value!,
                                            ),
                                      activeColor: Colors.blue,
                                    ),
                                  ),
                                  if (optionImageUrl != null &&
                                      optionImageUrl.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 32.0,
                                        bottom: 8.0,
                                      ),
                                      child: Image.network(
                                        optionImageUrl,
                                        height: 100,
                                        fit: BoxFit.contain,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Text(
                                                  'Error loading option image.',
                                                ),
                                      ),
                                    ),
                                  if (optionIndex < options.length - 1)
                                    const Divider(
                                      color: Colors.grey,
                                      thickness: 0.5,
                                      height: 16,
                                    ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 16.0,
                    bottom: 30.0 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(25.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _testSubmitted || _currentQuestionIndex == 0
                              ? null
                              : () {
                                  if (_pageController.hasClients &&
                                      _pageController.page! > 0) {
                                    _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                  setState(() {});
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 14 + 2),
                          ),
                          child: const Text('Previous'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testSubmitted
                              ? null
                              : _clearResponseForCurrentQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testSubmitted
                              ? null
                              : () {
                                  // Find the index of the current question in the master list.
                                  final currentQuestionId =
                                      _filteredQuestionIds[_currentQuestionIndex];
                                  final overallQuestionIndex = _questionIds
                                      .indexOf(currentQuestionId);

                                  if (overallQuestionIndex <
                                      _questionIds.length - 1) {
                                    // If there are more questions in the overall list, proceed to the next.
                                    // Reset the filter and animate to the next page.
                                    setState(() {
                                      _selectedSection = null;
                                      _filterQuestionsBySection();
                                    });

                                    _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  } else {
                                    // If this is the last question of the entire test, submit.
                                    _confirmAndSubmitTest();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _currentQuestionIndex == _questionIds.length - 1
                                ? Colors.green
                                : Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 14 + 2),
                          ),
                          child: Text(
                            // The button text now depends on whether we are at the end of the overall test.
                            _currentQuestionIndex == _questionIds.length - 1
                                ? 'Submit Test'
                                : 'Save & Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_sections.isNotEmpty)
              Positioned(
                bottom: 170 + MediaQuery.of(context).padding.bottom,
                right: 16,
                child: FloatingActionButton(
                  onPressed: _testSubmitted ? null : _showSectionSelector,
                  backgroundColor: Colors.blueAccent,
                  mini: true,
                  child: const Icon(Icons.sort, color: Colors.white, size: 22),
                ),
              ),
            Positioned(
              bottom: 120 + MediaQuery.of(context).padding.bottom,
              right: 16,
              child: FloatingActionButton(
                onPressed: _testSubmitted ? null : _showQuestionPalette,
                backgroundColor: Colors.green,
                mini: true,
                child: const Icon(
                  Icons.grid_on,
                  color: Colors.white,
                  size: 20 + 2,
                ),
              ),
            ),
            Positioned(
              top: 135,
              right: 17,
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black),
                onPressed: _isLoading || _testSubmitted
                    ? null
                    : _fetchQuestionsAndSession,
                tooltip: 'Refresh Test Data',
                iconSize: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
