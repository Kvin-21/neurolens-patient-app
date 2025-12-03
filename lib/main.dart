import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/thank_you_screen.dart';

// Brand colours used throughout the app.
const _primaryPurple = Color(0xFF667eea);
const _accentPurple = Color(0xFF764ba2);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up daily notification at 10am.
  try {
    final notifications = NotificationService();
    await notifications.initialize();
    await notifications.scheduleDailyNotification(hour: 10, minute: 0);
  } catch (e) {
    debugPrint('Notification error: $e');
  }

  runApp(const NeuroLensApp());
}

/// Root widget for the NeuroLens patient app.
class NeuroLensApp extends StatelessWidget {
  const NeuroLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
      ],
      child: MaterialApp(
        title: 'NeuroLens',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _primaryPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

/// Brief splash shown while we check login state.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      final storage = context.read<StorageService>();
      final patientId = await storage.getPatientId();
      final lastCompleted = await storage.getLastCompletedTime();

      if (!mounted) return;

      // No patient ID means first-time user.
      if (patientId == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // If they completed a session recently, show the thank you screen
      // until the next 10am slot arrives.
      if (lastCompleted != null) {
        final nextSlot = _calculateNextSessionTime(lastCompleted);
        if (DateTime.now().isBefore(nextSlot)) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ThankYouScreen(nextSessionTime: nextSlot)),
          );
          return;
        }
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RecordingScreen()),
      );
    } catch (e) {
      debugPrint('Error in checkLoginStatus: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  /// Works out when the next recording window opens (10am today or tomorrow).
  DateTime _calculateNextSessionTime(DateTime lastCompleted) {
    final tenAmToday = DateTime(
      lastCompleted.year,
      lastCompleted.month,
      lastCompleted.day,
      10,
    );
    // If 10am has already passed, bump to tomorrow.
    return tenAmToday.isBefore(lastCompleted)
        ? tenAmToday.add(const Duration(days: 1))
        : tenAmToday;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryPurple, _accentPurple],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, size: 80, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'NeuroLens',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}