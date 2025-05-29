import 'package:flutter/material.dart';

// Import our screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';

// This is the entry point of our Flutter app
// Think of it like the main() function in other programming languages
void main() {
  runApp(JamaicaPriceDirectoryApp());
}

// This is our main app widget - it wraps everything
class JamaicaPriceDirectoryApp extends StatelessWidget {
  const JamaicaPriceDirectoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App configuration
      title: 'Jamaica Price Directory',
      debugShowCheckedModeBanner: false, // Removes "DEBUG" banner
      
      // App theme - colors and styling
      theme: ThemeData(
        // Primary color scheme (Jamaica blue from your docs)
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF1E3A8A), // Jamaica blue
        
        // App bar styling
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        
        // Button styling
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        
        // Input field styling
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      
      // Define our app routes (navigation paths)
      routes: {
        '/': (context) => SplashScreen(),           // Home route (first screen)
        '/login': (context) => LoginScreen(),      // Login screen
        '/register': (context) => RegisterScreen(), // Register screen
        '/home': (context) => HomeScreen(),        // Main app screen
      },
      
      // Starting screen
      initialRoute: '/',
    );
  }
}