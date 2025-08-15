// DashboardSettingScreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io'; // For File
import 'package:cached_network_image/cached_network_image.dart'; // Ensure this is imported

class DashboardSettingScreen extends StatefulWidget {
  const DashboardSettingScreen({super.key});

  @override
  State<DashboardSettingScreen> createState() => _DashboardSettingScreenState();
}

class _DashboardSettingScreenState extends State<DashboardSettingScreen> {
  final ImagePicker _picker = ImagePicker();
  final int maxImages = 6; // Maximum number of images allowed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Dashboard Setting', // Reverted title as it's now general
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Student Dashboard Images', // Reverted text
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Upload up to $maxImages images for the student dashboard carousel. Recommended aspect ratio is 16:9 for best display.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            StreamBuilder<QuerySnapshot>(
              // *** CHANGE 1: Point to 'studentDashboardImages' collection ***
              stream: FirebaseFirestore.instance
                  .collection('studentDashboardImages') // <-- FINAL COLLECTION
                  .orderBy(
                    'createdAt', // Order by createdAt is safe for auto-generated IDs
                    descending: false,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading images: ${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  );
                }

                final List<DocumentSnapshot> imageDocs =
                    snapshot.data?.docs ?? [];
                final bool canAddMoreImages = imageDocs.length < maxImages;

                return Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10.0,
                            mainAxisSpacing: 10.0,
                            childAspectRatio: 16 / 9,
                          ),
                      itemCount: imageDocs.length,
                      itemBuilder: (context, index) {
                        final imageData =
                            imageDocs[index].data() as Map<String, dynamic>;
                        final String imageUrl = imageData['imageUrl'] ?? '';
                        final String docId = imageDocs[index].id;

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: Colors.white,
                                child: imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[200],
                                          alignment: Alignment.center,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                              ),
                                        ),
                                        errorWidget: (context, url, error) {
                                          return Container(
                                            color: Colors.grey[300],
                                            alignment: Alignment.center,
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  color: Colors.red,
                                                  size: 30,
                                                ),
                                                Text(
                                                  'Load Error',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'No Image',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                              ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  onPressed: () =>
                                      _deleteImage(docId, imageUrl),
                                  tooltip: 'Delete Image',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    if (canAddMoreImages)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _pickAndUploadImage,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(
                            'Add New Image (${imageDocs.length}/$maxImages)',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Maximum $maxImages images uploaded. Delete existing images to add more.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            // FIX: Disable the bottom controls to remove the tilt option.
            hideBottomControls: true,
          ),
          // FIX: Disable the bottom controls for iOS as well.
          IOSUiSettings(title: 'Crop Image'),
        ],
      );

      if (croppedFile != null) {
        final File imageFile = File(croppedFile.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading image...', style: TextStyle(fontSize: 12)),
          ),
        );
        final String? imageUrl = await _uploadImageToStorage(imageFile);
        if (imageUrl != null) {
          await _addImageUrlToFirestore(imageUrl);
        }
      }
    }
  }

  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      // *** CHANGE 2: Upload to 'dashboard_images' folder in Storage ***
      final String fileName =
          'dashboard_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}'; // <-- FINAL STORAGE FOLDER
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        fileName,
      );
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image upload failed: $e',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _addImageUrlToFirestore(String imageUrl) async {
    try {
      // *** CHANGE 3: Get current count from 'studentDashboardImages' ***
      final QuerySnapshot currentImages = await FirebaseFirestore.instance
          .collection('studentDashboardImages') // <-- FINAL COLLECTION
          .get();
      final int newOrder =
          currentImages.docs.length; // Simple ordering by current count

      // *** CHANGE 4: Write to 'studentDashboardImages' ***
      await FirebaseFirestore.instance.collection('studentDashboardImages').add(
        // <-- FINAL COLLECTION
        {
          'imageUrl': imageUrl,
          'createdAt': Timestamp.now(),
          'order': newOrder, // Store order for display
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image added to dashboard successfully!', // Reverted text
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save image: $e',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }
  }

  Future<void> _deleteImage(String docId, String imageUrl) async {
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                'Are you sure you want to delete this image?',
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

    if (!confirmDelete) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleting image...', style: TextStyle(fontSize: 12)),
      ),
    );

    try {
      if (imageUrl.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        // Cache eviction is crucial here and is present!
        await CachedNetworkImage.evictFromCache(imageUrl);
      }
      // *** CHANGE 5: Delete from 'studentDashboardImages' ***
      await FirebaseFirestore.instance
          .collection('studentDashboardImages') // <-- FINAL COLLECTION
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image deleted successfully!',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete image: $e',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }
  }
}
