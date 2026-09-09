import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart' as svc;
import 'pages/auth/login_page.dart';
import 'pages/home/home_page.dart';
import 'pages/reporting/location_page.dart';
import 'pages/settings/server_config_page.dart';
import 'core/app_colors.dart';
import 'core/api_client.dart';
import 'core/navigation.dart';

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM: ${message.notification?.title}');
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase Core init failed: $e');
    return;
  }

  // Local notifications (can fail independently — icon must be in res/drawable/)
  try {
    const androidSettings = AndroidInitializationSettings('notification_icon');
    await _localNotifs.initialize(
      const InitializationSettings(android: androidSettings),
    );
    debugPrint('Local notifications initialized.');
  } catch (e) {
    debugPrint('Local notifications init failed (push will still work): $e');
  }

  try {
    final messaging = FirebaseMessaging.instance;

    final notifSettings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('FCM permission: ${notifSettings.authorizationStatus}');

    final token = await messaging.getToken();
    if (token != null) {
      _registerFcmTokenWhenAuthReady(token);
    }

    messaging.onTokenRefresh.listen((newToken) {
      _registerFcmTokenWhenAuthReady(newToken);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'FBS';
      final body = message.notification?.body ?? '';
      try {
        _localNotifs.show(
          0, title, body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fbs_channel', 'FBS Kennisgewings',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Local notification show failed: $e');
      }
    });

    debugPrint('Firebase initialized for push notifications.');
  } catch (e) {
    debugPrint('FCM messaging init failed (push disabled): $e');
  }
}

void _registerFcmTokenWhenAuthReady(String token) {
  if (ApiClient.authNotifier.value) {
    // Already authenticated (e.g., biometric re-auth on warm start)
    svc.NotificationService.registerDeviceToken(token);
  } else {
    // Wait for login
    void listener() {
      if (ApiClient.authNotifier.value) {
        ApiClient.authNotifier.removeListener(listener);
        svc.NotificationService.registerDeviceToken(token);
      }
    }
    ApiClient.authNotifier.addListener(listener);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('af_ZA', null);
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found. Using hardcoded defaults or environment variables.");
  }
  _initFirebase();

  // Pas enige gestoorde bediener-URL (eerste-launch/instellings) toe sodat die
  // app by die korrekte bediener uitkom, selfs al verskil dit van die valbak.
  final storedUrl = await ApiClient.getStoredServerUrl();
  if (storedUrl != null && storedUrl.isNotEmpty) {
    await ApiClient().setBaseUrl(storedUrl);
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

      // Eerste-launch-hek: as geen bediener-URL gestoor is nie, wys eers die
      // bediener-instelling-skerm voordat daar na die aanmeldskerm gegaan word.
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        // Route management
        switch (settings.name) {
          case '/':
            page = const StartupGate();
            break;
          case '/setup':
            page = const ServerConfigPage(firstLaunch: true);
            break;
          case '/home':
            page = const HomePage();
            break;
          case '/location':
            final args = settings.arguments as Map<String, dynamic>?;
            page = LocationPage(autoConfirm: args?['autoConfirm'] ?? false);
            break;
          default:
            page = const StartupGate();
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

/// StartupGate: Kies die eerste skerm. Wanneer die gebruiker nog nie 'n
/// bediener-URL gestoor het nie (eerste keer dat die APK oopgemaak word), word
/// die bediener-instellingskerm gewys sodat hulle by hul eie bediener kan uitkom.
/// Daarna word die normale aanmeldskerm getoon.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final storedUrl = await ApiClient.getStoredServerUrl();
    if (!mounted) return;
    setState(() {
      _needsSetup = storedUrl == null || storedUrl.isEmpty;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }
    return _needsSetup
        ? const ServerConfigPage(firstLaunch: true)
        : const LoginPage();
  }
}
