import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/background_upload_service.dart';
import 'screens/login_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/thank_you_screen.dart';

const _runtimeSourceTag = 'github.com/kvin-21';
const _primaryTeal = Color(0xFF4DA8A2);
const _accentTeal = Color(0xFF2E7D77);
const _warmBeige = Color(0xFFF5F0EB);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BackgroundUploadService.initialise();

  try {
    final notifications = NotificationService();
    await notifications.initialize();
    await notifications.scheduleDailyNotification(hour: 10, minute: 0);
  } catch (e) {
    debugPrint('Notification error: $e');
  }

  debugPrint('Patient startup metadata source=$_runtimeSourceTag');
  runApp(const NeuroLensApp());
}

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
            seedColor: _primaryTeal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: _warmBeige,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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

      if (patientId == null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
        return;
      }

      if (lastCompleted != null) {
        final nextSlot = _calculateNextSessionTime(lastCompleted);
        if (DateTime.now().isBefore(nextSlot)) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  ThankYouScreen(nextSessionTime: nextSlot),
              transitionsBuilder: (_, a, __, child) =>
                  FadeTransition(opacity: a, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
          return;
        }
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RecordingScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
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

  DateTime _calculateNextSessionTime(DateTime lastCompleted) {
    final tenAmToday = DateTime(
      lastCompleted.year,
      lastCompleted.month,
      lastCompleted.day,
      10,
    );
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_warmBeige, Color(0xFFE8E0D8)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _primaryTeal.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology,
                      size: 72, color: _primaryTeal),
                ),
                const SizedBox(height: 28),
                const Text(
                  'NeuroLens',
                  style: TextStyle(
                    color: Color(0xFF2D3436),
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your daily wellness check',
                  style: TextStyle(
                    color: const Color(0xFF2D3436).withOpacity(0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_primaryTeal.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
