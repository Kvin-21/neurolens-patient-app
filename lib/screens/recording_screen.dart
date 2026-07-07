import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../models/recording_session.dart';
import '../models/question.dart';
import '../widgets/recording_button.dart';
import '../widgets/question_card.dart';
import '../widgets/progress_indicator.dart';
import 'thank_you_screen.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _warmBeige = Color(0xFFF5F0EB);
const _darkText = Color(0xFF2D3436);

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  late AudioService _audio;
  StorageService? _storage;

  String? _patientId;
  List<Question> _questions = [];
  int _questionIndex = 0;
  List<RecordingEntry> _recordings = [];
  bool _isRecording = false;
  bool _isLoading = true;
  bool _isQrScanning = false;
  String? _error;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _audio = AudioService();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
    _slideController.forward();
    _initAudio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storage == null) {
      _storage = context.read<StorageService>();
      _loadSession();
    }
  }

  Future<void> _initAudio() async {
    try {
      await _audio.init();
    } catch (e) {
      debugPrint('Error initialising audio: $e');
    }
  }

  @override
  void dispose() {
    _audio.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    if (_storage == null) return;

    try {
      _patientId = await _storage!.getPatientId();

      if (_patientId == null) {
        if (mounted) setState(() { _error = 'No patient ID found'; _isLoading = false; });
        return;
      }

      _questions = _storage!.getDefaultQuestions();

      final saved = await _storage!.getCurrentSession();
      if (saved != null && saved.patientId == _patientId) {
        _recordings = List.from(saved.recordings);
      } else {
        _recordings = _questions
            .map((q) => RecordingEntry(questionNumber: q.number, questionText: q.text))
            .toList();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading session: $e');
      if (mounted) setState(() { _error = 'Error loading: $e'; _isLoading = false; });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndSave();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (_recordings[_questionIndex].audioFile != null) {
        try { await _audio.cancel(); } catch (_) {}
      }
      await _audio.start(_patientId!, _questions[_questionIndex].number);
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) _showToast('Error: $e', Colors.red.shade400);
    }
  }

  Future<void> _stopAndSave() async {
    try {
      final path = await _audio.stop();
      if (path == null) return;

      final duration = await _audio.getAudioDuration(path);
      final updated = _recordings[_questionIndex].copyWith(
        audioFile: path,
        durationSeconds: duration,
      );

      setState(() {
        _recordings[_questionIndex] = updated;
        _isRecording = false;
      });

      await _persistSession();
      if (mounted) _showToast('Recording saved ✓', _primaryTeal);
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) _showToast('Error: $e', Colors.red.shade400);
    }
  }

  Future<void> _persistSession() async {
    if (_patientId == null || _storage == null) return;

    final session = RecordingSession(
      patientId: _patientId!,
      sessionTimestamp: DateTime.now(),
      recordings: _recordings,
    );
    await _storage!.saveSession(session);
  }

  void _animateToQuestion(int newIndex) {
    final goForward = newIndex > _questionIndex;
    _slideController.reset();
    _slideAnim = Tween<Offset>(
      begin: Offset(goForward ? 0.15 : -0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    setState(() => _questionIndex = newIndex);
    _slideController.forward();
  }

  void _prev() {
    if (_questionIndex > 0 && !_isRecording) {
      _animateToQuestion(_questionIndex - 1);
    }
  }

  void _next() {
    final recorded = _recordings[_questionIndex].audioFile != null;
    if (_questionIndex < _questions.length - 1 && !_isRecording && recorded) {
      _animateToQuestion(_questionIndex + 1);
    }
  }

  bool get _allComplete => _recordings.every((r) => r.audioFile != null);

  Future<void> _finish() async {
    if (_storage == null) return;

    if (!_allComplete) {
      _showToast('Please complete all 5 questions', Colors.orange.shade600);
      return;
    }

    _showSavingDialog();

    try {
      final session = RecordingSession(
        patientId: _patientId!,
        sessionTimestamp: DateTime.now(),
        recordings: _recordings,
      );

      final manifestPath = await _storage!.saveSessionManifest(session);
      await _storage!.clearCurrentSession();

      final now = DateTime.now();
      await _storage!.saveLastCompletedTime(now);

      if (!mounted) return;
      Navigator.of(context).pop();

      final tomorrow = DateTime(now.year, now.month, now.day + 1, 10);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ThankYouScreen(
            nextSessionTime: tomorrow,
            sessionManifestPath: manifestPath,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showToast('Error: $e', Colors.red.shade400);
      }
    }
  }

  Future<void> _logout() async {
    if (_storage != null) await _storage!.clearPatientId();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showToast(String msg, Color colour) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, spreadRadius: 1),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  void _showSavingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, spreadRadius: 4)],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(strokeWidth: 5, valueColor: AlwaysStoppedAnimation<Color>(_primaryTeal)),
              ),
              SizedBox(height: 28),
              Text('Saving recordings...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _darkText)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (_error != null) return _buildError();
    return _buildMain();
  }

  Widget _buildLoading() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_warmBeige, Color(0xFFE8E0D8)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 24,
                decoration: BoxDecoration(
                  color: _primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 280,
                height: 120,
                decoration: BoxDecoration(
                  color: _primaryTeal.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryTeal.withOpacity(0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_warmBeige, Color(0xFFE8E0D8)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _darkText.withOpacity(0.7))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMain() {
    final question = _questions[_questionIndex];
    final recorded = _recordings[_questionIndex].audioFile != null;
    final completed = _recordings.map((r) => r.audioFile != null).toList();

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Patient: $_patientId',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _darkText.withOpacity(0.6)),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _isRecording ? null : _showQrScanner,
                          icon: const Icon(Icons.qr_code_scanner),
                          color: _darkText.withOpacity(0.7),
                          tooltip: 'Scan QR code',
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _logout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.logout, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 2),
                                    QuestionProgressIndicator(
                                      currentQuestion: _questionIndex + 1,
                                      completedQuestions: completed,
                                      totalQuestions: _questions.length,
                                    ),
                                    const SizedBox(height: 8),
                                    SlideTransition(
                                      position: _slideAnim,
                                      child: FadeTransition(
                                        opacity: _fadeAnim,
                                        child: QuestionCard(
                                          questionText: question.text,
                                          questionNumber: question.number,
                                          totalQuestions: _questions.length,
                                          imageAssetPath: _questionImageFor(question.number),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            RecordingButton(
                                              isRecording: _isRecording,
                                              isRecorded: recorded,
                                              onPressed: _toggleRecording,
                                              amplitudeStream: _isRecording ? _audio.amplitudeStream : null,
                                            ),
                                            const SizedBox(height: 18),
                                            AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 250),
                                              child: Text(
                                                _isRecording ? 'Recording...' : recorded ? 'Recorded ✓' : 'Tap to record',
                                                key: ValueKey(_isRecording ? 'rec' : recorded ? 'done' : 'idle'),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: _isRecording ? Colors.red.shade400 : recorded ? _primaryTeal : _darkText.withOpacity(0.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildNavButtons(recorded),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _questionImageFor(int number) {
    if (number == 1 || number == 2) {
      return 'assets/images/imgs/Image of an elderly having a jolly good time on the beach!.png';
    }
    if (number == 3 || number == 4) {
      return 'assets/images/imgs/Family gathering in a garden setting.png';
    }
    return null;
  }

  Future<void> _showQrScanner() async {
    if (_isQrScanning) return;
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      _showToast('Camera permission is needed to scan QR codes', Colors.red.shade400);
      return;
    }

    setState(() => _isQrScanning = true);
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _QrScanDialog(),
    );

    if (mounted) {
      setState(() => _isQrScanning = false);
    }

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private key captured successfully.')),
      );
    }
  }

  Widget _buildNavButtons(bool recorded) {
    final isLast = _questionIndex == _questions.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (_questionIndex > 0)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isRecording ? null : _prev,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                  shadowColor: Colors.black.withOpacity(0.08),
                ),
              ),
            ),
          if (_questionIndex > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: isLast
                ? ElevatedButton.icon(
                    onPressed: _allComplete && !_isRecording ? _finish : null,
                    icon: const Icon(Icons.check_circle, size: 22),
                    label: const Text('Complete', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 2,
                      shadowColor: _primaryTeal.withOpacity(0.3),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: !_isRecording && recorded ? _next : null,
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    label: const Text('Next', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 2,
                      shadowColor: _primaryTeal.withOpacity(0.3),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QrScanDialog extends StatefulWidget {
  const _QrScanDialog();

  @override
  State<_QrScanDialog> createState() => _QrScanDialogState();
}

class _QrScanDialogState extends State<_QrScanDialog> {
  late final MobileScannerController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scanning QR Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _darkText),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 210,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        if (capture.barcodes.isNotEmpty) {
                          _complete();
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hold steady to capture the private key',
              textAlign: TextAlign.center,
              style: TextStyle(color: _darkText.withOpacity(0.6)),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}