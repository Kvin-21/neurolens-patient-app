import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/ml_interface_service.dart';
import '../models/recording_session.dart';
import '../models/question.dart';
import '../widgets/recording_button.dart';
import '../widgets/question_card.dart';
import '../widgets/progress_indicator.dart';
import 'thank_you_screen.dart';

const _primaryPurple = Color(0xFF667eea);
const _accentPurple = Color(0xFF764ba2);

/// Main screen where the patient records answers to each question.
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  late AudioService _audio;
  StorageService? _storage;
  late MLInterfaceService _ml;

  String? _patientId;
  List<Question> _questions = [];
  int _questionIndex = 0;
  List<RecordingEntry> _recordings = [];
  bool _isRecording = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _audio = AudioService();
    _ml = MLInterfaceService();
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

      // Restore partial session if one exists.
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

  // ─────────────────────────────────────────────────────────────────────────
  //  Recording flow
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndSave();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // If re-recording, discard old file first.
      if (_recordings[_questionIndex].audioFile != null) {
        try { await _audio.cancel(); } catch (_) {}
      }
      await _audio.start(_patientId!, _questions[_questionIndex].number);
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) _showToast('Error: $e', Colors.red);
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
      if (mounted) _showToast('Recording saved ✓', Colors.green);
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) _showToast('Error: $e', Colors.red);
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

  // ─────────────────────────────────────────────────────────────────────────
  //  Navigation
  // ─────────────────────────────────────────────────────────────────────────

  void _prev() {
    if (_questionIndex > 0 && !_isRecording) {
      setState(() => _questionIndex--);
    }
  }

  void _next() {
    final recorded = _recordings[_questionIndex].audioFile != null;
    if (_questionIndex < _questions.length - 1 && !_isRecording && recorded) {
      setState(() => _questionIndex++);
    }
  }

  bool get _allComplete => _recordings.every((r) => r.audioFile != null);

  // ─────────────────────────────────────────────────────────────────────────
  //  Finish and submit
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    if (_storage == null) return;

    if (!_allComplete) {
      _showToast('Please complete all 5 questions', Colors.orange);
      return;
    }

    _showSavingDialog();

    try {
      final session = RecordingSession(
        patientId: _patientId!,
        sessionTimestamp: DateTime.now(),
        recordings: _recordings,
      );

      await _storage!.saveSessionManifest(session);
      await _storage!.clearCurrentSession();

      final now = DateTime.now();
      await _storage!.saveLastCompletedTime(now);

      // Fire-and-forget ML processing so we don't block the user.
      Future.delayed(const Duration(milliseconds: 500), () async {
        try { await _ml.sendToMLModel(session); } catch (_) {}
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // close dialog

      final tomorrow = DateTime(now.year, now.month, now.day + 1, 10);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ThankYouScreen(nextSessionTime: tomorrow)),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showToast('Error: $e', Colors.red);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UI helpers
  // ─────────────────────────────────────────────────────────────────────────

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
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2),
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
      builder: (_) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryPurple.withOpacity(0.95), _accentPurple.withOpacity(0.95)],
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, spreadRadius: 10)],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(strokeWidth: 6, valueColor: AlwaysStoppedAnimation<Color>(_primaryPurple)),
                ),
                SizedBox(height: 32),
                Text('Saving recordings...', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryPurple)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

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
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primaryPurple, _accentPurple]),
        ),
        child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primaryPurple, _accentPurple]),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.white)),
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
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primaryPurple, _accentPurple]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Patient: $_patientId',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              QuestionProgressIndicator(
                currentQuestion: _questionIndex + 1,
                completedQuestions: completed,
                totalQuestions: _questions.length,
              ),
              const SizedBox(height: 32),
              QuestionCard(
                questionText: question.text,
                questionNumber: question.number,
                totalQuestions: _questions.length,
              ),
              const SizedBox(height: 40),
              RecordingButton(isRecording: _isRecording, isRecorded: recorded, onPressed: _toggleRecording),
              const SizedBox(height: 16),
              Text(
                _isRecording ? 'Recording...' : recorded ? 'Recorded ✓' : 'Tap to record',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const Spacer(),
              _buildNavButtons(recorded),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
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
                  backgroundColor: Colors.white.withOpacity(0.9),
                  foregroundColor: _primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          if (_questionIndex > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: isLast
                ? ElevatedButton.icon(
                    onPressed: _allComplete && !_isRecording ? _finish : null,
                    icon: const Icon(Icons.check_circle, size: 28),
                    label: const Text('Complete', style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: !_isRecording && recorded ? _next : null,
                    icon: const Icon(Icons.arrow_forward, size: 24),
                    label: const Text('Next', style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}