import 'dart:io';
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

        await _recorder!.startRecorder(
          toFile: _currentFilePath,
          codec: Codec.pcm16WAV,
          sampleRate: 44100,
        );
        _isRecording = true;
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      rethrow;
    }
  }

  /// Stops recording and returns the file path if successful.
  Future<String?> stop() async {
    if (!_isRecording || _recorder == null) return null;

    try {
      await _recorder!.stopRecorder();
      _isRecording = false;

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
      // 44100 Hz * 2 bytes * 2 channels = 176400 bytes per second
      final duration = (bytes - 44) / 176400.0;
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
      if (_recorder != null) {
        await _recorder!.closeRecorder();
      }
      _recorder = null;
      _initialised = false;
    } catch (e) {
      debugPrint('Error disposing recorder: $e');
    }
  }
}