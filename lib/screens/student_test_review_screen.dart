// File: lib/screens/student_test_review_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // For fetching image data from network
import 'dart:typed_data'; // For Uint8List
import 'package:flutter_math_fork/flutter_math.dart'; // Import for LaTeX rendering
import 'package:kadu_academy_app/utils/firestore_extensions.dart'; // Assuming this import is correct and necessary
import 'package:kadu_academy_app/utils/text_formatter.dart'; // NEW: Import the text formatter utility

class StudentTestReviewScreen extends StatefulWidget {
  final String testId;
  final String testTitle;
  final String
  studentId; // ADDED: Student ID is crucial for fetching their session

  const StudentTestReviewScreen({
    super.key,
    required this.testId,
    required this.testTitle,
    required this.studentId, // ADDED
  });

  @override
  State<StudentTestReviewScreen> createState() =>
      _StudentTestReviewScreenState();
}

class _StudentTestReviewScreenState extends State<StudentTestReviewScreen> {
  // Cache for fetched image bytes to avoid re-fetching the same image
  final Map<String, Uint8List> _imageBytesCache = {};
  Map<String, dynamic> _studentAnswers = {}; // To store answers from session
  bool _isLoadingSession = true; // To track session loading

  @override
  void initState() {
    super.initState();
    _fetchStudentSession(); // Call to fetch student session data
  }

