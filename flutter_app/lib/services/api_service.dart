import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/insight.dart';
import '../models/alert.dart';
import '../models/brief.dart';

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<List<Insight>> getInsights({
    String? agent,
    String? category,
    String? severity,
    int limit = 50,
    String? since,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (agent != null) params['agent'] = agent;
      if (category != null) params['category'] = category;
      if (severity != null) params['severity'] = severity;
      if (since != null) params['since'] = since;

      final response = await _dio.get('/insights', queryParameters: params);
      final list = response.data as List<dynamic>;
      return list.map((e) => Insight.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('getInsights error: ${e.message}');
      return [];
    }
  }

  Future<List<AlertModel>> getAlerts() async {
    try {
      final response = await _dio.get('/alerts');
      final list = response.data as List<dynamic>;
      return list.map((e) => AlertModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('getAlerts error: ${e.message}');
      return [];
    }
  }

  Future<void> dismissAlert(int id) async {
    try {
      await _dio.post('/alerts/$id/dismiss');
    } on DioException catch (e) {
      debugPrint('dismissAlert error: ${e.message}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAgentStatus() async {
    try {
      final response = await _dio.get('/agents/status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('getAgentStatus error: ${e.message}');
      return {};
    }
  }

  Future<void> triggerAgentRun(String name) async {
    try {
      await _dio.post('/agents/$name/run');
    } on DioException catch (e) {
      debugPrint('triggerAgentRun error: ${e.message}');
      rethrow;
    }
  }

  Future<List<Brief>> getBriefs() async {
    try {
      final response = await _dio.get('/briefs');
      final list = response.data as List<dynamic>;
      return list.map((e) => Brief.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('getBriefs error: ${e.message}');
      return [];
    }
  }

  Future<Map<String, String>> getSettings() async {
    try {
      final response = await _dio.get('/settings');
      final list = response.data as List<dynamic>;
      return {
        for (final item in list)
          (item as Map<String, dynamic>)['key'] as String: item['value'] as String? ?? '',
      };
    } on DioException catch (e) {
      debugPrint('getSettings error: ${e.message}');
      return {};
    }
  }

  Future<void> saveSetting(String key, String value) async {
    try {
      await _dio.post('/settings', data: {'key': key, 'value': value});
    } on DioException catch (e) {
      debugPrint('saveSetting error: ${e.message}');
    }
  }

  Future<String> downloadBrief(int id) async {
    final cacheDir = Directory.systemTemp;
    final filePath = '${cacheDir.path}/brief_$id.docx';

    try {
      await _dio.download(
        '/briefs/$id/download',
        filePath,
        options: Options(responseType: ResponseType.bytes),
      );
      return filePath;
    } on DioException catch (e) {
      debugPrint('downloadBrief error: ${e.message}');
      rethrow;
    }
  }
}
