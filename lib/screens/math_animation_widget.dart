import 'package:flutter/material.dart';
import 'dart:math'; // For Random class

class MathAnimationWidget extends StatefulWidget {
  const MathAnimationWidget({super.key});

  @override
  State<MathAnimationWidget> createState() => _MathAnimationWidgetState();
}

class _MathAnimationWidgetState extends State<MathAnimationWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _textAnimationController;
  late Animation<double> _opacityAnimation;

  final Random _random = Random(); // Random instance for picking thoughts

  final List<String> _positiveThoughts = [
    // Your 50 positive thoughts (or more)
    'Believe in yourself. You are capable',
    'Every day is a new beginning',
    'Your potential is endless',
    'Stay positive, work hard',
    'Great things take time. Be patient',
    'You are stronger than you think',
    'Today is a gift. Embrace it',
    'Choose joy. Choose kindness',
    'Keep learning, keep growing',
    'Your attitude determines your direction',
    'Find beauty in every day',
    'Small steps lead to big dreams',
    'Be the change you wish to see',
    'Focus on progress, not perfection',
    'Inspire and be inspired',
    'Challenges make you stronger',
    'You\'ve got this!',
    'Embrace your unique journey',
    'Never stop exploring',
    'Kindness makes a difference',
    'Dream big. Work hard. Stay humble',
    'The best is yet to come',
    'You are resilient and brave',
    'Create your own sunshine',
    'Happiness is a choice',
    'Radiate positive vibes',
    'Make today amazing',
    'Celebrate every small victory',
    'Your effort matters',
    'Believe in magic (and yourself)',
    'Stay curious. Stay hopeful',
    'You are enough, exactly as you are',
    'Growth is a process',
    'Find your happy place',
    'Keep shining your light',
    'Be grateful for today',
    'The power is within you',
    'You are making a difference',
    'Always find a reason to smile',
    'Live in the moment',
    'New opportunities await',
    'You are capable of miracles',
    'Let your light shine',
    'Positive mind, positive life',
    'Embrace new possibilities',
    'Your potential is limitless',
    'Stay true to yourself',
    'Make each day count',
    'You are valued',
    'Always be open to wonder',
  ];
  int _currentFormulaIndex = 0;

  @override
  bool get wantKeepAlive => true; // Crucial for persistence across tab changes

  @override
  void initState() {
    super.initState();
    // Initialize Text Animation Controller
    // MODIFIED: Total cycle duration is now 4 seconds
    // (e.g., 0.5s fade-in + 3.0s visible hold + 0.5s fade-out = 4 seconds total cycle)
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 4,
      ), // Set total cycle duration to 4 seconds
    );

    // Define opacity animation (fade in, hold, fade out)
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 1,
      ), // Fade In (1/8 of total duration = 0.5 seconds)
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 6,
      ), // Hold visible (6/8 of total duration = 3.0 seconds)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 1,
      ), // Fade Out (1/8 of total duration = 0.5 seconds)
    ]).animate(_textAnimationController);

    // Add listener to control formula change and animation repetition
    _textAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // When one full cycle (fade in -> hold -> fade out) completes,
        // update the formula and restart animation from the beginning.
        if (_positiveThoughts.isNotEmpty) {
          setState(() {
            _currentFormulaIndex = _random.nextInt(
              _positiveThoughts.length,
            ); // Randomly pick index
          });
        }
        _textAnimationController.forward(
          from: 0.0,
        ); // Restart from beginning for the new formula
      }
    });

    _textAnimationController.forward(); // Start the animation
  }

  @override
  void dispose() {
    _textAnimationController.dispose(); // Dispose the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Crucial for AutomaticKeepAliveClientMixin

    return SizedBox(
      // Use SizedBox to give it a fixed size vertically
      height: 30, // Retained height
      width: double.infinity, // Ensure it takes full width for centering
      child: Center(
        // Center the string horizontally and vertically
        child: AnimatedBuilder(
          animation: _textAnimationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _opacityAnimation, // Apply fade in/out
              child: Text(
                _positiveThoughts[_currentFormulaIndex],
                style: TextStyle(
                  fontSize: 16, // Retained font size
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent[700], // Retained color
                ),
                textAlign: TextAlign.center, // Ensure text is centered
                maxLines: 1, // Single line
                overflow:
                    TextOverflow.ellipsis, // Add ellipsis if text is too long
              ),
            );
          },
        ),
      ),
    );
  }
}
