// File: lib/screens/chats_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadu_academy_app/screens2/chat_messaging_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String? _currentUserType;
  bool? _isApprovedByAdminKaduAcademy;
  bool? _isApprovedByAdminCollegeStudent;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserType();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchCurrentUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _currentUserType = userDoc.data()?['studentType'] as String?;
          _isApprovedByAdminKaduAcademy =
              userDoc.data()?['isApprovedByAdminKaduAcademy'] as bool?;
          _isApprovedByAdminCollegeStudent =
              userDoc.data()?['isApprovedByAdminCollegeStudent'] as bool?;
          _isLoadingUser = false;
        });
      }
    }
  }

  Widget _buildChatListItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: 16.0,
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[200],
          child: Icon(icon, color: Colors.blueAccent, size: 30),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 20),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    List<Widget> chatItems = [];

    // All users can see the Admin Chat.
    chatItems.add(
      _buildChatListItem(
        title: 'Admin Chats',
        subtitle: 'Chat with the admin team of Kadu Academy.',
        icon: Icons.admin_panel_settings,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Admin chat is not available yet. Stay Tuned!',
                style: TextStyle(fontSize: 12),
              ),
            ),
          );
        },
      ),
    );

    // Add Kadu Academy chat only for Kadu Academy students who are approved.
    if (_currentUserType == 'kadu_academy' &&
        _isApprovedByAdminKaduAcademy == true) {
      chatItems.add(
        _buildChatListItem(
          title: 'Kadu Academy Students Chats',
          subtitle: 'Connect with Kadu Academy students.',
          icon: Icons.school,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatMessagingScreen(
                  chatType: 'kadu_academy_chat',
                  chatTitle: 'Kadu Academy Khamgaon',
                ),
              ),
            );
          },
        ),
      );
    }

    // Add College chat only for College students who are approved.
    if (_currentUserType == 'college' &&
        _isApprovedByAdminCollegeStudent == true) {
      chatItems.add(
        _buildChatListItem(
          title: 'College Students Chats',
          subtitle: 'Connect with College students.',
          icon: Icons.group,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatMessagingScreen(
                  chatType: 'college_chat',
                  chatTitle: 'College Students',
                ),
              ),
            );
          },
        ),
      );
    }

    // Check if no chat items are available
    if (chatItems.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No chat rooms available for your account type.'),
        ),
      );
    }

    return Scaffold(
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(children: chatItems),
      ),
    );
  }
}
