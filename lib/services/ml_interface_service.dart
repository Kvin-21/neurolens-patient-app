import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/recording_session.dart';
import '../models/question.dart';
import 'crypto_service.dart';

const _kDefaultApiBaseUrl = 'https://nl-api.yellowriver-4dd2d26f.australiaeast.azurecontainerapps.io';
const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _kDefaultApiBaseUrl);

class MLInterfaceService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _kApiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    validateStatus: (status) => status != null && status < 500,
  ));

  Future<({String token, String? resultKeyB64})> authenticatePatient({
    required String patientId,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/patient/auth',
      data: {'patient_id': patientId, 'password': password},
    );
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data!;
      return (
        token: data['access_token'] as String,
        resultKeyB64: data['result_key_b64'] as String?,
      );
    }
    final body = response.data;
    final detail = body is Map<String, dynamic> ? body['detail']?.toString() : null;
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: detail ?? 'Auth failed with status ${response.statusCode}',
    );
  }

  Future<String> initSessionUpload({
    required String patientId,
    required int fileCount,
    required String token,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/uploads/init',
      queryParameters: {'file_count': fileCount},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    if (data == null || response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload init failed with status ${response.statusCode}: $data');
    }
    return data['job_id'] as String;
  }

  Future<void> uploadEncryptedChunk({
    required String jobId,
    required int fileIndex,
    required EncryptedPayload payload,
    required String token,
  }) async {
    await _dio.put<void>(
      '/v1/uploads/$jobId/file/$fileIndex',
      data: FormData.fromMap({
        'encrypted_blob': MultipartFile.fromBytes(
          base64Decode(payload.encryptedBlobB64),
          filename: 'file_$fileIndex.enc',
        ),
        'nonce_b64': payload.nonceB64,
        'wrapped_key_b64': payload.wrappedKeyB64,
      }),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> finalizeSession({
    required String jobId,
    required String token,
  }) async {
    await _dio.post<void>(
      '/v1/uploads/$jobId/complete',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<Map<String, dynamic>> sendToMLModel(RecordingSession session) async {
    throw UnsupportedError(
      'Use BackgroundUploadService.scheduleUpload instead — '
      'uploads run in a background WorkManager task.',
    );
  }

  Future<List<Question>> loadQuestionsFromML() async {
    return [];
  }

  Map<String, dynamic> preparePrivacySafeData(
    String patientId,
    Map<String, dynamic> mlResults,
  ) {
    return {
      'patient_id': patientId,
      'metrics_summary': {
        if (mlResults.containsKey('metrics')) 'metrics': mlResults['metrics'],
        if (mlResults.containsKey('risk_score')) 'risk_score': mlResults['risk_score'],
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

