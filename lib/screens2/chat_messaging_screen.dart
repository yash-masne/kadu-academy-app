// File: lib/screens2/chat_messaging_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'dart:io'; // Explicitly importing dart:io for File
import 'package:cached_network_image/cached_network_image.dart'; // NEW: Added for image preview

class ChatMessagingScreen extends StatefulWidget {
  final String chatType;
  final String chatTitle;

  const ChatMessagingScreen({
    super.key,
    required this.chatType,
    required this.chatTitle,
  });

  @override
  State<ChatMessagingScreen> createState() => _ChatMessagingScreenState();
}

class _ChatMessagingScreenState extends State<ChatMessagingScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserName();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserName() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _currentUserName = userDoc.data()?['firstName'] as String?;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }

    final user = _auth.currentUser;
    if (user != null && _currentUserName != null) {
      final messageText = _messageController.text.trim();
      _messageController.clear();

      await _firestore.collection('messages').add({
        'text': messageText,
        'senderId': user.uid,
        'senderName': _currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
        'chatType': widget.chatType,
      });
      // The StreamBuilder will handle the scroll, so no need for an explicit call here.
    }
  }

  // NEW: Method to pick and send a file
  Future<void> _pickAndSendFile() async {
    final user = _auth.currentUser;
    if (user == null || _currentUserName == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      final file = result.files.first;
      if (file.bytes == null) {
        // Handle web case or other platforms where bytes might be null.
        if (file.path != null) {
          _showSnackBar('Uploading from local path...');
          // On web, this might not work correctly.
        } else {
          _showSnackBar('Selected file has no data.');
          return;
        }
      }

      _showSnackBar('Uploading file...');

      try {
        final fileName = path.basename(file.path ?? file.name!);
        final storageRef = _storage.ref().child(
          'chat_files/${widget.chatType}/${user.uid}/$fileName',
        );

        UploadTask uploadTask;
        if (file.bytes != null) {
          uploadTask = storageRef.putData(file.bytes!);
        } else {
          uploadTask = storageRef.putFile(File(file.path!));
        }

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        final fileType = _getFileType(fileName);

        await _firestore.collection('messages').add({
          'text': '', // No text message for file uploads
          'senderId': user.uid,
          'senderName': _currentUserName,
          'timestamp': FieldValue.serverTimestamp(),
          'chatType': widget.chatType,
          'fileUrl': downloadUrl,
          'fileName': fileName,
          'fileType': fileType,
        });

        _showSnackBar('File sent successfully!');
      } on FirebaseException catch (e) {
        _showSnackBar('File upload failed: ${e.message}');
      } catch (e) {
        _showSnackBar('An unexpected error occurred: $e');
      }
    }
  }

  String _getFileType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      return 'image';
    } else if (extension == '.pdf') {
      return 'pdf';
    } else if (['.doc', '.docx'].contains(extension)) {
      return 'word';
    }
    return 'unknown';
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chatTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent, // Applied new color
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('chatType', isEqualTo: widget.chatType)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello!'),
                  );
                }

                final messages = snapshot.data!.docs.reversed.toList();
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];

                    // FIX: Use a regular conditional check for the map before accessing keys
                    final messageData = message.data() as Map<String, dynamic>?;
                    final messageText = messageData?['text'];
                    final messageSender =
                        messageData?['senderName'] ?? 'Anonymous';
                    final fileUrl =
                        messageData != null &&
                            messageData.containsKey('fileUrl')
                        ? messageData['fileUrl']
                        : null;
                    final fileName =
                        messageData != null &&
                            messageData.containsKey('fileName')
                        ? messageData['fileName']
                        : null;
                    final fileType =
                        messageData != null &&
                            messageData.containsKey('fileType')
                        ? messageData['fileType']
                        : null;

                    final currentUser = _auth.currentUser;
                    final isMe = currentUser?.uid == messageData?['senderId'];

                    return MessageBubble(
                      sender: messageSender,
                      text: messageText,
                      isMe: isMe,
                      fileUrl: fileUrl,
                      fileName: fileName,
                      fileType: fileType,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // NEW: File picker button
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file,
                      color: Colors.blueAccent,
                    ),
                    onPressed: _pickAndSendFile,
                    tooltip: 'Attach file',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Enter your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String sender;
  final String text;
  final bool isMe;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;

  const MessageBubble({
    required this.sender,
    required this.text,
    required this.isMe,
    this.fileUrl,
    this.fileName,
    this.fileType,
    super.key,
  });

  // A helper to get the right icon for the file type
  IconData _getFileIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'word':
        return Icons.insert_drive_file;
      case 'image':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            sender,
            style: const TextStyle(fontSize: 12.0, color: Colors.black54),
          ),
          Material(
            borderRadius: BorderRadius.only(
              topLeft: isMe
                  ? const Radius.circular(15.0)
                  : const Radius.circular(0),
              topRight: isMe
                  ? const Radius.circular(0)
                  : const Radius.circular(15.0),
              bottomLeft: const Radius.circular(15.0),
              bottomRight: const Radius.circular(15.0),
            ),
            elevation: 5.0,
            color: isMe ? Colors.lightBlueAccent : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 20.0,
              ),
              child: fileUrl != null
                  ? GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(fileUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          // Handle error
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open file: $fileName'),
                            ),
                          );
                        }
                      },
                      child: fileType == 'image'
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: CachedNetworkImage(
                                imageUrl: fileUrl!,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                                width: 150,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getFileIcon(fileType!),
                                  color: isMe
                                      ? Colors.white
                                      : Colors.blueAccent,
                                ),
                                const SizedBox(width: 8.0),
                                Flexible(
                                  child: Text(
                                    fileName!,
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: isMe
                                          ? Colors.white
                                          : Colors.blueAccent,
                                      fontSize: 15.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    )
                  : Text(
                      text,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15.0,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
