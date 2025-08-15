// File: C:\Users\yashm\project\student_livestream_app_new\lib\screens2\free_zone_screen.dart

import 'package:flutter/material.dart';

class FreeZoneScreen extends StatelessWidget {
  const FreeZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Zone', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(
          16.0,
        ), // Padding around the entire body content
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Free Learn & Practice',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 15),

            // Daily GK List Tile (No Card, reduced font)
            ListTile(
              leading: Icon(
                Icons.language,
                size: 28,
                color: Colors.blue[700],
              ), // Slightly smaller icon
              title: const Text(
                'Daily GK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ), // Reduced font size
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ), // Slightly smaller arrow
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Currently these features unavailable \n Will be Available Soon !',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const Divider(height: 0), // Thin divider for separation
            // Free Videos List Tile (No Card, reduced font)
            ListTile(
              leading: Icon(
                Icons.play_circle_outline,
                size: 28,
                color: Colors.blue[700],
              ),
              title: const Text(
                'Free Videos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Currently these features unavailable \n Will be Available Soon !',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const Divider(height: 0),

            // Flash Cards List Tile (No Card, reduced font)
            ListTile(
              leading: Icon(
                Icons.description,
                size: 28,
                color: Colors.blue[700],
              ),
              title: const Text(
                'Flash Cards',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Currently these features unavailable \n Will be Available Soon !',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const Divider(height: 0),

            // Free eBooks List Tile (No Card, reduced font)
            ListTile(
              leading: Icon(Icons.menu_book, size: 28, color: Colors.blue[700]),
              title: const Text(
                'Free eBooks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Currently these features unavailable \n Will be Available Soon !',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            // No Divider after the last item if not desired
          ],
        ),
      ),
    );
  }
}
