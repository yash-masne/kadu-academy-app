// File: C:\Users\yashm\project\student_livestream_app_new\lib\screens2\buy_course_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyCourseScreen extends StatelessWidget {
  const BuyCourseScreen({super.key});

  Future<void> _launchPhoneDialer(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {}
  }

  // UPDATED _launchMap FUNCTION
  Future<void> _launchMap(String address) async {
    // Using the specific Google Maps share URL provided
    final Uri launchUri = Uri.parse(
      'https://share.google/8vrWTxiraJWDySp1G?q=$address}',
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // Optionally, add a SnackBar here to inform the user if launching fails
    }
  }

  @override
  Widget build(BuildContext context) {
    const String phoneNumber = '+91 8830020091';
    const String address =
        'In Front Of Rutik Book Stall, Near School Number 9, Civil Lines-444303, Khamgaon';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.remove_shopping_cart,
                size: 80,
                color: Colors.amber[700]!,
              ),
              const SizedBox(height: 15),
              const Text(
                'Online Courses Coming Soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(211, 47, 47, 1),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'We are diligently working to bring you engaging online courses.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Text(
                'Stay tuned for updates!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              const Text(
                'Contact Kadu Academy:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _launchPhoneDialer(phoneNumber),
                icon: const Icon(Icons.phone),
                label: const Text(phoneNumber),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                'Visit Us Offline:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(
                      top: 0.5,
                      right: 3.0,
                    ), // Adjust this value as needed
                    child: Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _launchMap(address),
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
