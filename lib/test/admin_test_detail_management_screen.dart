// File: lib/screens/admin_test_detail_management_screen.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// --- Re-defining Constants for Test Details Dropdowns and new lists ---
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
const List<String> kTestTypes = [
  'Free',
  'Kadu Academy Student',
  'College Student',
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
// --- END NEW CONSTANTS ---

class AdminTestDetailManagementScreen extends StatefulWidget {
  final String testId;
  final Map<String, dynamic> initialTestData;

  const AdminTestDetailManagementScreen({
    super.key,
    required this.testId,
    required this.initialTestData,
  });

  @override
  State<AdminTestDetailManagementScreen> createState() =>
      _AdminTestDetailManagementScreenState();
}

class _AdminTestDetailManagementScreenState
    extends State<AdminTestDetailManagementScreen> {
  // Controllers for Test Details
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // --- NEW: Test Type and Multi-Select States ---
  String? _selectedTestType;
  List<String> _selectedKaduCourses = [];
  List<String> _selectedCollegeBranches = [];
  List<String> _selectedCollegeYears = [];

  // --- NEW: Marking Scheme States ---
  final TextEditingController _marksPerQuestionController =
      TextEditingController();
  bool _isNegativeMarking = false;
  final TextEditingController _negativeMarksValueController =
      TextEditingController();

  // --- NEW: Enable Option E Toggle State ---
  bool _enableOptionE = false; // Controls visibility of the 5th option
  // --- END NEW ---

  // --- NEW: Scheduling States ---
  Timestamp? _scheduledPublishTime;
  Timestamp? _globalExpiryTime;
  // --- END NEW ---

  // Controllers for Adding New Questions
  final TextEditingController _questionTextController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final List<bool> _isCorrectOption = [];
  int _numberOfOptions = 5; // Total possible options (A, B, C, D, E)

  final TextEditingController _questionOrderController =
      TextEditingController();

  final List<XFile?> _pickedOptionImageFiles = [];
  final List<String?> _uploadedOptionImageUrls = [];
  final List<bool> _isUploadingOptionImage = [];

  String? _editingQuestionId;

  XFile? _pickedImageFile;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  // NEW: LaTeX mode states
  bool _isQuestionLatexMode = false;
  List<bool> _isOptionLatexMode = [];

  // --- START MODIFIED: Image Placement and Text Part States ---
  bool _isImageAboveQuestion = false;
  bool _isImageInBetween = false;
  final TextEditingController _questionTextPart1Controller =
      TextEditingController();
  final TextEditingController _questionTextPart2Controller =
      TextEditingController();
  // --- END MODIFIED ---

  // New list to hold questions for reordering
  List<DocumentSnapshot> _reorderableQuestions = [];
  bool _isReordering = false;

  // Add this line inside your _AdminTestDetailManagementScreenState class
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize Test Details fields
    _titleController.text = widget.initialTestData['title'] ?? '';
    _descriptionController.text = widget.initialTestData['description'] ?? '';
    _durationController.text = (widget.initialTestData['durationMinutes'] ?? 0)
        .toString();
    _selectedTestType = null; // Default to null initially

    // Determine _selectedTestType based on existing boolean flags
    bool isFreeTest = widget.initialTestData['isFree'] ?? false;
    bool isPaidCollegeTest = widget.initialTestData['isPaidCollege'] ?? false;
    bool isPaidKaduAcademyTest =
        widget.initialTestData['isPaidKaduAcademy'] ?? false;

    if (isFreeTest) {
      _selectedTestType = 'Free';
    } else if (isPaidCollegeTest && isPaidKaduAcademyTest) {
      _selectedTestType = 'College Student';
    } else if (isPaidCollegeTest) {
      _selectedTestType = 'College Student';
    } else if (isPaidKaduAcademyTest) {
      _selectedTestType = 'Kadu Academy Student';
    }
    if (!(isFreeTest || isPaidCollegeTest || isPaidKaduAcademyTest)) {
      _selectedTestType = null;
    }
    _selectedKaduCourses = List<String>.from(
      widget.initialTestData['allowedCourses'] ?? [],
    );
    _selectedCollegeBranches = List<String>.from(
      widget.initialTestData['allowedBranches'] ?? [],
    );
    _selectedCollegeYears = List<String>.from(
      widget.initialTestData['allowedYears'] ?? [],
    );

    // --- NEW: Initialize Marking Scheme Fields ---
    _marksPerQuestionController.text =
        (widget.initialTestData['marksPerQuestion'] ?? 1.0).toString();
    _isNegativeMarking = widget.initialTestData['isNegativeMarking'] ?? false;
    _negativeMarksValueController.text =
        (widget.initialTestData['negativeMarksValue'] as num? ?? 0.0)
            .toString();

    // --- NEW: Initialize Enable Option E State ---
    _enableOptionE = widget.initialTestData['enableOptionE'] ?? true;

    // --- NEW: Initialize Scheduled Times from initial data ---
    _scheduledPublishTime = widget.initialTestData['scheduledPublishTime'];
    _globalExpiryTime = widget.initialTestData['globalExpiryTime'];

    _isQuestionLatexMode = false;
    _isOptionLatexMode = List.generate(_numberOfOptions, (index) => false);
    _initializeOptionFields();
    _setInitialQuestionOrder();
  }

  void _initializeOptionFields() {
    _optionControllers.clear();
    _isCorrectOption.clear();
    _pickedOptionImageFiles.clear();
    _uploadedOptionImageUrls.clear();
    _isUploadingOptionImage.clear();
    _isOptionLatexMode.clear();

    for (int i = 0; i < _numberOfOptions; i++) {
      _optionControllers.add(TextEditingController());
      _isCorrectOption.add(false);
      _pickedOptionImageFiles.add(null);
      _uploadedOptionImageUrls.add(null);
      _isUploadingOptionImage.add(false);
      _isOptionLatexMode.add(false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _marksPerQuestionController.dispose();
    _negativeMarksValueController.dispose();
    _questionTextController.dispose();
    _questionOrderController.dispose();
    // --- NEW: Dispose of the new controllers ---
    _questionTextPart1Controller.dispose();
    _questionTextPart2Controller.dispose();
    // --- END NEW ---
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    // NEW: Dispose the scroll controller
    _scrollController.dispose();
    super.dispose();
  }

  // --- Helper for SnackBar Styling ---
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

  // --- MODIFICATION: New function to set the default question order ---
  Future<void> _setInitialQuestionOrder() async {
    try {
      final questionsCollection = FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('questions');
      final querySnapshot = await questionsCollection.get();
      final currentCount = querySnapshot.docs.length;
      if (_editingQuestionId == null) {
        _questionOrderController.text = (currentCount + 1).toString();
      }
    } catch (e) {
      _showSnackBar('Failed to get question count: $e');
    }
  }

  // --- Image Picking, Cropping, Upload Logic for Question Image ---
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        _cropImage(pickedFile);
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _cropImage(XFile imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
          statusBarColor: Colors.transparent,
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _pickedImageFile = XFile(croppedFile.path);
        _uploadedImageUrl = null;
      });
      _uploadImageToFirebase();
    }
  }

  Future<void> _uploadImageToFirebase() async {
    if (_pickedImageFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final String fileName =
          'question_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = storageRef.putFile(File(_pickedImageFile!.path));

      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _uploadedImageUrl = downloadUrl;
        _isUploadingImage = false;
        _showSnackBar('Image uploaded successfully!');
      });
    } catch (e) {
      _showSnackBar('Failed to upload image: $e');
      setState(() {
        _isUploadingImage = false;
        _uploadedImageUrl = null;
      });
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _pickedImageFile = null;
      _uploadedImageUrl = null;
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickOptionImage(ImageSource source, int optionIndex) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        _cropOptionImage(pickedFile, optionIndex);
      }
    } catch (e) {
      _showSnackBar('Failed to pick option image: $e');
    }
  }

  Future<void> _cropOptionImage(XFile imageFile, int optionIndex) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Option Image',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
          statusBarColor: Colors.transparent,
        ),
        IOSUiSettings(
          title: 'Crop Option Image',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _pickedOptionImageFiles[optionIndex] = XFile(croppedFile.path);
        _uploadedOptionImageUrls[optionIndex] = null;
      });
      _uploadOptionImageToFirebase(optionIndex);
    }
  }

  Future<void> _uploadOptionImageToFirebase(int optionIndex) async {
    if (_pickedOptionImageFiles[optionIndex] == null) return;

    setState(() {
      _isUploadingOptionImage[optionIndex] = true;
    });

    try {
      final String fileName =
          'option_images/${DateTime.now().millisecondsSinceEpoch}_option$optionIndex.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = storageRef.putFile(
        File(_pickedOptionImageFiles[optionIndex]!.path),
      );

      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _uploadedOptionImageUrls[optionIndex] = downloadUrl;
        _isUploadingOptionImage[optionIndex] = false;
        _showSnackBar(
          'Option ${String.fromCharCode(65 + optionIndex)} image uploaded successfully!',
        );
      });
    } catch (e) {
      _showSnackBar('Option image upload failed: $e');
      setState(() {
        _isUploadingOptionImage[optionIndex] = false;
        _uploadedOptionImageUrls[optionIndex] = null;
      });
    }
  }

  void _clearSelectedOptionImage(int optionIndex) {
    setState(() {
      _pickedOptionImageFiles[optionIndex] = null;
      _uploadedOptionImageUrls[optionIndex] = null;
    });
  }

  void _showOptionImageSourceDialog(int optionIndex) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickOptionImage(ImageSource.gallery, optionIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickOptionImage(ImageSource.camera, optionIndex);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _parseOptionsFromText(String pastedText) {
    // Check if the pasted text actually contains newlines
    if (!pastedText.contains('\n')) {
      return; // If it's a single line, do nothing as per requirement
    }

    // Split the text by newline characters
    List<String> lines = pastedText.split('\n');

    // Update controllers and clear unused ones
    setState(() {
      // Clear all option fields first to ensure a clean slate for parsing
      for (int i = 0; i < _numberOfOptions; i++) {
        _optionControllers[i].clear();
        _isCorrectOption[i] = false;
        _pickedOptionImageFiles[i] = null;
        _uploadedOptionImageUrls[i] = null;
        _isUploadingOptionImage[i] = false;
        _isOptionLatexMode[i] = false; // Also reset LaTeX mode
      }

      // Populate option controllers with parsed lines
      for (int i = 0; i < lines.length && i < _numberOfOptions; i++) {
        // IMPORTANT: No .trim() here, as this is for populating the controller from multiline paste
        _optionControllers[i].text = lines[i];
      }

      _showSnackBar('Options parsed successfully!');
    });
  }

  // --- Test Details Management ---
  void _updateTestDetails() async {
    // MODIFIED: Removed .trim() to preserve internal spaces for title and description
    final String title = _titleController.text;
    final String description = _descriptionController.text;
    final int? duration = int.tryParse(
      _durationController.text.trim(),
    ); // trim for number input is fine

    // NEW VALIDATION: Ensure Test Type is selected
    if (_selectedTestType == null || _selectedTestType!.isEmpty) {
      _showSnackBar(
        'Please select Test Type (Free, Kadu Academy Student, or College Student).',
      );
      return;
    }

    if (title.isEmpty ||
        description.isEmpty ||
        duration == null ||
        duration <= 0) {
      _showSnackBar(
        'Please fill Test Title, Description, and Duration correctly.',
      );
      return;
    }

    if (_selectedTestType == 'Kadu Academy Student' &&
        _selectedKaduCourses.isEmpty) {
      _showSnackBar('Please select at least one course for Kadu Academy Test.');
      return;
    } else if (_selectedTestType == 'College Student') {
      if (_selectedCollegeBranches.isEmpty) {
        _showSnackBar('Please select at least one branch for College Test.');
        return;
      }
      if (_selectedCollegeYears.isEmpty) {
        _showSnackBar('Please select at least one year for College Test.');
        return;
      }
    }

    _showSnackBar('Updating test details...');

    try {
      final Map<String, dynamic> updateData = {
        'title': title,
        'description': description,
        'durationMinutes': duration,
        'marksPerQuestion':
            double.tryParse(_marksPerQuestionController.text) ?? 1.0,
        'isNegativeMarking': _isNegativeMarking,
        'negativeMarksValue': _isNegativeMarking
            ? (double.tryParse(_negativeMarksValueController.text) ?? 0.0)
            : 0.0,
        'enableOptionE': _enableOptionE,
        'updatedAt': Timestamp.now(),

        // --- NEW: Save the boolean flags based on selected test type ---
        'isFree': _selectedTestType == 'Free',
        'isPaidCollege': _selectedTestType == 'College Student',
        'isPaidKaduAcademy': _selectedTestType == 'Kadu Academy Student',
        // --- END NEW ---
      };

      if (_selectedTestType == 'Kadu Academy Student') {
        updateData['allowedCourses'] = _selectedKaduCourses;
        updateData['allowedBranches'] = [];
        updateData['allowedYears'] = [];
      } else if (_selectedTestType == 'College Student') {
        updateData['allowedBranches'] = _selectedCollegeBranches;
        updateData['allowedYears'] = _selectedCollegeYears;
        updateData['allowedCourses'] = [];
      } else {
        updateData['allowedCourses'] = [];
        updateData['allowedBranches'] = [];
        updateData['allowedYears'] = [];
      }

      await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .update(updateData);

      _showSnackBar('Test "$title" details updated!');
    } catch (e) {
      _showSnackBar('Failed to update test details: $e');
    }
  }

  // --- NEW: Function to schedule a test and send a notification ---
  Future<void> _scheduleTestAndNotify() async {
    // Check if test details are valid before scheduling
    final String title = _titleController.text;
    if (title.isEmpty) {
      _showSnackBar('Please fill in the test title first.');
      return;
    }

    final DateTime? scheduledDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (scheduledDate != null) {
      final TimeOfDay? scheduledTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (scheduledTime != null) {
        final DateTime scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );

        if (scheduledDateTime.isBefore(DateTime.now())) {
          _showSnackBar('Scheduled time must be in the future.');
          return;
        }

        _showSnackBar(
          'Scheduling test and sending notifications...',
          duration: 3,
        );

        try {
          // 1. Update Firestore to schedule the test
          await FirebaseFirestore.instance
              .collection('tests')
              .doc(widget.testId)
              .update({
                'isPublished': false,
                'scheduledPublishTime': Timestamp.fromDate(scheduledDateTime),
                'publishTime': null,
                'updatedAt': Timestamp.now(),
              });

          // 2. Call the new Cloud Function to send a notification
          final HttpsCallable callable = FirebaseFunctions.instance
              .httpsCallable('sendScheduledTestNotification');
          await callable.call({
            'testId': widget.testId,
            'testTitle': title,
            'scheduledTime': scheduledDateTime.toIso8601String(),
          });

          _showSnackBar('Test scheduled and notifications sent!', duration: 2);
        } catch (e) {
          _showSnackBar('Failed to schedule test or send notification: $e');
        }
      }
    }
  }
  // --- END NEW FUNCTION ---

  // --- Question Management ---
  void _addOrUpdateQuestion() async {
    // --- MODIFIED: Use new text part controllers ---
    final String questionTextPart1 = _questionTextPart1Controller.text;
    final String questionTextPart2 = _isImageInBetween
        ? _questionTextPart2Controller.text
        : '';
    final String questionText = _isImageInBetween
        ? '$questionTextPart1 $questionTextPart2'
        : questionTextPart1;
    // --- END MODIFIED ---
    String? finalImageUrl = _uploadedImageUrl;
    // --- START MODIFICATION: Get the order value ---
    final int? questionOrder = int.tryParse(
      _questionOrderController.text.trim(),
    );
    // --- END MODIFICATION ---

    // Question must have text OR image (cannot be empty)
    if (questionText.isEmpty && finalImageUrl == null) {
      _showSnackBar('Question must have text or an image.');
      return;
    }
    // --- START MODIFICATION: Add validation for the order number ---
    if (questionOrder == null || questionOrder <= 0) {
      _showSnackBar('Please enter a valid question number (positive integer).');
      return;
    }
    // --- END MODIFICATION ---

    List<Map<String, dynamic>> options = [];
    bool hasCorrectOption = false;

    // All 5 options are ALWAYS saved, even if text/image is empty.
    // The only compulsion is that *one* must be marked correct.
    for (int i = 0; i < _numberOfOptions; i++) {
      if (i == 4 && !_enableOptionE) {
        // If option E is disabled, skip saving it
        continue;
      }
      options.add({
        // MODIFIED: Removed .trim() to preserve internal spaces for option text
        'text': _optionControllers[i].text,
        'isCorrect': _isCorrectOption[i],
        'imageUrl': _uploadedOptionImageUrls[i],
        'isLatexOption':
            _isOptionLatexMode[i], // NEW: Save LaTeX mode for option
      });

      if (_isCorrectOption[i]) {
        hasCorrectOption = true;
      }
    }

    if (!hasCorrectOption) {
      _showSnackBar('Please select at least one correct option.');
      return;
    }

    _showSnackBar('Saving question...');

    try {
      CollectionReference questionsCollection = FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('questions');

      // --- START MODIFIED: Save new image placement and text part data ---
      final Map<String, dynamic> questionData = {
        'questionText': questionText,
        'questionTextPart1': questionTextPart1,
        'questionTextPart2': questionTextPart2,
        'isImageAboveQuestion': _isImageAboveQuestion,
        'isImageInBetween': _isImageInBetween,
        'options': options,
        'type': 'multiple_choice',
        'imageUrl': finalImageUrl,
        'isLatexQuestion': _isQuestionLatexMode,
        'order': questionOrder,
      };

      if (_editingQuestionId == null) {
        await questionsCollection.add({
          ...questionData,
          'createdAt': Timestamp.now(),
        });
        _showSnackBar('Question added successfully!');
      } else {
        await questionsCollection.doc(_editingQuestionId).update({
          ...questionData,
          'updatedAt': Timestamp.now(),
        });
        _showSnackBar('Question updated successfully!');
      }
      // --- END MODIFIED ---

      // START ADDITION: Update totalQuestions in the main test document
      // Fetch the current count of questions
      QuerySnapshot updatedQuestionsSnapshot = await questionsCollection.get();
      int newTotalQuestions = updatedQuestionsSnapshot.docs.length;

      // Update the parent test document
      await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .update({
            'totalQuestions': newTotalQuestions,
            'updatedAt': Timestamp.now(),
          });

      // END ADDITION

      _clearQuestionFields();
    } catch (e) {
      _showSnackBar('Failed to save/update question: $e');
    }
  }

  // --- MODIFICATION: Updated to be async to fetch the next order number ---
  Future<void> _clearQuestionFields() async {
    // --- MODIFIED: Clear new controllers ---
    _questionTextPart1Controller.clear();
    _questionTextPart2Controller.clear();
    // --- END MODIFIED ---
    _setInitialQuestionOrder();
    for (var controller in _optionControllers) {
      controller.clear();
    }
    _pickedOptionImageFiles.fillRange(0, _pickedOptionImageFiles.length, null);
    _uploadedOptionImageUrls.fillRange(
      0,
      _uploadedOptionImageUrls.length,
      null,
    );
    _isUploadingOptionImage.fillRange(0, _isUploadingOptionImage.length, false);

    setState(() {
      _isCorrectOption.fillRange(0, _isCorrectOption.length, false);
      _editingQuestionId = null;
      _clearSelectedImage();
      _isQuestionLatexMode = false; // Clear LaTeX mode for question
      _isOptionLatexMode.fillRange(
        0,
        _isOptionLatexMode.length,
        false,
      ); // Clear LaTeX mode for options
      // --- NEW: Reset image placement flags to default 'below' ---
      _isImageAboveQuestion = false;
      _isImageInBetween = false;
      // --- END NEW ---
    });
  }

  void _editQuestion(String questionId, Map<String, dynamic> questionData) {
    setState(() {
      _editingQuestionId = questionId;
      _questionOrderController.text =
          (questionData['order'] as int?)?.toString() ?? '';
      _isQuestionLatexMode = questionData['isLateexQuestion'] ?? false;
      // --- MODIFIED: Load the image placement flags from Firestore ---
      _isImageAboveQuestion = questionData['isImageAboveQuestion'] ?? false;
      _isImageInBetween = questionData['isImageInBetween'] ?? false;

      if (_isImageInBetween) {
        _questionTextPart1Controller.text =
            questionData['questionTextPart1'] ?? '';
        _questionTextPart2Controller.text =
            questionData['questionTextPart2'] ?? '';
      } else {
        _questionTextPart1Controller.text = questionData['questionText'] ?? '';
        _questionTextPart2Controller.text = ''; // Clear the second part
      }
      // --- END MODIFIED ---
      _clearSelectedImage();
      _uploadedImageUrl = questionData['imageUrl'];

      _optionControllers.clear();
      _isCorrectOption.clear();
      _pickedOptionImageFiles.clear();
      _uploadedOptionImageUrls.clear();
      _isUploadingOptionImage.clear();
      _isOptionLatexMode.clear(); // Clear this too

      List<dynamic> options = questionData['options'] ?? [];
      _numberOfOptions = math.max(5, options.length);
      _initializeOptionFields(); // Re-initialize fields including LaTeX modes

      for (int i = 0; i < options.length && i < _numberOfOptions; i++) {
        _optionControllers[i].text = options[i]['text'] ?? '';
        _isCorrectOption[i] = options[i]['isCorrect'] ?? false;
        _uploadedOptionImageUrls[i] = options[i]['imageUrl'];
        _isOptionLatexMode[i] =
            options[i]['isLatexOption'] ?? false; // Load LaTeX mode for option
      }
    });
    _showSnackBar('Editing existing question.');
  }

  // --- NEW: Helper function to handle database updates while preserving scroll position ---
  Future<void> _handleDatabaseUpdate(
    Future<void> Function() dbOperation,
  ) async {
    if (!_scrollController.hasClients) {
      // If the controller isn't attached yet, just run the operation
      return dbOperation();
    }

    final currentOffset = _scrollController.offset;

    await dbOperation();

    // Delay slightly to give the UI rebuild time to finish.
    await Future.delayed(const Duration(milliseconds: 100));

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(currentOffset);
    }
  }

  // NEW: Helper function to duplicate image by fetching and re-uploading it
  Future<String?> _duplicateImageAndGetUrl(String? sourceUrl) async {
    if (sourceUrl == null || sourceUrl.isEmpty) return null;
    try {
      final http.Response response = await http.get(Uri.parse(sourceUrl));
      final List<int> imageBytes = response.bodyBytes;
      final String fileName =
          'question_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = storageRef.putData(Uint8List.fromList(imageBytes));

      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _showSnackBar('Failed to duplicate image: $e');
      return null;
    }
  }

  // MODIFIED: This function now makes a true duplicate and re-indexes
  Future<void> _duplicateQuestion(DocumentSnapshot questionDocument) async {
    await _handleDatabaseUpdate(() async {
      _showSnackBar('Duplicating question...', duration: 2);
      try {
        Map<String, dynamic> questionData =
            questionDocument.data() as Map<String, dynamic>;

        // Duplicate the main question image
        if (questionData['imageUrl'] != null) {
          questionData['imageUrl'] = await _duplicateImageAndGetUrl(
            questionData['imageUrl'],
          );
        }

        // Duplicate images for all options
        List<dynamic> options = questionData['options'] ?? [];
        for (int i = 0; i < options.length; i++) {
          if (options[i]['imageUrl'] != null) {
            options[i]['imageUrl'] = await _duplicateImageAndGetUrl(
              options[i]['imageUrl'],
            );
          }
        }
        questionData['options'] = options;

        // Prepare for re-ordering
        final int oldOrder = questionData['order'] ?? 1;
        final int oldIndex = _reorderableQuestions.indexWhere(
          (doc) => doc.id == questionDocument.id,
        );

        // Create a new question document with the duplicated data
        final DocumentReference newQuestionRef = FirebaseFirestore.instance
            .collection('tests')
            .doc(widget.testId)
            .collection('questions')
            .doc();

        // Start a batch write to ensure all updates are atomic
        final WriteBatch batch = FirebaseFirestore.instance.batch();

        // Update the new question data and insert it
        final Map<String, dynamic> newQuestionData = Map.from(questionData);
        newQuestionData['order'] =
            oldOrder + 1; // Insert right after the original
        newQuestionData['createdAt'] = Timestamp.now();
        newQuestionData['updatedAt'] = Timestamp.now();

        batch.set(newQuestionRef, newQuestionData);

        // Increment the order of all subsequent questions
        for (int i = oldIndex + 1; i < _reorderableQuestions.length; i++) {
          final doc = _reorderableQuestions[i];
          final docRef = FirebaseFirestore.instance
              .collection('tests')
              .doc(widget.testId)
              .collection('questions')
              .doc(doc.id);
          batch.update(docRef, {'order': i + 2});
        }

        await batch.commit();

        _showSnackBar('Question duplicated successfully!');

        // Update the main test document's total question count
        await FirebaseFirestore.instance
            .collection('tests')
            .doc(widget.testId)
            .update({
              'totalQuestions': _reorderableQuestions.length + 1,
              'updatedAt': Timestamp.now(),
            });
      } catch (e) {
        _showSnackBar('Failed to duplicate question: $e');
        print('Duplication error: $e');
      }
    });
  }

  Future<void> _deleteQuestion(
    String questionId,
    String questionText,
    int questionOrder,
  ) async {
    // Truncate the question text for a cleaner confirmation modal
    final String truncatedText = questionText.length > 50
        ? '${questionText.substring(0, 50)}...'
        : questionText;

    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete this question?\n\n'
            'Question: "$truncatedText"',
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
    );

    if (confirmDelete == true) {
      // Handle database deletion logic
      // This part remains similar to your original code
      await _handleDatabaseUpdate(() async {
        _showSnackBar('Deleting question...', duration: 2);
        try {
          // Delete the question from Firestore
          await FirebaseFirestore.instance
              .collection('tests')
              .doc(widget.testId)
              .collection('questions')
              .doc(questionId)
              .delete();

          // Re-index remaining questions
          await _reorderQuestionsInFirestore();

          _showSnackBar('Question deleted successfully!');

          // Update totalQuestions count in the main test document
          CollectionReference questionsCollection = FirebaseFirestore.instance
              .collection('tests')
              .doc(widget.testId)
              .collection('questions');
          QuerySnapshot updatedQuestionsSnapshot = await questionsCollection
              .get();
          int newTotalQuestions = updatedQuestionsSnapshot.docs.length;

          await FirebaseFirestore.instance
              .collection('tests')
              .doc(widget.testId)
              .update({
                'totalQuestions': newTotalQuestions,
                'updatedAt': Timestamp.now(),
              });

          _clearQuestionFields();
        } catch (e) {
          _showSnackBar('Failed to delete question: $e');
        }
      });
    }
  }

  // --- START MODIFICATION: New method to handle drag-and-drop reordering ---
  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final DocumentSnapshot item = _reorderableQuestions.removeAt(oldIndex);
    _reorderableQuestions.insert(newIndex, item);

    // After reordering the local list, update the 'order' field in Firestore
    _reorderQuestionsInFirestore();
  }

  Future<void> _reorderQuestionsInFirestore() async {
    await _handleDatabaseUpdate(() async {
      setState(() {
        _isReordering = true;
      });
      _showSnackBar('Reordering questions...');

      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < _reorderableQuestions.length; i++) {
        final questionDocRef = FirebaseFirestore.instance
            .collection('tests')
            .doc(widget.testId)
            .collection('questions')
            .doc(_reorderableQuestions[i].id);

        batch.update(questionDocRef, {'order': i + 1});
      }

      try {
        await batch.commit();
        _showSnackBar('Question order updated successfully!');
      } catch (e) {
        _showSnackBar('Failed to update question order: $e');
      } finally {
        setState(() {
          _isReordering = false;
        });
      }
    });
  }
  // --- END MODIFICATION ---

  // --- START MODIFICATION: New function to handle manual reordering ---
  Future<void> _changeQuestionOrderManually(
    String questionId,
    int oldOrder,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: oldOrder.toString(),
    );

    final newOrderString = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Question Number'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'New Question Number',
              hintText:
                  'Enter a number between 1 and ${_reorderableQuestions.length}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );

    if (newOrderString != null && newOrderString.isNotEmpty) {
      final int? newOrder = int.tryParse(newOrderString);
      final int maxOrder = _reorderableQuestions.length;

      if (newOrder == null || newOrder < 1 || newOrder > maxOrder) {
        _showSnackBar(
          'Invalid question number. Must be between 1 and $maxOrder.',
        );
        return;
      }

      if (newOrder == oldOrder) return; // No change needed

      _showSnackBar('Renumbering questions...');

      final oldIndex = _reorderableQuestions.indexWhere(
        (doc) => doc.id == questionId,
      );
      final newIndex = newOrder - 1;

      final draggedDoc = _reorderableQuestions.removeAt(oldIndex);
      _reorderableQuestions.insert(newIndex, draggedDoc);

      await _reorderQuestionsInFirestore();
    }
  }
  // --- END MODIFICATION ---

  // Helper to format text with **bold** syntax
  Widget _formatTextWithBold(String text, {Color? color}) {
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
    return RichText(text: TextSpan(children: spans));
  }

  // This helper is for the main question text which has a different base style
  Widget _formatQuestionText(String text, int order, {bool isPart1 = true}) {
    final List<TextSpan> spans = [];
    final parts = text.split('*');
    if (isPart1) {
      spans.add(
        TextSpan(
          text: '$order. ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color.fromARGB(255, 49, 49, 49),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(255, 49, 49, 49),
            ),
          ),
        );
      }
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingQuestionId == null
              ? 'Manage Test Details & Questions'
              : 'Edit Question',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Test Details Section ---
                const Text(
                  'Test Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Test Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                // --- Test Type Selection (NEW) ---
                DropdownButtonFormField<String>(
                  value: _selectedTestType,
                  decoration: const InputDecoration(
                    labelText: 'Test Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  hint: const Text('Select Test Type'),
                  items: kTestTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTestType = newValue;
                      // Clear selections for other types when one is chosen
                      _selectedKaduCourses.clear();
                      _selectedCollegeBranches.clear();
                      _selectedCollegeYears.clear();
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select Test Type' : null,
                ),
                const SizedBox(height: 20),
                // --- Conditional Sections based on Test Type ---
                // Kadu Academy Test Fields
                Visibility(
                  visible: _selectedTestType == 'Kadu Academy Student',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Courses (Kadu Academy):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...kKaduCourses.map((course) {
                        return CheckboxListTile(
                          title: Text(
                            course,
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _selectedKaduCourses.contains(course),
                          onChanged: (bool? newValue) {
                            setState(() {
                              if (newValue == true) {
                                _selectedKaduCourses.add(course);
                              } else {
                                _selectedKaduCourses.remove(course);
                              }
                            });
                          },
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // College Student Test Fields
                Visibility(
                  visible: _selectedTestType == 'College Student',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Branches (College):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...kBranches.map((branch) {
                        return CheckboxListTile(
                          title: Text(
                            branch,
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _selectedCollegeBranches.contains(branch),
                          onChanged: (bool? newValue) {
                            setState(() {
                              if (newValue == true) {
                                _selectedCollegeBranches.add(branch);
                              } else {
                                _selectedCollegeBranches.remove(branch);
                              }
                            });
                          },
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Years (College):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...kYears.map((year) {
                        return CheckboxListTile(
                          title: Text(
                            year,
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _selectedCollegeYears.contains(year),
                          onChanged: (bool? newValue) {
                            setState(() {
                              if (newValue == true) {
                                _selectedCollegeYears.add(year);
                              } else {
                                _selectedCollegeYears.remove(year);
                              }
                            });
                          },
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // --- Marking Scheme (NEW) ---
                const Text(
                  'Marking Scheme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _marksPerQuestionController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Marks Per Question (Default: 1)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                CheckboxListTile(
                  title: const Text(
                    'Enable Negative Marking',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: _isNegativeMarking,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _isNegativeMarking = newValue ?? false;
                    });
                  },
                ),
                Visibility(
                  visible: _isNegativeMarking,
                  child: TextField(
                    controller: _negativeMarksValueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Negative Marks Value (e.g., 0.25)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                // --- NEW: Enable Option E Toggle ---
                CheckboxListTile(
                  title: const Text(
                    'Enable Option E (5th option)',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: _enableOptionE,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _enableOptionE = newValue ?? false;
                      // Clear Option E's content if disabled
                      if (!_enableOptionE) {
                        _optionControllers[4].clear(); // Option E is at index 4
                        _pickedOptionImageFiles[4] = null;
                        _uploadedOptionImageUrls[4] = null;
                        _isCorrectOption[4] = false;
                        _isOptionLatexMode[4] =
                            false; // Clear its LaTeX mode too
                      }
                    });
                  },
                ),
                // --- END NEW ---
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _updateTestDetails,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Save Test Details',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 40),

                // --- Add/Edit Question Section (Existing) ---
                Text(
                  _editingQuestionId == null
                      ? 'Add New Question'
                      : 'Edit Question',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // --- MODIFIED: Dropdown for image placement ---
                DropdownButtonFormField<String>(
                  value: _isImageAboveQuestion
                      ? 'above'
                      : (_isImageInBetween ? 'inBetween' : 'below'),
                  decoration: const InputDecoration(
                    labelText: 'Question Image Placement',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'below', child: Text('Below Text')),
                    DropdownMenuItem(value: 'above', child: Text('Above Text')),
                    DropdownMenuItem(
                      value: 'inBetween',
                      child: Text('In-Between Text'),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _isImageAboveQuestion = newValue == 'above';
                      _isImageInBetween = newValue == 'inBetween';
                    });
                  },
                ),
                const SizedBox(height: 20),
                // --- END MODIFIED ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 1, // Allocate a smaller space for the order field
                      child: TextField(
                        controller: _questionOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Q. No.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3, // Allocate more space for the question text
                      child: TextField(
                        controller: _questionTextPart1Controller,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          labelText: 'Question Text (Part 1)',
                          border: OutlineInputBorder(),
                        ),
                        // Retain the existing multi-line paste functionality
                        onChanged: (text) {
                          if (text.contains('\n')) {
                            _parseOptionsFromText(text);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Retain the image and LaTeX buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('LaTeX', style: TextStyle(fontSize: 12)),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _isQuestionLatexMode,
                                onChanged: (bool value) {
                                  setState(() {
                                    _isQuestionLatexMode = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 30,
                          ),
                          onPressed: _showImageSourceDialog,
                          tooltip: 'Add Image to Question',
                        ),
                      ],
                    ),
                  ],
                ),
                // --- NEW: Second text field for 'in-between' image placement ---
                if (_isImageInBetween)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: TextField(
                      controller: _questionTextPart2Controller,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'Question Text (Part 2)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                // --- END NEW ---
                const SizedBox(
                  height: 5,
                ), // Small gap before LaTeX formula buttons
                Visibility(
                  visible: _isQuestionLatexMode,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                      bottom: 10.0,
                    ), // Added padding for buttons
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _questionTextPart1Controller.text +=
                                r'\frac{numerator}{denominator}';
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: const Text(
                            r'\frac',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _questionTextPart1Controller.text +=
                                r'\sum_{lower}^{upper}';
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: const Text(
                            r'\sum',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _questionTextPart1Controller.text += r'\sqrt{}';
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: const Text(
                            r'\sqrt',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _questionTextPart1Controller.text += r'\text{}';
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: const Text(
                            r'\text{}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _questionTextPart1Controller.text +=
                                r'\int_{lower}^{upper}';
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: const Text(
                            r'\int',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _questionTextPart1Controller.text += r'\alpha';
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: const Text(
                            r'\alpha',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isUploadingImage)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(),
                  ),
                if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Image.network(
                      _uploadedImageUrl!,
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Text('Invalid Image URL or network error.'),
                    ),
                  ),
                if ((_pickedImageFile != null || _uploadedImageUrl != null) &&
                    !_isUploadingImage)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearSelectedImage,
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.red,
                        size: 20,
                      ),
                      label: const Text(
                        'Clear Question Image',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Options for the Question (Input Fields)
                ...List.generate(_numberOfOptions, (index) {
                  if (index == 4 && !_enableOptionE) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[index],
                                maxLines: null,
                                decoration: InputDecoration(
                                  labelText: index == 4
                                      ? 'Option E Text (OPTIONAL)'
                                      : 'Option ${String.fromCharCode(65 + index)} Text',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (text) {
                                  if (index == 0 && text.contains('\n')) {
                                    _parseOptionsFromText(text);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'LaTeX',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    Transform.scale(
                                      scale: 0.7,
                                      child: Switch(
                                        value: _isOptionLatexMode[index],
                                        onChanged: (bool value) {
                                          setState(() {
                                            _isOptionLatexMode[index] = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 25,
                                  ),
                                  onPressed: () =>
                                      _showOptionImageSourceDialog(index),
                                  tooltip:
                                      'Add Image to Option ${String.fromCharCode(65 + index)}',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Visibility(
                          visible: _isOptionLatexMode[index],
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    _optionControllers[index].text +=
                                        r'\frac{numerator}{denominator}';
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    r'\frac',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _optionControllers[index].text +=
                                        r'\sum_{lower}^{upper}';
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    r'\sum',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _optionControllers[index].text +=
                                        r'\sqrt{}';
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    r'\sqrt',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _optionControllers[index].text +=
                                        r'\text{}';
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    r'\text{}',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _optionControllers[index].text +=
                                        r'\int_{lower}^{upper}';
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    r'\int',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _optionControllers[index].text += r'\alpha';
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    r'\alpha',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isUploadingOptionImage[index])
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(),
                          ),
                        if (_pickedOptionImageFiles[index] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Image.file(
                              File(_pickedOptionImageFiles[index]!.path),
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          )
                        else if (_uploadedOptionImageUrls[index] != null &&
                            _uploadedOptionImageUrls[index]!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Image.network(
                              _uploadedOptionImageUrls[index]!,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text('Error loading option image'),
                            ),
                          ),
                        if ((_pickedOptionImageFiles[index] != null ||
                                _uploadedOptionImageUrls[index] != null) &&
                            !_isUploadingOptionImage[index])
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _clearSelectedOptionImage(index),
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.red,
                                size: 18,
                              ),
                              label: Text(
                                'Clear Option ${String.fromCharCode(65 + index)} Image',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _isCorrectOption[index],
                                onChanged: (bool? value) {
                                  setState(() {
                                    for (
                                      int i = 0;
                                      i < _isCorrectOption.length;
                                      i++
                                    ) {
                                      _isCorrectOption[i] = (i == index)
                                          ? value!
                                          : false;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 1),
                            const Text(
                              'Correct',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _addOrUpdateQuestion,
                  icon: Icon(
                    _editingQuestionId == null ? Icons.add : Icons.save,
                  ),
                  label: Text(
                    _editingQuestionId == null
                        ? 'Add Question'
                        : 'Update Question',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
                if (_editingQuestionId != null)
                  TextButton(
                    onPressed: _clearQuestionFields,
                    child: const Text(
                      'Cancel Edit',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 40),

                // Existing Questions List Section
                const Text(
                  'Existing Questions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tests')
                      .doc(widget.testId)
                      .collection('questions')
                      .orderBy('order', descending: false)
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
                        child: Text('No questions added yet.'),
                      );
                    }
                    _reorderableQuestions = snapshot.data!.docs;
                    return ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reorderableQuestions.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        DocumentSnapshot questionDocument =
                            _reorderableQuestions[index];
                        Map<String, dynamic> questionData =
                            questionDocument.data() as Map<String, dynamic>;

                        String questionId = questionDocument.id;
                        List<dynamic> options = questionData['options'] ?? [];
                        int questionOrder = questionData['order'] ?? index + 1;

                        String questionTextPart1 =
                            questionData['questionTextPart1'] ??
                            questionData['questionText'] ??
                            '';
                        String questionTextPart2 =
                            questionData['questionTextPart2'] ?? '';
                        bool isImageInBetween =
                            questionData['isImageInBetween'] ?? false;
                        bool isImageAboveQuestion =
                            questionData['isImageAboveQuestion'] ?? false;
                        String? questionImageUrl = questionData['imageUrl'];
                        bool isQuestionLatex =
                            questionData['isLatexQuestion'] ?? false;

                        List<Widget> questionContent = [];

                        if (isImageAboveQuestion && questionImageUrl != null) {
                          questionContent.add(
                            Image.network(
                              questionImageUrl,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text('Error loading image'),
                            ),
                          );
                        }

                        questionContent.add(
                          Padding(
                            padding: EdgeInsets.only(
                              top:
                                  isImageAboveQuestion &&
                                      questionImageUrl != null
                                  ? 8.0
                                  : 0.0,
                            ),
                            child: isQuestionLatex
                                ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Math.tex(
                                      '$questionOrder. $questionTextPart1',
                                      textStyle: const TextStyle(fontSize: 16),
                                    ),
                                  )
                                : _formatQuestionText(
                                    questionTextPart1,
                                    questionOrder,
                                  ),
                          ),
                        );

                        if (isImageInBetween) {
                          if (questionImageUrl != null) {
                            questionContent.add(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Image.network(
                                  questionImageUrl,
                                  height: 100,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Text('Error loading image'),
                                ),
                              ),
                            );
                          }
                          questionContent.add(
                            isQuestionLatex
                                ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Math.tex(
                                      questionTextPart2,
                                      textStyle: const TextStyle(fontSize: 16),
                                    ),
                                  )
                                : _formatQuestionText(
                                    questionTextPart2,
                                    0,
                                    isPart1: false,
                                  ),
                          );
                        }

                        if (!isImageAboveQuestion &&
                            !isImageInBetween &&
                            questionImageUrl != null) {
                          questionContent.add(
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Image.network(
                                questionImageUrl,
                                height: 100,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text('Error loading image'),
                              ),
                            ),
                          );
                        }

                        return Card(
                          key: ValueKey(questionId),
                          margin: const EdgeInsets.only(bottom: 10.0),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...questionContent,
                                const SizedBox(height: 10),
                                ...options.asMap().entries.map((entry) {
                                  int optionIndex = entry.key;
                                  Map<String, dynamic> option = entry.value;
                                  String optionText = option['text'] ?? '';
                                  bool isCorrect = option['isCorrect'] ?? false;
                                  String? optionImageUrl = option['imageUrl'];
                                  bool isOptionLatex =
                                      option['isLatexOption'] ?? false;

                                  if (optionIndex == 4 &&
                                      !widget
                                          .initialTestData['enableOptionE']) {
                                    return const SizedBox.shrink();
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${String.fromCharCode(65 + optionIndex)}. ',
                                            style: TextStyle(
                                              color: isCorrect
                                                  ? Colors.green
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: isOptionLatex
                                                ? SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Math.tex(
                                                      optionText,
                                                      textStyle: TextStyle(
                                                        color: isCorrect
                                                            ? Colors.green
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                  )
                                                : _formatTextWithBold(
                                                    optionText,
                                                    color: isCorrect
                                                        ? Colors.green
                                                        : Colors.black,
                                                  ),
                                          ),
                                        ],
                                      ),
                                      if (optionImageUrl != null &&
                                          optionImageUrl.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                          child: Image.network(
                                            optionImageUrl,
                                            height: 80,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => const Text(
                                                  'Error loading option image',
                                                ),
                                          ),
                                        ),
                                    ],
                                  );
                                }).toList(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _changeQuestionOrderManually(
                                            questionId,
                                            questionOrder,
                                          ),
                                      icon: const Icon(Icons.swap_vert),
                                      tooltip: 'Change order manually',
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () =>
                                          _duplicateQuestion(questionDocument),
                                      child: const Text(
                                        'Duplicate',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _editQuestion(
                                        questionId,
                                        questionData,
                                      ),
                                      child: const Text(
                                        'Edit',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _deleteQuestion(
                                        questionId,
                                        questionData['questionText'] ??
                                            'No Question Text',
                                        questionOrder,
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(fontSize: 12),
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

                // ... (code below)
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.done_all),
                  label: const Text(
                    'Finish Adding Questions',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
