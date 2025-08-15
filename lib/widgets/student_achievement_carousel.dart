// lib/widgets/student_achievement_carousel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StudentAchievementCarousel extends StatefulWidget {
  const StudentAchievementCarousel({super.key});

  @override
  State<StudentAchievementCarousel> createState() =>
      _StudentAchievementCarouselState();
}

class _StudentAchievementCarouselState
    extends State<StudentAchievementCarousel> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  Timer? _carouselTimer;
  List<String> _imageUrls = []; // List to hold fetched image URLs

  // Flags to manage carousel initialization and updates
  bool _hasInitializedCarousel = false;

  @override
  void initState() {
    super.initState();
    _fetchImagesAndSetupCarousel(); // Fetch images and then setup the carousel
    _pageController.addListener(() {
      if (_pageController.page != null) {
        final newPageIndex = _pageController.page!.round();
        if (newPageIndex != _currentPageIndex) {
          setState(() {
            _currentPageIndex = newPageIndex;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchImagesAndSetupCarousel() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(
            'studentDashboardImages',
          ) // Reading from your main collection
          .orderBy('order', descending: false) // Order by the 'order' field
          .get();

      final List<String> fetchedUrls = snapshot.docs
          .map(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['imageUrl'] as String?,
          )
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();

      if (mounted) {
        setState(() {
          _imageUrls = fetchedUrls;
          _hasInitializedCarousel = true; // Mark as initialized
        });

        if (_imageUrls.length > 1) {
          _startCarouselAutoScroll(_imageUrls.length);
        }
      }
    } catch (e) {
      print('StudentAchievementCarousel: Error fetching images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading achievement images: $e')),
        );
        setState(() {
          _hasInitializedCarousel =
              true; // Still mark as initialized to show placeholder
        });
      }
    }
  }

  void _startCarouselAutoScroll(int itemCount) {
    _carouselTimer?.cancel();

    if (itemCount <= 1) {
      return;
    }

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_pageController.hasClients ||
          _pageController.page == null ||
          _pageController.position.maxScrollExtent == 0.0) {
        _carouselTimer?.cancel();
        return;
      }

      int currentPage = _pageController.page!.round();
      int nextPage = (currentPage + 1) % itemCount;

      _pageController
          .animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          )
          .catchError((e) {
            print('StudentAchievementCarousel: Error animating to page: $e');
            _carouselTimer?.cancel();
          });
    });
  }

  Widget _placeholderBanner() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 5.0),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 40, color: Colors.grey[500]),
            const SizedBox(height: 8),
            const Text(
              'No Achievement Images',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_imageUrls.isEmpty) {
      return SizedBox(
        height: 180, // Maintain height even when empty
        child: Center(
          child: !_hasInitializedCarousel
              ? const CircularProgressIndicator() // Initial loading
              : _placeholderBanner(), // Show placeholder if no images after trying to load
        ),
      );
    }

    return Column(
      children: [
        // FIX: Wrap the PageView.builder in a SizedBox with a fixed height.
        // This gives the PageView a constrained size, resolving the layout error.
        SizedBox(
          height: 180, // Set a fixed height for the carousel
          child: PageView.builder(
            controller: _pageController,
            itemCount: _imageUrls.length,
            itemBuilder: (context, index) {
              final String currentImageUrl = _imageUrls[index];
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tapped on Achievement: ${index + 1}'),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  elevation: 0,
                  color: Colors.transparent, // Set card color to transparent
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.grey[200]!,
                    ), // Match card border to a light grey
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: currentImageUrl,
                    fit: BoxFit
                        .contain, // This is the crucial fix: it ensures the entire image is visible
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      print(
                        'StudentAchievementCarousel: IMAGE LOAD ERROR for $url: $error',
                      );
                      return Container(
                        color: Colors.red[100],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 40),
                              SizedBox(height: 5),
                              Text(
                                'Image Load Error',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        // Dot Indicators
        const SizedBox(height: 8.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _imageUrls.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              height: 4.0,
              width: _currentPageIndex == index ? 4.0 : 4.0,
              decoration: BoxDecoration(
                color: _currentPageIndex == index
                    ? Colors.blueAccent
                    : Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
