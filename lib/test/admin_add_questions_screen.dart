import 'dart:io'; // For File operations

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:image_cropper/image_cropper.dart'; // For cropping images
import 'package:image_picker/image_picker.dart';

// We'll import admin_edit_question_screen.dart here later

class AdminAddQuestionsScreen extends StatefulWidget {
  final String testId; // The ID of the test to which questions will be added

  const AdminAddQuestionsScreen({super.key, required this.testId});

  @override
  State<AdminAddQuestionsScreen> createState() =>
      _AdminAddQuestionsScreenState();
}

class _AdminAddQuestionsScreenState extends State<AdminAddQuestionsScreen> {
  final TextEditingController _questionTextController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final List<bool> _isCorrectOption = []; // To track which option is correct
  int _numberOfOptions = 4; // Default to 4 options per question

  // --- NEW: Image related state variables ---
  XFile? _pickedImageFile; // Stores the image picked from gallery/camera
  final TextEditingController _imageUrlController =
      TextEditingController(); // For direct image URL input
  String? _uploadedImageUrl; // Stores the URL after Firebase Storage upload
  bool _isUploadingImage = false; // To show upload progress
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    _initializeOptionFields();
  }

  void _initializeOptionFields() {
    _optionControllers.clear();
    _isCorrectOption.clear();
    for (int i = 0; i < _numberOfOptions; i++) {
      _optionControllers.add(TextEditingController());
      _isCorrectOption.add(false);
    }
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _imageUrlController.dispose(); // Dispose image URL controller
    super.dispose();
  }

  // --- NEW: Image Picking and Cropping Logic ---
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
      ); // Low quality for faster upload
      if (pickedFile != null) {
        _cropImage(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
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
          statusBarColor: Theme.of(context).primaryColor,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
          hideBottomControls: false, // Optional: helps on some devices
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _pickedImageFile = XFile(croppedFile.path);
        _imageUrlController.clear();
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
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(
        'question_images/$fileName',
      );
      final uploadTask = storageRef.putFile(File(_pickedImageFile!.path));

      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _uploadedImageUrl = downloadUrl;
        _isUploadingImage = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
      }
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
      _imageUrlController.clear();
    });
  }
  // --- END NEW: Image Logic ---

  void _addQuestion() async {
    final String questionText = _questionTextController.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question text cannot be empty.')),
      );
      return;
    }

    // Determine the image URL to save
    String? finalImageUrl;
    if (_uploadedImageUrl != null) {
      finalImageUrl = _uploadedImageUrl; // Prioritize uploaded image
    } else if (_imageUrlController.text.trim().isNotEmpty) {
      finalImageUrl = _imageUrlController.text.trim(); // Then check manual URL
    }

    List<Map<String, dynamic>> options = [];
    bool hasCorrectOption = false;

    for (int i = 0; i < _numberOfOptions; i++) {
      final String optionText = _optionControllers[i].text.trim();
      if (optionText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All options must be filled.')),
        );
        return;
      }
      options.add({'text': optionText, 'isCorrect': _isCorrectOption[i]});
      if (_isCorrectOption[i]) {
        hasCorrectOption = true;
      }
    }

    if (!hasCorrectOption) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one correct option.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saving question...')));

    try {
      CollectionReference questionsCollection = FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('questions');

      await questionsCollection.add({
        'questionText': questionText,
        'options': options,
        'type': 'multiple_choice',
        'imageUrl': finalImageUrl, // <-- NEW: Save image URL
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question saved successfully!')),
      );

      // Clear all fields after successful add
      _questionTextController.clear();
      for (var controller in _optionControllers) {
        controller.clear();
      }
      setState(() {
        _isCorrectOption.fillRange(0, _isCorrectOption.length, false);
        _clearSelectedImage(); // Clear image fields
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add question: $e')));
    }
  }

  // Function to delete a question
  Future<void> _deleteQuestion(String questionId, String questionText) async {
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete this question? "$questionText"?',
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting question "$questionText"...')),
    );

    try {
      await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('questions')
          .doc(questionId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete question: $e')));
    }
  }

  // --- NEW: Duplicate Question Logic ---
  Future<void> _duplicateQuestion(DocumentSnapshot questionDocument) async {
    Map<String, dynamic> questionData =
        questionDocument.data() as Map<String, dynamic>;

    // Populate the 'Add New Question' form with duplicated data
    setState(() {
      _questionTextController.text = questionData['questionText'] ?? '';
      _clearSelectedImage(); // Clear current image selection first

      // Set image preview if present in duplicated question
      String? duplicatedImageUrl = questionData['imageUrl'];
      if (duplicatedImageUrl != null && duplicatedImageUrl.isNotEmpty) {
        _imageUrlController.text = duplicatedImageUrl;
        _uploadedImageUrl =
            duplicatedImageUrl; // Treat it as if it was uploaded for preview
      }

      // Clear existing option controllers and add new ones based on duplicated options
      _optionControllers.clear();
      _isCorrectOption.clear();
      List<dynamic> options = questionData['options'] ?? [];
      _numberOfOptions =
          options.length; // Set number of options to match duplicated question

      for (var option in options) {
        _optionControllers.add(
          TextEditingController(text: option['text'] ?? ''),
        );
        _isCorrectOption.add(option['isCorrect'] ?? false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question loaded into form for duplication.'),
        ),
      );
    });
  }
  // --- END NEW: Duplicate Logic ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Questions'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adding questions for Test ID: ${widget.testId}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Section for adding new questions
              const Text(
                'Add New Question',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _questionTextController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // --- NEW: Image Upload & Link Section ---
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (Optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Enter direct image link',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _pickedImageFile =
                              null; // Clear picked file if URL is typed
                          _uploadedImageUrl =
                              null; // Clear uploaded URL if URL is typed
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showImageSourceDialog(), // Method to choose source
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Image'),
                  ),
                ],
              ),
              if (_isUploadingImage)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(), // Or Circular
                ),
              if (_pickedImageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Image.file(
                    File(_pickedImageFile!.path),
                    height: 150, // Adjust height as needed
                    fit: BoxFit.contain,
                  ),
                ),
              if (_imageUrlController.text.isNotEmpty && !_isUploadingImage)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Image.network(
                    _imageUrlController.text,
                    height: 150, // Adjust height as needed
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text('Invalid Image URL'), // Handle broken links
                  ),
                ),
              if ((_pickedImageFile != null ||
                      _imageUrlController.text.isNotEmpty) &&
                  !_isUploadingImage)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearSelectedImage,
                    icon: const Icon(Icons.clear, color: Colors.red),
                    label: const Text(
                      'Clear Image',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // --- END NEW: Image Section ---
              ...List.generate(_numberOfOptions, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            labelText:
                                'Option ${String.fromCharCode(65 + index)}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Checkbox(
                        value: _isCorrectOption[index],
                        onChanged: (bool? value) {
                          setState(() {
                            for (int i = 0; i < _isCorrectOption.length; i++) {
                              _isCorrectOption[i] = (i == index)
                                  ? value!
                                  : false;
                            }
                          });
                        },
                      ),
                      const Text('Correct'),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Question',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(
                height: 40,
              ), // More space before existing questions
              // --- Section for displaying existing questions ---
              const Text(
                'Existing Questions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tests')
                    .doc(widget.testId)
                    .collection('questions')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No questions added yet.'));
                  }

                  return ListView.builder(
                    shrinkWrap:
                        true, // Important for nested ListView in SingleChildScrollView
                    physics:
                        const NeverScrollableScrollPhysics(), // Prevents nested scrolling issues
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot questionDocument =
                          snapshot.data!.docs[index];
                      Map<String, dynamic> questionData =
                          questionDocument.data() as Map<String, dynamic>;

                      String questionId = questionDocument.id;
                      String questionText =
                          questionData['questionText'] ?? 'No Question Text';
                      List<dynamic> options = questionData['options'] ?? [];
                      String? imageUrl =
                          questionData['imageUrl']; // Get image URL

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10.0),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}. $questionText',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (imageUrl != null &&
                                  imageUrl.isNotEmpty) // Display image
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    height:
                                        100, // Smaller height for list preview
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Text('Error loading image'),
                                  ),
                                ),
                              const SizedBox(height: 5),
                              ...options.map((option) {
                                return Text(
                                  '${option['text']} ${option['isCorrect'] ? '(Correct)' : ''}',
                                  style: TextStyle(
                                    color: option['isCorrect']
                                        ? Colors.green
                                        : Colors.black,
                                  ),
                                );
                              }),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // --- NEW: Duplicate Button ---
                                  TextButton(
                                    onPressed: () =>
                                        _duplicateQuestion(questionDocument),
                                    child: const Text('Duplicate'),
                                  ),
                                  const SizedBox(width: 8),
                                  // --- END NEW ---
                                  TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Edit Question "$questionText" - Coming Soon!',
                                          ),
                                        ),
                                      );
                                      // Navigator.pushNamed(context, '/admin_edit_question', arguments: {'testId': widget.testId, 'questionId': questionId, 'initialQuestionData': questionData});
                                    },
                                    child: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => _deleteQuestion(
                                      questionId,
                                      questionText,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
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
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.done_all),
                label: const Text(
                  'Finish Adding Questions',
                  style: TextStyle(fontSize: 18),
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
    );
  }

  // --- NEW: Show Image Source Dialog ---
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
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
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
}
