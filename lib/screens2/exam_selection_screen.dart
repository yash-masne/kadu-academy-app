// File: lib/screens2/exam_selection_screen.dart

import 'package:flutter/material.dart';

class ExamSelectionScreen extends StatefulWidget {
  const ExamSelectionScreen({super.key});

  @override
  State<ExamSelectionScreen> createState() => _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends State<ExamSelectionScreen> {
  int? _selectedIndex; // State variable to track selected card index

  final List<Map<String, dynamic>> examCategories = const [
    {
      'title': 'Banking',
      'subtitle': 'IBPS PO, Clerk, RRB, SBI, RBI, EPFO.',
      'icon': Icons.account_balance,
      'color': Color.fromARGB(255, 220, 50, 50),
    },
    {
      'title': 'SSC',
      'subtitle': 'SSC CGL, CHSL, MTS, GD, Steno',
      'icon': Icons.school,
      'color': Color.fromARGB(255, 60, 180, 75),
    },
    {
      'title': 'Teaching',
      'subtitle': 'TET, PRT, TGT, PGT',
      'icon': Icons.campaign,
      'color': Color.fromARGB(255, 120, 80, 200),
    },
    {
      'title': 'FCI',
      'subtitle': 'General, Depot, Technical, JE',
      'icon': Icons.warehouse,
      'color': Color.fromARGB(255, 240, 150, 0),
    },
    {
      'title': 'Regulatory Bodies & SO',
      'subtitle': 'RBI, SEBI, NABARD and SO',
      'icon': Icons.gavel,
      'color': Color.fromARGB(255, 0, 150, 180),
    },
    {
      'title': 'Railways',
      'subtitle': 'RRB ALP/Tech, NTPC, Group D',
      'icon': Icons.train,
      'color': Color.fromARGB(255, 90, 120, 180),
    },
    {
      'title': 'Scholarship',
      'subtitle': 'Navodaya, Olympiad',
      'icon': Icons.emoji_events,
      'color': Color.fromARGB(255, 255, 100, 150),
    },
    {
      'title': 'Aptitude',
      'subtitle': 'Quantitative, Logical Reasoning, Verbal',
      'icon': Icons.lightbulb_outline,
      'color': Color.fromARGB(255, 0, 190, 200),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Your Exam',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select your Exam',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'You can switch between Exams later',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio:
                      1.4, // FURTHER REDUCED aspect ratio (making them even shorter)
                ),
                itemCount: examCategories.length,
                itemBuilder: (context, index) {
                  final category = examCategories[index];
                  final isSelected = _selectedIndex == index;

                  return Card(
                    elevation: isSelected ? 8 : 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? const BorderSide(color: Colors.blue, width: 2)
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          // Toggle selection: if already selected, deselect; otherwise, select
                          _selectedIndex = isSelected ? null : index;
                        });
                        // SNACKBAR REMOVED AS PER REQUEST
                      },
                      // Removed Stack as tick mark is removed
                      child: Padding(
                        padding: const EdgeInsets.all(
                          8.0,
                        ), // REDUCED INTERNAL PADDING
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.start, // Align content to top
                          children: [
                            Row(
                              // Row for Icon and Title
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    category['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  category['icon'] as IconData,
                                  size: 24,
                                  color: category['color'] as Color,
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 5,
                            ), // REDUCED space between title/icon row and subtitle
                            Text(
                              category['subtitle'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(), // Pushes content to top, consumes vacant space
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),

              // Continue / Skip Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/dashboard',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/dashboard',
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: const BorderSide(color: Colors.blue),
                        foregroundColor: Colors.blue,
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
