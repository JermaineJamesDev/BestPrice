import 'package:flutter/material.dart';
import 'package:jamaica_price_directory/core/theme/themes.dart';

// Import our screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/enhanced_camera_screen.dart';
import 'app_navigation_shell.dart';
import 'services/consolidated_ocr_service.dart';

// This is the entry point of our Flutter app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the consolidated OCR service
  final config = OCRServiceConfig(
    usePersistentCache: true,
    maxRetryAttempts: 3,
    enablePerformanceMonitoring: true,
    defaultPriority: ProcessingPriority.normal,
  );

  await ConsolidatedOCRService.instance.initialize(config: config);

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🚨 Flutter Error: ${details.exception}');
    debugPrint('🚨 Stack Trace: ${details.stack}');
    FlutterError.presentError(details);
  };

  runApp(const JamaicaPriceDirectoryApp());
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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,

      // Define our app routes (navigation paths)
      routes: {
        '/': (context) => SplashScreen(), // Splash screen
        '/login': (context) => LoginScreen(), // Login screen
        '/register': (context) => RegisterScreen(), // Register screen
        // Main app routes with navigation shell
        '/home': (context) =>
            AppNavigationShell(currentRoute: '/home', child: HomeScreen()),
        '/search': (context) =>
            AppNavigationShell(currentRoute: '/search', child: SearchScreen()),
        '/camera': (context) => AppNavigationShell(
          currentRoute: '/camera',
          child: EnhancedCameraScreen(),
        ),
        '/budget': (context) =>
            AppNavigationShell(currentRoute: '/budget', child: BudgetScreen()),
        '/profile': (context) => AppNavigationShell(
          currentRoute: '/profile',
          child: ProfileScreen(),
        ),
        
      },

      // Starting screen
      initialRoute: '/',
    );
  }
}
