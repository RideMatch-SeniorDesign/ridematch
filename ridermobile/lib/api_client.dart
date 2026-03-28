import "package:dio/dio.dart";

const _apiHost = String.fromEnvironment(
  "API_HOST",
  defaultValue: "10.0.2.2",
);

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: "http://$_apiHost:8003",
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
            headers: {"Content-Type": "application/json"},
          ),
        );

  final Dio _dio;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        "/api/rider/login",
        data: {"username": username, "password": password},
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
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post("/api/rider/signup", data: payload);
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
      return <String, dynamic>{
        "success": false,
        "error": "Could not create account. Check your connection and try again.",
      };
    }
  }

  Future<Map<String, dynamic>> fetchProfile({
    required int riderId,
  }) async {
    final response = await _dio.get("/api/rider/profile/$riderId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateProfile({
    required int riderId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post("/api/rider/profile/$riderId", data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchDashboard({
    required int riderId,
  }) async {
    final response = await _dio.get("/api/rider/dashboard/$riderId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchReviews({
    required int riderId,
  }) async {
    final response = await _dio.get("/api/rider/reviews/$riderId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchActiveTrip({
    required int riderId,
  }) async {
    final response = await _dio.get("/api/rider/active-trip/$riderId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> requestRide({
    required int riderId,
    required String startLoc,
    required String endLoc,
    required String rideType,
    required String notes,
  }) async {
    final response = await _dio.post(
      "/api/rider/request",
      data: {
        "rider_id": riderId,
        "start_loc": startLoc,
        "end_loc": endLoc,
        "ride_type": rideType,
        "notes": notes,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> cancelRide({
    required int tripId,
    required int riderId,
  }) async {
    final response = await _dio.post(
      "/api/rider/trip/$tripId/cancel",
      data: {"rider_id": riderId},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> changePassword({
    required int riderId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        "/api/rider/change-password",
        data: {
          "rider_id": riderId,
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
        "error": "Could not update password. Try again.",
      };
    }
  }

  Future<Map<String, dynamic>> fetchPendingReviews({
    required int riderId,
  }) async {
    final response = await _dio.get("/api/rider/pending-reviews/$riderId");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> submitTripReview({
    required int tripId,
    required int riderId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        "/api/rider/trip/$tripId/review",
        data: {
          "rider_id": riderId,
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
      "limit": 5,
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

  Future<Map<String, dynamic>> reverseGeocode({
    required String apiKey,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get(
      "https://api.geoapify.com/v1/geocode/reverse",
      queryParameters: {
        "lat": latitude,
        "lon": longitude,
        "format": "json",
        "apiKey": apiKey,
      },
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
      queryParameters: {
        "waypoints": "$startLatitude,$startLongitude|$endLatitude,$endLongitude",
        "mode": "drive",
        "details": "route_details",
        "format": "geojson",
        "apiKey": apiKey,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
