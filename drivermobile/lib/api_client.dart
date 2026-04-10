import "package:dio/dio.dart";

const _apiHost = String.fromEnvironment(
  "API_HOST",
  defaultValue: "10.0.2.2",
);

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: "http://$_apiHost:8002",
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {"Content-Type": "application/json"},
          ),
        );

  final Dio _dio;

  String get realtimeBaseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        "/api/driver/login",
        data: <String, String>{
          "username": username,
          "password": password,
        },
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{"success": false, "error": "Unexpected response from server."};
    } on DioException catch (exc) {
      final data = exc.response?.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        result.putIfAbsent("success", () => false);
        if (result["success"] == false) {
          final err = (result["error"] ?? "").toString().toLowerCase();
          if (err.contains("invalid")) {
            result["error"] = "Invalid username or password.";
          }
        }
        return result;
      }
      final code = exc.response?.statusCode;
      if (code == 401 || code == 400) {
        return <String, dynamic>{
          "success": false,
          "error": "Invalid username or password.",
        };
      }
      if (exc.response == null) {
        return <String, dynamic>{
          "success": false,
          "error": "Could not reach the server. Check your connection.",
        };
      }
      return <String, dynamic>{
        "success": false,
        "error": "Could not sign in. Try again.",
      };
    }
  }

  Future<Map<String, dynamic>> signup({
    required Map<String, String> fields,
    required List<String> preferences,
    required String profilePhotoPath,
  }) async {
    try {
      final formData = FormData();
      for (final entry in fields.entries) {
        formData.fields.add(MapEntry(entry.key, entry.value));
      }
      for (final preference in preferences) {
        formData.fields.add(MapEntry("preferences", preference));
      }
      final normalizedPath = profilePhotoPath.replaceAll("\\", "/");
      final filename = normalizedPath.split("/").last;
      formData.files.add(
        MapEntry(
          "profile_photo",
          await MultipartFile.fromFile(
            profilePhotoPath,
            filename: filename.isNotEmpty ? filename : "profile.jpg",
          ),
        ),
      );
      final response = await _dio.post(
        "/api/driver/signup",
        data: formData,
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{"success": false, "error": "Unexpected response from server."};
    } on DioException catch (exc) {
      final data = exc.response?.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        result.putIfAbsent("success", () => false);
        return result;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadDriverProfilePhoto({
    required int accountId,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap(
        <String, dynamic>{
          "account_id": accountId.toString(),
          "profile_photo": await MultipartFile.fromFile(filePath),
        },
      );
      final response = await _dio.post(
        "/api/driver/profile/photo",
        data: formData,
        options: Options(
          headers: <String, String>{"Content-Type": "multipart/form-data"},
        ),
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (exc) {
      final data = exc.response?.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        result.putIfAbsent("success", () => false);
        return result;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchDriverProfile({
    required int accountId,
  }) async {
    final response = await _dio.get("/api/driver/profile/$accountId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateDriverProfile({
    required int driverId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post("/api/driver/profile/$driverId", data: payload);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (exc) {
      final data = exc.response?.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        result.putIfAbsent("success", () => false);
        return result;
      }
      return <String, dynamic>{
        "success": false,
        "error": "Could not save settings. Try again.",
      };
    }
  }

  Future<Map<String, dynamic>> changeDriverPassword({
    required int driverId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        "/api/driver/change-password",
        data: <String, dynamic>{
          "driver_id": driverId,
          "current_password": currentPassword,
          "new_password": newPassword,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (exc) {
      final data = exc.response?.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        result.putIfAbsent("success", () => false);
        return result;
      }
      return <String, dynamic>{
        "success": false,
        "error": "Could not change password. Try again.",
      };
    }
  }

  Future<Map<String, dynamic>> fetchDashboard({
    required int driverId,
  }) async {
    final response = await _dio.get("/api/driver/dashboard/$driverId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchReviews({
    required int driverId,
  }) async {
    final response = await _dio.get("/api/driver/reviews/$driverId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchPendingReviews({
    required int driverId,
  }) async {
    final response = await _dio.get("/api/driver/pending-reviews/$driverId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchTrips({
    required int driverId,
  }) async {
    final response = await _dio.get("/api/driver/trips/$driverId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchIncome({
    required int driverId,
  }) async {
    final response = await _dio.get("/api/driver/income/$driverId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> submitTripReview({
    required int tripId,
    required int driverId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        "/api/driver/trip/$tripId/review",
        data: <String, dynamic>{
          "driver_id": driverId,
          "rating": rating,
          if (comment != null && comment.isNotEmpty) "comment": comment,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (exc) {
      final data = exc.response?.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        result.putIfAbsent("success", () => false);
        return result;
      }
      return <String, dynamic>{
        "success": false,
        "error": "Could not submit review. Try again.",
      };
    }
  }

  Future<Map<String, dynamic>> fetchDriverDispatch({
    required int accountId,
  }) async {
    try {
      final response = await _dio.get("/api/driver/dispatch/$accountId");
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (exc) {
      final data = exc.response?.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        result.putIfAbsent("success", () => false);
        return result;
      }
      if (exc.response == null) {
        return <String, dynamic>{
          "success": false,
          "error": "Could not reach the server. Check your connection.",
          "trip": null,
          "is_available": false,
        };
      }
      return <String, dynamic>{
        "success": false,
        "error": "Could not load dispatch. Try again.",
        "trip": null,
        "is_available": false,
      };
    }
  }

  Future<Map<String, dynamic>> setDriverAvailability({
    required int driverId,
    required bool isAvailable,
  }) async {
    final response = await _dio.post(
      "/api/driver/availability",
      data: <String, dynamic>{
        "driver_id": driverId,
        "is_available": isAvailable,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateDriverLocation({
    required int driverId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.post(
      "/api/driver/location",
      data: <String, dynamic>{
        "driver_id": driverId,
        "latitude": latitude,
        "longitude": longitude,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchMapsConfig() async {
    final response = await _dio.get("/api/config/maps");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> geocodeAddress({
    required String apiKey,
    required String address,
    double? proximityLatitude,
    double? proximityLongitude,
  }) async {
    final query = <String, dynamic>{
      "text": address,
      "limit": 1,
      "format": "json",
      "apiKey": apiKey,
    };
    if (proximityLatitude != null && proximityLongitude != null) {
      query["bias"] = "proximity:$proximityLongitude,$proximityLatitude";
    }
    final response = await _dio.get(
      "https://api.geoapify.com/v1/geocode/autocomplete",
      queryParameters: query,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchRoute({
    required String apiKey,
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    final response = await _dio.get(
      "https://api.geoapify.com/v1/routing",
      queryParameters: <String, dynamic>{
        "waypoints": "$startLatitude,$startLongitude|$endLatitude,$endLongitude",
        "mode": "drive",
        "details": "route_details",
        "format": "geojson",
        "apiKey": apiKey,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> acceptTrip({
    required int tripId,
    required int driverId,
  }) async {
    final response = await _dio.post(
      "/api/driver/trip/$tripId/accept",
      data: <String, dynamic>{"driver_id": driverId},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> startTrip({
    required int tripId,
    required int driverId,
  }) async {
    final response = await _dio.post(
      "/api/driver/trip/$tripId/start",
      data: <String, dynamic>{"driver_id": driverId},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> completeTrip({
    required int tripId,
    required int driverId,
    double? finalCost,
  }) async {
    final response = await _dio.post(
      "/api/driver/trip/$tripId/complete",
      data: <String, dynamic>{
        "driver_id": driverId,
        ...?finalCost == null ? null : {"final_cost": finalCost},
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
