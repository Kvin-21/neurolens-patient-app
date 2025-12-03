import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recording_session.dart';
import '../models/question.dart';

/// Persists patient data, session state, and audio files locally.
class StorageService {
  static const _keyPatientId = 'patient_id';
  static const _keyCurrentSession = 'current_session';
  static const _keyLastCompleted = 'last_completed_time';

  Future<void> savePatientId(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPatientId, patientId);
  }

  Future<String?> getPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPatientId);
  }

  Future<void> clearPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPatientId);
    await prefs.remove(_keyCurrentSession);
  }

  /// Saves the current in-progress session so it survives app restarts.
  Future<void> saveSession(RecordingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(session.toJson());
    await prefs.setString(_keyCurrentSession, json);
  }

  Future<RecordingSession?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCurrentSession);
    if (json == null) return null;

    try {
      return RecordingSession.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error loading session: $e');
      return null;
    }
  }

  Future<void> clearCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentSession);
  }

  Future<void> saveLastCompletedTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastCompleted, time.toIso8601String());
  }

  Future<DateTime?> getLastCompletedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_keyLastCompleted);
    if (timeStr == null) return null;

    try {
      return DateTime.parse(timeStr);
    } catch (_) {
      return null;
    }
  }

  /// Lists all WAV recordings stored in the app directory.
  Future<List<String>> getRecordingFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(dir.path);

    if (!await folder.exists()) return [];

    final files = await folder
        .list()
        .where((item) => item is File && item.path.endsWith('.wav'))
        .toList();

    return files.map((f) => f.path).toList();
  }

  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  /// Writes a JSON manifest alongside audio files for easy debugging.
  Future<String> saveSessionManifest(RecordingSession session) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'session_${session.patientId}_$timestamp.json';
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(jsonEncode(session.toJson()));

    return filePath;
  }

  /// Hard-coded question set used when ML service isn't connected.
  List<Question> getDefaultQuestions() => [
    Question(number: 1, text: 'How are you feeling today?'),
    Question(number: 2, text: 'What did you have for breakfast this morning?'),
    Question(number: 3, text: 'Tell me about something that made you happy recently.'),
    Question(number: 4, text: 'What activities did you do yesterday?'),
    Question(number: 5, text: 'Describe the weather outside today.'),
  ];
}