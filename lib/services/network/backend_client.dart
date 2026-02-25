import 'dart:convert';
import 'dart:io';

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
  BackendClient({
    http.Client? client,
    String? baseUrl,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? kBackendBaseUrl).replaceAll(RegExp(r'/+$'), ''),
        _apiKey = apiKey ?? kBackendApiKey {
    if (_apiKey.isEmpty) {
      throw ArgumentError(
        'Backend API key is required. '
        'Set BACKEND_API_KEY environment variable or pass apiKey parameter.',
      );
    }
  }

  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;

  Uri get _uploadUri => Uri.parse('$_baseUrl/upload');

  Uri _analyticsUri(String path, Map<String, dynamic> query) {
    final uri = Uri.parse('$_baseUrl$path');
    return uri.replace(
      queryParameters:
          query.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  /// Adds Firebase ID token to [headers] if the user is signed in.
  /// Silent on failure — anonymous/legacy uploads are allowed.
  static Future<void> _addAuthHeaders(Map<String, String> headers) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('Failed to get auth token: $e');
    }
  }

  Future<void> uploadBatch(
    Map<String, dynamic> payload, {
    bool compress = false,
  }) async {
    final jsonBody = jsonEncode(payload);
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      'X-API-Key': _apiKey,
    };
    final bodyBytes =
        compress ? gzip.encode(utf8.encode(jsonBody)) : utf8.encode(jsonBody);
    if (compress) {
      headers[HttpHeaders.contentEncodingHeader] = 'gzip';
    }
    await _addAuthHeaders(headers);

    final response = await _client.post(
      _uploadUri,
      headers: headers,
      body: bodyBytes,
    );

    if (response.statusCode != 202) {
      throw BackendException(
        'Upload failed with status ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }

  /// Static helper for GET requests (used by daily pot service)
  static Future<http.Response> get(String path) async {
    final uri = Uri.parse('$kBackendBaseUrl$path');
    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    await _addAuthHeaders(headers);
    return await http.get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
  }

  /// Static helper for POST requests (used by daily pot service)
  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$kBackendBaseUrl$path');
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    await _addAuthHeaders(headers);
    return await http.post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
  }

  Future<List<CoverageTile>> fetchCoverage({
    int hours = 24,
    int minDevices = 0,
  }) async {
    final uri = _analyticsUri('/analytics/coverage', {
      'hours': hours,
      'min_devices': minDevices,
    });

    final response = await _client.get(
      uri,
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader: 'application/json',
        'X-API-Key': _apiKey,
      },
    );

    if (response.statusCode != 200) {
      throw BackendException(
        'Coverage request failed with status ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['items'];
    if (items is! List) {
      return const [];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(CoverageTile.fromJson)
        .toList();
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

class CoverageTile {
  const CoverageTile({
    required this.geohash,
    required this.samplesCount,
    required this.deviceEvents,
    required this.deviceHours,
    this.avgLight,
    this.avgAccelRms,
    this.avgGyroRms,
    this.movementScore,
    this.locationShare,
  });

  final String geohash;
  final double samplesCount;
  final double deviceEvents;
  final double deviceHours;
  final double? avgLight;
  final double? avgAccelRms;
  final double? avgGyroRms;
  final double? movementScore;
  final double? locationShare;

  factory CoverageTile.fromJson(Map<String, dynamic> json) {
    double? toNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      return parsed;
    }

    return CoverageTile(
      geohash: json['geohash']?.toString() ?? '',
      samplesCount: toNum(json['samples_count']) ?? 0,
      deviceEvents: toNum(json['device_events']) ?? 0,
      deviceHours: toNum(json['device_hours']) ?? 0,
      avgLight: toNum(json['avg_light']),
      avgAccelRms: toNum(json['avg_accel_rms']),
      avgGyroRms: toNum(json['avg_gyro_rms']),
      movementScore: toNum(json['movement_score']),
      locationShare: toNum(json['location_share']),
    );
  }
}
