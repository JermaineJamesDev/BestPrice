import 'package:flutter/material.dart';

// Main Navigation Shell - Handles bottom navigation and routing
class AppNavigationShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  
  const AppNavigationShell({super.key, 
    required this.child, 
    required this.currentRoute,
  });
  
  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  int _selectedIndex = 0;
  
  // Navigation items configuration
  final List<NavItem> _navItems = [
    NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: '/home',
    ),
    NavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: 'Search',
      route: '/search',
    ),
    NavItem(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt,
      label: 'Camera',
      route: '/camera',
    ),
    NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Budget',
      route: '/budget',
    ),
    NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
      route: '/profile',
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _updateSelectedIndex();
  }
  
  @override
  void didUpdateWidget(AppNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _updateSelectedIndex();
    }
  }
  
  // Update selected index based on current route
  void _updateSelectedIndex() {
    for (int i = 0; i < _navItems.length; i++) {
      if (widget.currentRoute.startsWith(_navItems[i].route)) {
        setState(() {
          _selectedIndex = i;
        });
        break;
      }
    }
  }
  
  // Handle navigation tap
  void _onNavItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      
      // Navigate to the selected route
      Navigator.pushReplacementNamed(context, _navItems[index].route);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha((0.3 * 255).round()),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onNavItemTapped,
          
          // Styling
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1E3A8A),
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          
          // Navigation items
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Icon(item.icon),
            activeIcon: Icon(item.activeIcon),
            label: item.label,
          )).toList(),
        ),
      ),
      
      // Floating Action Button for quick price submission
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1 // Show on Home and Search tabs
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/camera');
              },
              backgroundColor: Color(0xFF1E3A8A),
              tooltip: 'Add Price',
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// Navigation Item Data Class
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  
  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}