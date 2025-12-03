/// Captures a complete recording session with all patient responses.
class RecordingSession {
  final String patientId;
  final DateTime sessionTimestamp;
  final List<RecordingEntry> recordings;

  RecordingSession({
    required this.patientId,
    required this.sessionTimestamp,
    required this.recordings,
  });

  Map<String, dynamic> toJson() => {
    'patient_id': patientId,
    'session_timestamp': sessionTimestamp.toIso8601String(),
    'recordings': recordings.map((r) => r.toJson()).toList(),
  };

  factory RecordingSession.fromJson(Map<String, dynamic> json) => RecordingSession(
    patientId: json['patient_id'] as String,
    sessionTimestamp: DateTime.parse(json['session_timestamp'] as String),
    recordings: (json['recordings'] as List)
        .map((r) => RecordingEntry.fromJson(r as Map<String, dynamic>))
        .toList(),
  );

  /// A session is complete when all 5 questions have audio files.
  bool get isComplete =>
      recordings.length == 5 && recordings.every((r) => r.audioFile != null);
}

/// A single recording entry linking a question to its audio response.
class RecordingEntry {
  final int questionNumber;
  final String questionText;
  final String? audioFile;
  final double? durationSeconds;

  RecordingEntry({
    required this.questionNumber,
    required this.questionText,
    this.audioFile,
    this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
    'question_number': questionNumber,
    'question_text': questionText,
    'audio_file': audioFile,
    'duration_seconds': durationSeconds,
  };

  factory RecordingEntry.fromJson(Map<String, dynamic> json) => RecordingEntry(
    questionNumber: json['question_number'] as int,
    questionText: json['question_text'] as String,
    audioFile: json['audio_file'] as String?,
    durationSeconds: json['duration_seconds'] as double?,
  );

  RecordingEntry copyWith({String? audioFile, double? durationSeconds}) =>
      RecordingEntry(
        questionNumber: questionNumber,
        questionText: questionText,
        audioFile: audioFile ?? this.audioFile,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );
}
