import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/auth/login_page.dart';
import 'pages/home/home_page.dart';
import 'pages/reporting/location_page.dart';
import 'core/app_colors.dart';


// Global key for navigation across the app without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('af_ZA', null);
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found. Using hardcoded defaults or environment variables.");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Akademia Fasiliteite',

      // Global App Theme Configuration
      theme: ThemeData(
        fontFamily: 'Poppins',
        primaryColor: AppColors.navy,
        scaffoldBackgroundColor: AppColors.background,

        // Custom AppBar styling for a consistent look
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),

        // Default button styles
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // Text input styling used throughout the app
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          labelStyle: const TextStyle(color: AppColors.navy),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          prefixIconColor: AppColors.navy,
        ),
      ),

      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        // Route management
        switch (settings.name) {
          case '/':
            page = const LoginPage();
            break;
          case '/home':
            page = const HomePage();
            break;
          case '/location':
            final args = settings.arguments as Map<String, dynamic>?;
            page = LocationPage(autoConfirm: args?['autoConfirm'] ?? false);
            break;
          default:
            page = const LoginPage();
        }

        // Custom Smooth Fade Transition between screens
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = 0.0;
            const end = 1.0;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return FadeTransition(
              opacity: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
      },
    );
  }
}
