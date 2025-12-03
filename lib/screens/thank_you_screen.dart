import 'package:flutter/material.dart';
import 'dart:async';
import 'recording_screen.dart';

const _primaryPurple = Color(0xFF667eea);
const _accentPurple = Color(0xFF764ba2);

/// Shown after completing a session; displays countdown to next available slot.
class ThankYouScreen extends StatefulWidget {
  final DateTime nextSessionTime;

  const ThankYouScreen({super.key, required this.nextSessionTime});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  Timer? _countdownTimer;
  String _remaining = '';

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();

      // Redirect once the window opens.
      final now = DateTime.now();
      if (!now.isBefore(widget.nextSessionTime)) {
        _countdownTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RecordingScreen()),
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryPurple, _accentPurple],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, size: 100, color: Colors.green),
                        const SizedBox(height: 32),
                        const Text(
                          'Thank You!',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _primaryPurple,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your recordings have been saved',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _primaryPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Next Session',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tomorrow at 10:00 AM',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryPurple,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'in $_remaining',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'You will receive a notification',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
    );
  }
}