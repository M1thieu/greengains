import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

const String kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://greengains.onrender.com',
);

const String kBackendApiKey = String.fromEnvironment(
  'BACKEND_API_KEY',
  defaultValue: '', // API key must be provided via dart_defines.json or --dart-define
);

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
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
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

  /// Static GET via Dio — auth header added automatically by interceptor.
  /// Returns an [http.Response]-compatible wrapper so all call sites are unchanged.
  static Future<http.Response> get(
    String path, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final res = await _dio.get<String>(
      path,
      options: Options(
        receiveTimeout: timeout,
        responseType: ResponseType.plain,
      ),
    );
    return http.Response(res.data ?? '', res.statusCode ?? 200);
  }

  /// Static POST via Dio — auth header added automatically by interceptor.
  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final res = await _dio.post<String>(
      path,
      data: jsonEncode(body),
      options: Options(
        receiveTimeout: timeout,
        responseType: ResponseType.plain,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      ),
    );
    return http.Response(res.data ?? '', res.statusCode ?? 200);
  }
}

class BackendException implements Exception {
  BackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'BackendException(statusCode: $statusCode, message: $message)';
}
