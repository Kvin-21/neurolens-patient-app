import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImageSummary {
  final int id;
  final String patientId;
  final String date;
  final String summary;

  const ImageSummary({
    required this.id,
    required this.patientId,
    required this.date,
    required this.summary,
  });

  factory ImageSummary.fromJson(Map<String, dynamic> json) {
    return ImageSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      patientId: json['patient_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
    );
  }
}

class NeurolensApiService {
  static const _kBaseUrlKey = 'neurolens_caregiver_base_url';
  static const _kDefaultBaseUrl = 'https://8477-42-60-169-28.ngrok-free.app';

  Dio? _dio;
  String _baseUrl = _kDefaultBaseUrl;

  NeurolensApiService() {
    _initDio(_baseUrl);
  }

  void _initDio(String baseUrl) {
    _baseUrl = baseUrl;
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  String get baseUrl => _baseUrl;

  Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kBaseUrlKey);
    if (saved != null && saved.isNotEmpty) {
      _initDio(saved);
    }
  }

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final normalised = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, normalised);
    _initDio(normalised);
  }

  Future<({String accessToken, String refreshToken})> login({
    required String patientId,
    required String password,
    required String role,
  }) async {
    final response = await _dio!.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'patient_id': patientId,
        'password': password,
        'role': role,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data!;
      return (
        accessToken: data['access_token']?.toString() ?? '',
        refreshToken: data['refresh_token']?.toString() ?? '',
      );
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: 'Login failed with ${response.statusCode}: ${response.data}',
    );
  }
  Future<({String accessToken, String refreshToken})?> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio!.post<Map<String, dynamic>>(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        return (
          accessToken: data['access_token']?.toString() ?? '',
          refreshToken: data['refresh_token']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return null;
  }

  Future<List<ImageSummary>> uploadImages({
    required String token,
    required List<({String filename, Uint8List bytes})> images,
  }) async {
    final formData = FormData();
    for (final image in images) {
      formData.files.add(MapEntry(
        'image',
        MultipartFile.fromBytes(image.bytes, filename: image.filename),
      ));
    }

    final response = await _dio!.post<Map<String, dynamic>>(
      '/upload_patient_images',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if ((response.statusCode == 200 || response.statusCode == 207) &&
        response.data != null) {
      final summaries = response.data!['summaries'] as List<dynamic>? ?? [];
      return summaries
          .whereType<Map<String, dynamic>>()
          .map((s) => ImageSummary.fromJson(s))
          .toList();
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: 'Image upload failed with ${response.statusCode}: ${response.data}',
    );
  }

  Future<List<ImageSummary>> fetchImageSummaries({
    required String token,
  }) async {
    final response = await _dio!.get<Map<String, dynamic>>(
      '/patient_image_summaries',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200 && response.data != null) {
      final summaries = response.data!['image_summaries'] as List<dynamic>? ?? [];
      return summaries
          .whereType<Map<String, dynamic>>()
          .map((s) => ImageSummary.fromJson(s))
          .toList();
    }

    if (response.statusCode == 404) return [];

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: 'Fetch summaries failed with ${response.statusCode}: ${response.data}',
    );
  }
}
