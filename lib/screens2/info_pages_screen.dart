// File: lib/screens2/info_pages_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Required for phone dialer and map

class InfoPagesScreen extends StatelessWidget {
  const InfoPagesScreen({super.key});

  // Phone number and address details (centralized for easy modification)
  static const String _phoneNumber = '+91 8830020091';
  static const String _address =
      'In Front Of Rutik Book Stall, Near School Number 9, Civil Lines-444303, Khamgaon';
  static const String _websiteUrl = 'https://kaduacademy.com/';

  // Function to launch phone dialer
  Future<void> _launchPhoneDialer(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // It's good practice to show a user-facing error message here
    }
  }

  // Function to launch map application
  Future<void> _launchMap(String address) async {
    // The provided Google Maps URL is a share link, which is fine, but a
    // more standard approach for launching a map with a query is better.
    // This will work more reliably on both Android and iOS.
    final Uri launchUri = Uri.parse(
      'https://maps.app.goo.gl/YetF9n722yDACvog6',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {}
  }

  // Function to launch website URL
  Future<void> _launchWebsite(String url) async {
    final Uri launchUri = Uri.parse(url);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Information & Support', // General title for this consolidated page
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(
          24.0,
        ), // Increased padding for better look
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Stretch children for a clean layout
          children: [
            _buildSectionTitle('Contact Us'),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Rajesh Kadu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _launchPhoneDialer(_phoneNumber),
                icon: const Icon(Icons.phone, size: 20),
                label: const Text(_phoneNumber, style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: const Text(
                'Offline Address:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  // Use Flexible to prevent overflow on long addresses
                  child: Text(
                    _address,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _launchMap(_address),
                icon: const Icon(Icons.map, size: 20),
                label: const Text(
                  'View on Map',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20), // Added space after the map button
            // --- Website Button (NEW) ---
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _launchWebsite(_websiteUrl),
                icon: const Icon(Icons.public, size: 20),
                label: const Text(
                  'Visit Our Website',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // --- End of new addition ---
            const Divider(height: 50, thickness: 1, color: Colors.grey),

            _buildSectionTitle('About Kadu Academy'),
            const SizedBox(height: 15),
            const Text(
              'Kadu Academy is dedicated to providing high-quality educational resources and a supportive learning environment for students aspiring to excel in various competitive exams. Our mission is to empower learners with the knowledge, skills, and confidence needed to achieve their academic and career goals. We offer comprehensive study materials, expert-led live sessions, and a robust platform for practice and performance tracking. Join us on your journey to success!',
              // Adjusted text style to be thinner and more elegant
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.justify,
            ),
            const Divider(height: 50, thickness: 1, color: Colors.grey),

            _buildSectionTitle('Terms and Conditions'),
            const SizedBox(height: 15),
            const Text(
              'Welcome to Kadu Academy. By accessing or using our services, you agree to comply with and be bound by the following terms and conditions of use. Please review these terms carefully. If you do not agree to these terms, you should not use our services. We reserve the right to change these terms at any time without prior notice. Your continued use of the platform constitutes acceptance of the revised terms. All content provided on this platform is for informational purposes only. Kadu Academy makes no representations as to the accuracy or completeness of any information on this site or found by following any link on this site. Kadu Academy will not be liable for any errors or omissions in this information nor for the availability of this information. The owner will not be liable for any losses, injuries, or damages from the display or use of this information. Your use of any information or materials on this website is entirely at your own risk, for which we shall not be liable. It shall be your own responsibility to ensure that any products, services, or information available through this website meet your specific requirements.',
              // Adjusted text style to be thinner and more elegant
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.justify,
            ),
            const Divider(height: 50, thickness: 1, color: Colors.grey),

            _buildSectionTitle('Privacy Policy'),
            const SizedBox(height: 15),
            const Text(
              'At Kadu Academy, we are committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit our mobile application. We collect personal information that you voluntarily provide to us when you register on the app, express an interest in obtaining information about us or our products and services, when you participate in activities on the app, or otherwise when you contact us. The personal information that we collect depends on the context of your interactions with us and the app, the choices you make, and the products and features you use. We do not knowingly collect data from or market to children under 18 years of age. By using the app, you consent to the data practices described in this policy. We implement a variety of security measures to maintain the safety of your personal information when you place an order or enter, submit, or access your personal information. Your information, whether public or private, will not be sold, exchanged, transferred, or given to any other company for any reason whatsoever, without your consent, other than for the express purpose of delivering the purchased product or service requested. We may update this privacy policy from time to time. The updated version will be indicated by an updated "Revised" date and the updated version will be effective as soon as it is accessible.',
              // Adjusted text style to be thinner and more elegant
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 40),

            // --- Developer Info Section (NEW) ---
            const DeveloperInfoSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper widget to build consistent titles
  Widget _buildSectionTitle(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}

// --- NEW WIDGET FOR DEVELOPER INFO ---
class DeveloperInfoSection extends StatelessWidget {
  const DeveloperInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Text(
            'Designed & Developed By',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Yash Masne',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900, // Make the name bold and prominent
              color: Colors.blue, // Use a highlight color
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
