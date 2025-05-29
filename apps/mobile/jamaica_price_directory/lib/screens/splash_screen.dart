import 'package:flutter/material.dart';
import 'dart:async'; // For Timer functionality

// Splash Screen - First screen users see when app opens
// Shows logo and app name, then navigates to login
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

// State class - handles the screen's changing data and behavior
class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    // This runs when the screen first loads
    _navigateToLogin();
  }
  
  // Function to wait 3 seconds, then go to login screen
  void _navigateToLogin() {
    Timer(Duration(seconds: 3), () {
      // Navigator is Flutter's way to move between screens
      // pushReplacementNamed removes this screen from memory
      Navigator.pushReplacementNamed(context, '/login');
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color
      backgroundColor: Color(0xFF1E3A8A), // Jamaica blue from your theme
      
      // Body contains all the content
      body: Center(
        child: Column(
          // Center everything vertically
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo (using a placeholder icon for now)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.shopping_cart,
                size: 60,
                color: Color(0xFF1E3A8A),
              ),
            ),
            
            SizedBox(height: 32), // Space between elements
            
            // App Name
            Text(
              'Jamaica Price Directory',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 16),
            
            // Tagline
            Text(
              'Find the best prices across Jamaica',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 48),
            
            // Loading indicator
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}