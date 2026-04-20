import 'package:flutter/material.dart';
import 'dart:async';
import '../services/background_upload_service.dart';
import 'recording_screen.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _warmBeige = Color(0xFFF5F0EB);
const _darkText = Color(0xFF2D3436);

class ThankYouScreen extends StatefulWidget {
  final DateTime nextSessionTime;

  final String? sessionManifestPath;

  const ThankYouScreen({
    super.key,
    required this.nextSessionTime,
    this.sessionManifestPath,
  });

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen>
    with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  String _remaining = '';
  bool _uploadScheduled = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _updateRemaining();
    _startCountdown();
    _scheduleUpload();
  }

  Future<void> _scheduleUpload() async {
    final path = widget.sessionManifestPath;
    if (path == null || _uploadScheduled) return;
    _uploadScheduled = true;
    try {
      await BackgroundUploadService.scheduleUpload(path);
    } catch (e) {
      debugPrint('[NeuroLens] Could not schedule upload: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();

      final now = DateTime.now();
      if (!now.isBefore(widget.nextSessionTime)) {
        _countdownTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const RecordingScreen(),
              transitionsBuilder: (_, a, __, child) =>
                  FadeTransition(opacity: a, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      }
    });
  }

  void _updateRemaining() {
    final diff = widget.nextSessionTime.difference(DateTime.now());

    if (diff.isNegative || diff.inSeconds == 0) {
      setState(() => _remaining = 'Ready now!');
      return;
    }

    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;

    if (hours > 0) {
      setState(() => _remaining = '${hours}h ${mins}m');
    } else if (mins > 0) {
      setState(() => _remaining = '${mins}m');
    } else {
      setState(() => _remaining = 'Less than 1m');
    }
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
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _primaryTeal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle, size: 72, color: _primaryTeal),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Thank You!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: _darkText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your responses have been securely sent',
                            style: TextStyle(fontSize: 17, color: _darkText.withOpacity(0.55)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: _primaryTeal.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Next Session',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _darkText.withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Tomorrow at 10:00 AM',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _darkText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'in $_remaining',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: _primaryTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'You will receive a notification',
                            style: TextStyle(fontSize: 13, color: _darkText.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}