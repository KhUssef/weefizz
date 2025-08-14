import 'package:flutter/material.dart';
import 'home.dart';
import 'fabrics.dart';
import 'templates.dart';
import 'profile.dart';
import 'new_project_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  // Use a private key internally to avoid exposing a private type in a public API
  static final GlobalKey<_MainNavigationScreenState> _navKey = GlobalKey<_MainNavigationScreenState>();
  // Factory to create the shell with the internal key
  factory MainNavigationScreen.shell() => MainNavigationScreen(key: _navKey);
  static void selectTab(int index) {
    _navKey.currentState?.setIndex(index);
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  final List<BottomNavigationBarItem> _bottomNavItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.grid_view),
      activeIcon: Icon(Icons.grid_view),
      label: 'Accueil',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.description_outlined),
      activeIcon: Icon(Icons.description),
      label: 'Gabarits',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.category_outlined),
      activeIcon: Icon(Icons.category),
  label: 'Tissus',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  // Keep cached data when switching tabs; no auto-refetch here
  }

  void setIndex(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  void _onAddPressed() {
    // Navigate to new project screen from home
    if (_currentIndex == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const NewProjectScreen(),
        ),
      );
    } else {
      // Handle add button press based on current screen
      switch (_currentIndex) {
        case 1: // Templates
          debugPrint('Add new template');
          break;
        case 2: // Fabrics
          debugPrint('Add new fabric');
          break;
        case 3: // Profile
          debugPrint('Add new item from profile');
          break;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      HomeScreen(onSelectTab: (i) => setState(() => _currentIndex = i)),
      const TemplatesScreen(),
      const FabricsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    // When app window is reopened/resumed, refetch everything
  // Keep cached data on resume; no auto-refetch here
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: _bottomNavItems,
        ),
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _onAddPressed,
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
