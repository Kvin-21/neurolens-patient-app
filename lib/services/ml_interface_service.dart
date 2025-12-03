import '../models/recording_session.dart';
import '../models/question.dart';

/// Stub for ML model integration. Teams should implement these methods.
class MLInterfaceService {
  /// Override to fetch questions from your ML backend.
  Future<List<Question>> loadQuestionsFromML() async {
    throw UnimplementedError('ML needs to implement question generation');
  }

  /// Override to send audio for analysis. Returns extracted metrics.
  Future<Map<String, dynamic>> sendToMLModel(RecordingSession session) async {
    throw UnimplementedError('ML needs to implement audio analysis');
  }

  /// Strips sensitive data before any external transmission.
  Map<String, dynamic> preparePrivacySafeData(
    String patientId,
    Map<String, dynamic> mlResults,
  ) {
    return {
      'patient_id': patientId,
      'age_range': '60-70',
      'gender': 'optional',
      'metrics_summary': {
        if (mlResults.containsKey('metrics')) 'metrics': mlResults['metrics'],
        if (mlResults.containsKey('risk_score')) 'risk_score': mlResults['risk_score'],
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
