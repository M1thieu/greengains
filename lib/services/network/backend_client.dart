import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants.dart';

export 'api_models.dart';

const String kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://greengains.onrender.com',
);

const String kBackendApiKey = String.fromEnvironment(
  'BACKEND_API_KEY',
  defaultValue: '', // API key must be provided via dart_defines.json or --dart-define
);

/// Thrown by [BackendClient] for any non-2xx response or network error.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class BackendClient {
  BackendClient({String? apiKey})
      : _apiKey = apiKey ?? kBackendApiKey {
    if (_apiKey.isEmpty) {
      throw ArgumentError(
        'Backend API key is required. '
        'Set BACKEND_API_KEY environment variable or pass apiKey parameter.',
      );
    }
  }

  final String _apiKey;

  /// Singleton Dio instance with Firebase auth interceptor.
  /// Adds Bearer token on every request; retries once on 401 with a fresh token.
  static final Dio _dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: kBackendBaseUrl,
      connectTimeout: kApiTimeout,
      receiveTimeout: kApiTimeout,
      headers: {HttpHeaders.acceptHeader: 'application/json'},
    ));

    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await FirebaseAuth.instance.currentUser?.getIdToken();
          if (token != null) {
            options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
          }
        } catch (e) {
          debugPrint('Auth token fetch failed: $e');
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        // On 401, refresh the token once and retry
        if (err.response?.statusCode == 401) {
          try {
            final token = await FirebaseAuth.instance.currentUser
                ?.getIdToken(true); // force refresh
            if (token != null) {
              err.requestOptions.headers[HttpHeaders.authorizationHeader] =
                  'Bearer $token';
              final retried = await _dio.fetch(err.requestOptions);
              return handler.resolve(retried);
            }
          } catch (e) {
            debugPrint('Token refresh failed: $e');
          }
        }
        handler.next(err);
      },
    ));

    return dio;
  }

  Future<void> uploadBatch(
    Map<String, dynamic> payload, {
    bool compress = false,
  }) async {
    final jsonBody = jsonEncode(payload);
    final bodyBytes =
        compress ? gzip.encode(utf8.encode(jsonBody)) : utf8.encode(jsonBody);

    await _dio.post<void>(
      '/upload',
      data: bodyBytes,
      options: Options(
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          'X-API-Key': _apiKey,
          if (compress) HttpHeaders.contentEncodingHeader: 'gzip',
        },
        validateStatus: (status) => status == 202,
      ),
    );
  }

  /// GET request — returns decoded JSON body.
  /// Throws [ApiException] on non-2xx or network failure.
  static Future<Map<String, dynamic>> get(
    String path, {
    Duration timeout = kApiTimeout,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        options: Options(
          receiveTimeout: timeout,
          responseType: ResponseType.json,
        ),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'GET $path failed',
      );
    }
  }

  /// POST request — returns decoded JSON body.
  /// Throws [ApiException] on non-2xx or network failure.
  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = kApiTimeout,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(
          receiveTimeout: timeout,
          responseType: ResponseType.json,
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        ),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'POST $path failed',
      );
    }
  }
}

/// Shared Nominatim reverse-geocoding client.
/// Single instance — used by home screen (territory label) and tile info sheet.
final nominatimClient = Dio(BaseOptions(
  baseUrl: 'https://nominatim.openstreetmap.org',
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 8),
  headers: {'User-Agent': 'GreenGains/1.0 (com.eremat.greengains)'},
));

/// Legacy exception type — kept for any external callers.
/// Prefer [ApiException] for new code.
class BackendException implements Exception {
  BackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'BackendException(statusCode: $statusCode, message: $message)';
}
