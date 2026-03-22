import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://10.0.2.2:8002',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  final Dio _dio;

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _sessionKey = 'rider_user_session_json';

  String get realtimeBaseUrl => _dio.options.baseUrl ?? '';

  Future<void> saveSessionUser(Map<String, dynamic> user) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readSessionUser() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSessionUser() async {
    await _storage.delete(key: _sessionKey);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      '/rider/login',
      data: {
        'username': username,
        'password': password,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required List<String> preferences,
  }) async {
    final response = await _dio.post(
      '/rider/signup',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'confirm_password': confirmPassword,
        'preferences': preferences,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchDashboard({
    required int riderId,
  }) async {
    final response = await _dio.get('/rider/dashboard/$riderId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchActiveTrip({
    required int riderId,
  }) async {
    final response = await _dio.get('/rider/active-trip/$riderId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> requestRide({
    required int riderId,
    required String startLoc,
    required String endLoc,
    required String rideType,
    required String timePref,
    required String notes,
  }) async {
    final response = await _dio.post(
      '/rider/request-ride',
      data: {
        'rider_id': riderId,
        'start_loc': startLoc,
        'end_loc': endLoc,
        'ride_type': rideType,
        'time_pref': timePref,
        'notes': notes,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> cancelRide({
    required int tripId,
  }) async {
    final response = await _dio.post(
      '/rider/cancel-ride',
      data: {
        'trip_id': tripId,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchReviews({
  required int riderId,
}) async {
  final response = await _dio.get('/rider/reviews/$riderId');
  return Map<String, dynamic>.from(response.data as Map);
}

Future<Map<String, dynamic>> saveSettings({
  required int riderId,
  required String firstName,
  required String lastName,
  required String email,
  required String phone,
  required List<String> preferences,
}) async {
  final response = await _dio.post(
    '/rider/settings',
    data: {
      'rider_id': riderId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'preferences': preferences,
    },
  );
  return Map<String, dynamic>.from(response.data as Map);
}
}