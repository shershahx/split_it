import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    
    // Navigate to the corresponding route
    switch (index) {
      case 0:
        context.go('/groups');
        break;
      case 1:
        context.go('/friends');
        break;
      case 2:
        context.go('/activity');
        break;
      case 3:
        context.go('/account');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine current index based on current location
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/groups')) {
      _selectedIndex = 0;
    } else if (location.startsWith('/friends')) {
      _selectedIndex = 1;
    } else if (location.startsWith('/activity')) {
      _selectedIndex = 2;
    } else if (location.startsWith('/account')) {
      _selectedIndex = 3;
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
      ),
    );
  }
}
