import 'package:flutter/material.dart';
import 'package:kadu_academy_app/screens/home_screen.dart';
import 'package:kadu_academy_app/screens/livestream_screen.dart';
import 'package:kadu_academy_app/screens/chats_screen.dart';
import 'package:kadu_academy_app/screens/profile_screen.dart';
import 'package:kadu_academy_app/test/student_test_list_screen.dart';
import 'package:kadu_academy_app/screens2/app_drawer.dart';
import 'package:kadu_academy_app/screens2/notifications_screen.dart'; // Import the notifications screen

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  DateTime?
  _lastPressed; // NEW: Track the last time the back button was pressed

  late final List<Widget> _widgetOptions;
  final List<String> _appBarTitles = const [
    'Home',
    'Livestream',
    'Tests',
    'Chats',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const HomeScreen(), // HomeScreen doesn't need callback anymore as per our last changes
      const LivestreamScreen(),
      const StudentTestListScreen(),
      const ChatsScreen(),
      const ProfileScreen(),
    ];
  }

  void onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // MODIFIED: Back button handling logic
  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      // If not on the Home tab, switch to the Home tab and don't exit.
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    }

    // If on the Home tab, check for a second press.
    final now = DateTime.now();
    if (_lastPressed == null ||
        now.difference(_lastPressed!) > const Duration(seconds: 2)) {
      _lastPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press again to exit the app.'),
          duration: Duration(seconds: 2),
        ),
      );
      return false; // Don't exit yet.
    }

    // If the second press happens within 2 seconds, exit the app.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // <--- Added WillPopScope here
      onWillPop: _onWillPop, // <--- Assigned the back button handler
      child: Scaffold(
        backgroundColor: Colors.blue,
        appBar: AppBar(
          toolbarHeight:
              55.0, // <--- Reduced AppBar height (e.g., from default 56.0)
          title: Text(
            _appBarTitles[_selectedIndex],
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          centerTitle: true,
          leading: Builder(
            builder: (BuildContext context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
          actions: [
            // NEW: Made the notification icon active
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
          ],
          backgroundColor: Colors.blue,
        ),
        drawer: const AppDrawer(),
        body: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions.map((widget) {
            return Offstage(
              offstage: _widgetOptions.indexOf(widget) != _selectedIndex,
              child: TickerMode(
                enabled: _widgetOptions.indexOf(widget) == _selectedIndex,
                child: widget,
              ),
            );
          }).toList(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.live_tv),
              label: 'Livestream',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Tests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Chats',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          onTap: onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