  // Helper to fetch image bytes from URL
  Future<Uint8List?> _fetchImageBytes(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (_imageBytesCache.containsKey(imageUrl)) {
      return _imageBytesCache[imageUrl];
    }
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        _imageBytesCache[imageUrl] = response.bodyBytes; // Cache the bytes
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Helper method to fetch student session data
  Future<void> _fetchStudentSession() async {
    try {
      final String currentStudentId = widget.studentId;
      final String currentTestId = widget.testId;

      final QuerySnapshot sessionSnapshot = await FirebaseFirestore.instance
          .collection('studentTestSessions')
          .where('studentId', isEqualTo: currentStudentId)
          .where('testId', isEqualTo: currentTestId)
          .where(
            'status',
            isEqualTo: 'completed',
          ) // Only completed sessions for review
          .limit(1) // Assuming one completed session per test per student
          .get();

      if (sessionSnapshot.docs.isNotEmpty) {
        setState(() {
          _studentAnswers = sessionSnapshot.docs.first['answers'] ?? {};
          _isLoadingSession = false;
        });
      } else {
        setState(() {
          _isLoadingSession = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No completed test session found to review.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2), // Shorter duration
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingSession = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading review data: $e')),
        );
      }
    }
  }

  // This helper formats plain text with *bold* formatting
  List<TextSpan> _formatTextWithBold(String text, {required Color color}) {
    final List<TextSpan> spans = [];
    final parts = text.split('*');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(color: color),
          ),
        );
      }
    }
    return spans;
  }

  // Helper to build the correctness label box
  Widget _buildCorrectnessLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0), // Cute rounded box
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8, // Reduced from 10 to 8
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review: ${widget.testTitle}',
          style: const TextStyle(fontSize: 14), // Reduced from 16 to 14
        ),
        centerTitle: true,
      ),
      body:
          _isLoadingSession // Check if session data is loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tests')
                  .doc(widget.testId)
                  .collection('questions')
                  .orderBy(
                    'order',
                    descending: false,
                  ) // Order questions consistently
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
                    child: Text('No questions found for this test review.'),
                  );
                }

                final List<DocumentSnapshot> questions = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> questionData =
                        questions[index].data() as Map<String, dynamic>;
                    String questionId = questions[index].id; // Get question ID
                    String questionText = questionData['questionText'] ?? 'N/A';
                    List<dynamic> options = questionData['options'] ?? [];
                    String? imageUrl = questionData['imageUrl'];
                    bool isQuestionLatex =
                        questionData['isLatexQuestion'] ??
                        false; // NEW: Get LaTeX flag for question

                    // Get image placement details
                    final bool isImageAboveQuestion =
                        questionData['isImageAboveQuestion'] ?? false;
                    final bool isImageInBetween =
                        questionData['isImageInBetween'] ?? false;
                    final String questionTextPart1 =
                        questionData['questionTextPart1'] ?? questionText;
                    final String questionTextPart2 =
                        questionData['questionTextPart2'] ?? '';

                    // Get student's selected answer for this question
                    final int? studentSelectedOptionIndex =
                        _studentAnswers[questionId];
                    // Find the actual correct option index
                    int? correctOptionIndex;
                    for (int i = 0; i < options.length; i++) {
                      if (options[i]['isCorrect'] == true) {
                        correctOptionIndex = i;
                        break;
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(
                        bottom: 12.0,
                      ), // Reduced from 16 to 12
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          12.0,
                        ), // Reduced from 16 to 12
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- START MODIFICATION FOR QUESTION TEXT RENDERING ---
                            if (isImageAboveQuestion &&
                                imageUrl != null &&
                                imageUrl.isNotEmpty)
                              FutureBuilder<Uint8List?>(
                                future: _fetchImageBytes(imageUrl),
                                builder: (context, imageSnapshot) {
                                  if (imageSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (imageSnapshot.hasError ||
                                      imageSnapshot.data == null) {
                                    return const Text('Image failed to load.');
                                  }
                                  return Image.memory(
                                    imageSnapshot.data!,
                                    height: 120,
                                    fit: BoxFit.contain,
                                  );
                                },
                              ),

                            Text(
                              'Question ${index + 1}:',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            isQuestionLatex
                                ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Math.tex(
                                      questionTextPart1,
                                      textStyle: const TextStyle(fontSize: 14),
                                    ),
                                  )
                                : RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(
                                        context,
                                      ).style.copyWith(fontSize: 14),
                                      children: _formatTextWithBold(
                                        questionTextPart1,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),

                            if (isImageInBetween) ...[
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                FutureBuilder<Uint8List?>(
                                  future: _fetchImageBytes(imageUrl),
                                  builder: (context, imageSnapshot) {
                                    if (imageSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (imageSnapshot.hasError ||
                                        imageSnapshot.data == null) {
                                      return const Text(
                                        'Image failed to load.',
                                      );
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Image.memory(
                                        imageSnapshot.data!,
                                        height: 120,
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  },
                                ),
                              isQuestionLatex
                                  ? SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Math.tex(
                                        questionTextPart2,
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : RichText(
                                      text: TextSpan(
                                        style: DefaultTextStyle.of(
                                          context,
                                        ).style.copyWith(fontSize: 14),
                                        children: _formatTextWithBold(
                                          questionTextPart2,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                            ],

                            if (!isImageAboveQuestion &&
                                !isImageInBetween &&
                                imageUrl != null &&
                                imageUrl.isNotEmpty)
                              FutureBuilder<Uint8List?>(
                                future: _fetchImageBytes(imageUrl),
                                builder: (context, imageSnapshot) {
                                  if (imageSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (imageSnapshot.hasError ||
                                      imageSnapshot.data == null) {
                                    return const Text('Image failed to load.');
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Image.memory(
                                      imageSnapshot.data!,
                                      height: 120,
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 12), // Reduced from 16 to 12
                            // Display options, highlighting correct ones and student's choice
                            ...options.asMap().entries.map((entry) {
                              int optionIndex = entry.key;
                              Map<String, dynamic> option = entry.value;
                              bool isCorrectOption =
                                  option['isCorrect'] ?? false;
                              bool isOptionLatex =
                                  option['isLatexOption'] ??
                                  false; // NEW: Get LaTeX flag for option

                              // Determine if this option was chosen by the student
                              bool isStudentChosen =
                                  studentSelectedOptionIndex == optionIndex;

                              // Determine the background color and border for the option container
                              Color containerBgColor = Colors.transparent;
                              Color containerBorderColor = Colors.transparent;

                              if (isStudentChosen) {
                                if (isCorrectOption) {
                                  containerBgColor = Colors.green.withOpacity(
                                    0.1,
                                  ); // Faint green
                                  containerBorderColor = Colors.green
                                      .withOpacity(0.5);
                                } else {
                                  containerBgColor = Colors.red.withOpacity(
                                    0.1,
                                  ); // Faint red
                                  containerBorderColor = Colors.red.withOpacity(
                                    0.5,
                                  );
                                }
                              } else if (isCorrectOption) {
                                // This is the correct option, but student did not choose it
                                containerBgColor = Colors.blue.withOpacity(
                                  0.05,
                                ); // Faint blue for correct unchosen
                                containerBorderColor = Colors.blue.withOpacity(
                                  0.3,
                                );
                              }

                              // Determine the icon and text color for the option text itself
                              Color optionTextColor = Colors.black87;
                              IconData optionIcon =
                                  Icons.radio_button_off; // Default icon

                              String correctnessLabelText =
                                  ''; // Text for the cute box label
                              Color correctnessLabelColor = Colors
                                  .transparent; // Color for the cute box label

                              if (isStudentChosen) {
                                if (isCorrectOption) {
                                  optionIcon = Icons.check_circle;
                                  optionTextColor = Colors.green[700]!;
                                  correctnessLabelText = 'Your Correct';
                                  correctnessLabelColor = Colors.green;
                                } else {
                                  optionIcon = Icons.cancel;
                                  optionTextColor = Colors.red[700]!;
                                  correctnessLabelText = 'Your Wrong';
                                  correctnessLabelColor = Colors.red;
                                }
                              } else if (isCorrectOption) {
                                // This is the correct option, but student did not choose it
                                optionIcon = Icons
                                    .check_circle_outline; // Outline checkmark for correct but unchosen
                                optionTextColor = Colors.blue[700]!;
                                correctnessLabelText =
                                    'Correct Answer'; // Changed label for clarity
                                correctnessLabelColor = Colors.blue;
                              }

                              return Container(
                                // Wrap option content in a Container for background and border
                                margin: const EdgeInsets.symmetric(
                                  vertical: 3.0,
                                ), // Reduced from 4 to 3
                                decoration: BoxDecoration(
                                  color: containerBgColor,
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: containerBorderColor,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  // Inner padding for the option content
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 6.0,
                                  ), // Reduced from 16/8 to 12/6
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            optionIcon, // Dynamically chosen icon
                                            color:
                                                optionTextColor, // Icon color matches text color
                                            size: 16, // Reduced from 18 to 16
                                          ),
                                          const SizedBox(
                                            width: 6,
                                          ), // Reduced from 8 to 6
                                          Expanded(
                                            // --- START MODIFICATION FOR OPTION TEXT RENDERING ---
                                            child: Row(
                                              // Use a Row for the option letter and content for better alignment
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Option letter (A., B., etc.)
                                                Text(
                                                  '${String.fromCharCode(65 + optionIndex)}.',
                                                  style: TextStyle(
                                                    fontSize:
                                                        14, // Consistent font size
                                                    color: optionTextColor,
                                                    fontWeight:
                                                        (isStudentChosen ||
                                                            isCorrectOption)
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 4,
                                                ), // Small space after the letter

                                                Flexible(
                                                  // Flexible to allow text/Math.tex to wrap and take available space
                                                  child: isOptionLatex
                                                      ? SingleChildScrollView(
                                                          // For horizontal overflow of Math.tex
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          child: Math.tex(
                                                            option['text'] ??
                                                                'N/A', // Only the text content
                                                            textStyle: TextStyle(
                                                              fontSize:
                                                                  14, // Reduced from 16 to 14
                                                              fontWeight:
                                                                  (isStudentChosen ||
                                                                      isCorrectOption)
                                                                  ? FontWeight
                                                                        .bold
                                                                  : FontWeight
                                                                        .normal,
                                                              color:
                                                                  optionTextColor,
                                                            ),
                                                            onErrorFallback:
                                                                (
                                                                  FlutterMathException
                                                                  e,
                                                                ) {
                                                                  return Text(
                                                                    '${option['text'] ?? 'N/A'} (LaTeX Error)',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14, // Reduced from 16 to 14
                                                                      fontWeight:
                                                                          (isStudentChosen ||
                                                                              isCorrectOption)
                                                                          ? FontWeight.bold
                                                                          : FontWeight.normal,
                                                                      color: Colors
                                                                          .red, // Error color
                                                                    ),
                                                                    softWrap:
                                                                        true,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .fade,
                                                                  );
                                                                },
                                                          ),
                                                        )
                                                      : Text(
                                                          option['text'] ??
                                                              'N/A', // Only the text content
                                                          style: TextStyle(
                                                            fontSize:
                                                                14, // Reduced from 16 to 14
                                                            fontWeight:
                                                                (isStudentChosen ||
                                                                    isCorrectOption)
                                                                ? FontWeight
                                                                      .bold
                                                                : FontWeight
                                                                      .normal,
                                                            color:
                                                                optionTextColor,
                                                          ),
                                                          softWrap: true,
                                                          overflow: TextOverflow
                                                              .visible,
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Add the correctness label here (cute box)
                                          if (correctnessLabelText.isNotEmpty)
                                            _buildCorrectnessLabel(
                                              correctnessLabelText,
                                              correctnessLabelColor,
                                            ),
                                        ],
                                      ),
                                      // Option Image (if available)
                                      if (option['imageUrl'] != null &&
                                          option['imageUrl'].isNotEmpty)
                                        FutureBuilder<Uint8List?>(
                                          future: _fetchImageBytes(
                                            option['imageUrl'],
                                          ),
                                          builder: (context, optionImageSnapshot) {
                                            if (optionImageSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                              return const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 32.0,
                                                  top: 8.0,
                                                  bottom: 4.0,
                                                ),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                    ),
                                              );
                                            }
                                            if (optionImageSnapshot.hasError ||
                                                optionImageSnapshot.data ==
                                                    null) {
                                              return const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 32.0,
                                                  top: 8.0,
                                                  bottom: 4.0,
                                                ),
                                                child: Text(
                                                  'Option image failed to load.',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 9,
                                                  ),
                                                ), // Reduced from 11 to 9
                                              );
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                left: 32.0,
                                                top: 8.0,
                                                bottom: 4.0,
                                              ),
                                              child: Image.memory(
                                                optionImageSnapshot.data!,
                                                height:
                                                    70, // Reduced from 80 to 70
                                                fit: BoxFit.contain,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
