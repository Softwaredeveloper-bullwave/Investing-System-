import 'package:dio/dio.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/token_storage.dart';

/// Dio HTTP client for KYC & Payments module.
class KycDioClient {
  KycDioClient._();

  static final KycDioClient instance = KycDioClient._();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode ?? 500;
          final data = error.response?.data;
          final message = _extractErrorMessage(
            data,
            _friendlyDioMessage(error),
          );
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              error: ApiException(status, message),
            ),
          );
        },
      ),
    );

  Dio get dio => _dio;

  static String _extractErrorMessage(dynamic data, String fallback) {
    if (data is! Map) return fallback;

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (detail is List && detail.isNotEmpty) {
      return detail.map((item) => item.toString()).join('. ');
    }

    for (final entry in data.entries) {
      if (entry.key == 'code') continue;
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return '${entry.key}: ${value.first}';
      }
    }

    return fallback;
  }

  static String _friendlyDioMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server is taking too long to respond. Check that Django is running at ${ApiConfig.baseUrl}.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server at ${ApiConfig.baseUrl}. Run: python manage.py runserver 0.0.0.0:8000';
      default:
        return error.message ?? 'Request failed';
    }
  }

  Never _rethrowAsApi(DioException error) {
    if (error.error is ApiException) throw error.error!;
    throw ApiException(
      error.response?.statusCode ?? 500,
      _extractErrorMessage(error.response?.data, _friendlyDioMessage(error)),
    );
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return res.data ?? {};
    } on DioException catch (e) {
      _rethrowAsApi(e);
    }
  }

  Future<Map<String, dynamic>> postJson(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      return res.data ?? {};
    } on DioException catch (e) {
      _rethrowAsApi(e);
    }
  }
}

