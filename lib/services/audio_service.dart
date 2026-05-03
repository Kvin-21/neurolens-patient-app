import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles audio recording for patient responses.
class AudioService {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _currentFilePath;
  bool _initialised = false;
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  StreamSubscription<RecordingDisposition>? _progressSubscription;
  double _smoothedAmplitude = 0.0;
  DateTime? _recordingStartTime;
  static const Duration _initializationDelay = Duration(milliseconds: 500);
  static const double _biasOffset = 0.28; // Suppresses baseline to near 0
  static const double _silenceFloor = 0.0;

  static const int _sampleRate = 16000;
  static const int _numChannels = 1;

  bool get isRecording => _isRecording;

  /// Initialises the recorder. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;

    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      _initialised = true;
    } catch (e) {
      debugPrint('Error initialising recorder: $e');
      _initialised = false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  /// Starts recording to a new WAV file.
  Future<void> start(String patientId, int questionNum) async {
    if (!_initialised) await init();
    if (_recorder == null) throw Exception('Recorder not initialised');
    if (_isRecording) throw Exception('Already recording');

    final granted = await requestPermission();
    if (!granted) throw Exception('No microphone permission');

    try {
      if (!_recorder!.isRecording) {
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentFilePath = '${dir.path}/${patientId}_q${questionNum}_$timestamp.wav';
        _recordingStartTime = DateTime.now();
        _resetAmplitudeTracking();

        await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 50));
        await _progressSubscription?.cancel();
        _progressSubscription = _recorder!.onProgress?.listen(_consumeProgress);
        await _recorder!.startRecorder(
          toFile: _currentFilePath,
          codec: Codec.pcm16WAV,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
          bufferSize: 2048,
          audioSource: AudioSource.microphone,
          enableNoiseSuppression: false,
          enableEchoCancellation: false,
        );
        _isRecording = true;
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      rethrow;
    }
  }

  /// Returns a normalised amplitude stream (0.0 – 1.0) from the microphone.
  Stream<double>? get amplitudeStream {
    return _amplitudeController.stream;
  }

  void _resetAmplitudeTracking() {
    _smoothedAmplitude = 0.0;
  }

  void _consumeProgress(RecordingDisposition progress) {
    // Force 0 for first 0.5s to avoid startup spike
    if (_recordingStartTime != null) {
      if (DateTime.now().difference(_recordingStartTime!) < _initializationDelay) {
        _emitAmplitude(0.0);
        return;
      }
    }

    final decibels = progress.decibels ?? 0.0;
    final normalised = _normaliseDecibels(decibels);

    final delta = (normalised - _smoothedAmplitude).abs();
    if (delta >= 0.10) {
      _smoothedAmplitude = normalised;
    } else {
      // Small changes are softened a little so the bar does not jitter.
      _smoothedAmplitude = _smoothedAmplitude * 0.85 + normalised * 0.15;
    }

    _emitAmplitude(_smoothedAmplitude.clamp(_silenceFloor, 1.0));
  }

  double _normaliseDecibels(double decibels) {
    const noiseFloor = -15.0;
    if (decibels < noiseFloor) return 0.0;

    double normalised;
    if (decibels <= 0) {
      normalised = ((decibels - noiseFloor) / (0.0 - noiseFloor)).clamp(0.0, 1.0);
    } else {
      // Lowered dB ceiling from 120 to 85 to stretch normal speech to full range
      normalised = (decibels / 85.0).clamp(0.0, 1.0);
    }

    // Apply bias offset to suppress baseline
    normalised = max(0.0, normalised - _biasOffset);
    // Re-normalize to 0-1 range after bias
    return (normalised / (1.0 - _biasOffset)).clamp(0.0, 1.0);
  }

  void _emitAmplitude(double value) {
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(value);
    }
  }

  /// Stops recording and returns the file path if successful.
  Future<String?> stop() async {
    if (!_isRecording || _recorder == null) return null;

    try {
      await _recorder!.stopRecorder();
      _isRecording = false;
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      _emitAmplitude(0.0);

      if (_currentFilePath != null && await File(_currentFilePath!).exists()) {
        return _currentFilePath;
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancels in-progress recording and deletes the file.
  Future<void> cancel() async {
    if (!_isRecording || _recorder == null) return;

    try {
      await _recorder!.stopRecorder();
      _isRecording = false;
      await _progressSubscription?.cancel();
      _progressSubscription = null;

      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        if (await file.exists()) await file.delete();
      }
      _currentFilePath = null;
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
    }
  }

  /// Estimates duration from file size. WAV headers are 44 bytes.
  Future<double> getAudioDuration(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return 0.0;

      final bytes = await file.length();
      const bytesPerSecond = _sampleRate * _numChannels * 2;
      final duration = (bytes - 44) / bytesPerSecond;
      return duration > 0 ? duration : 0.0;
    } catch (e) {
      debugPrint('Error getting duration: $e');
      return 0.0;
    }
  }

  Future<void> dispose() async {
    try {
      if (_recorder != null && _recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      if (_recorder != null) {
        await _recorder!.closeRecorder();
      }
      _recorder = null;
      _initialised = false;
      await _amplitudeController.close();
    } catch (e) {
      debugPrint('Error disposing recorder: $e');
    }
  }
}