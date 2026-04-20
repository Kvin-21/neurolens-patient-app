import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import 'crypto_service.dart';
import 'ml_interface_service.dart';

const _kUploadTaskName = 'neurolens_upload';

const _kUploadTaskTag = 'neurolens_upload_task';

const _kTokenKey = 'auth_token';
const _kPasswordKey = 'patient_password';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _kUploadTaskName) return true;

    try {
      final manifestPath = inputData?['manifest_path'] as String?;
      if (manifestPath == null) return true;

      const storage = FlutterSecureStorage();
      var token = await storage.read(key: _kTokenKey);
      if (token == null) return false;

      final manifestFile = File(manifestPath);
      if (!await manifestFile.exists()) return true;

      final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final patientId = manifest['patient_id'] as String;
      final recordings = manifest['recordings'] as List<dynamic>;

      final wavPaths = recordings
          .map((r) => r['audio_file'] as String?)
          .where((p) => p != null)
          .cast<String>()
          .toList();

      if (wavPaths.isEmpty) return true;

      final service = MLInterfaceService();

      Future<String> initWithReauth() async {
        try {
          return await service.initSessionUpload(
            patientId: patientId,
            fileCount: wavPaths.length,
            token: token!,
          );
        } catch (e) {
          if (e is DioException && e.response?.statusCode == 401) {
            final password = await storage.read(key: _kPasswordKey);
            if (password == null) rethrow;
            final auth = await service.authenticatePatient(
              patientId: patientId,
              password: password,
            );
            token = auth.token;
            await storage.write(key: _kTokenKey, value: auth.token);
            return await service.initSessionUpload(
              patientId: patientId,
              fileCount: wavPaths.length,
              token: token!,
            );
          }
          rethrow;
        }
      }

      final jobId = await initWithReauth();

      for (var i = 0; i < wavPaths.length; i++) {
        final bytes = await File(wavPaths[i]).readAsBytes();
        final payload = CryptoService.encryptFile(bytes);
        await service.uploadEncryptedChunk(
          jobId: jobId,
          fileIndex: i,
          payload: payload,
          token: token!,
        );
      }

      await service.finalizeSession(jobId: jobId, token: token!);

      await manifestFile.delete();
      return true;
    } catch (e) {
      debugPrint('[NeuroLens] Background upload failed: $e');
      return false;
    }
  });
}

class BackgroundUploadService {
  static const _storage = FlutterSecureStorage();

  static Future<void> initialise() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  static Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _kTokenKey, value: token);
  }

  static Future<void> scheduleUpload(String manifestPath) async {
    await Workmanager().registerOneOffTask(
      _kUploadTaskTag,
      _kUploadTaskName,
      inputData: {'manifest_path': manifestPath},
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
      existingWorkPolicy: ExistingWorkPolicy.append,
    );
  }

  static Future<String?> readAuthToken() => _storage.read(key: _kTokenKey);

  static Future<void> clearAuthToken() => _storage.delete(key: _kTokenKey);
}
