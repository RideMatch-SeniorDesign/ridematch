import "package:dio/dio.dart";

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: "http://10.0.2.2:8002",
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
    final response = await _dio.post(
      "/api/driver/login",
      data: <String, String>{
        "username": username,
        "password": password,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
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

  Future<Map<String, dynamic>> fetchDriverDispatch({
    required int accountId,
  }) async {
    final response = await _dio.get("/api/driver/dispatch/$accountId");
    return Map<String, dynamic>.from(response.data as Map);
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
    required double finalCost,
  }) async {
    final response = await _dio.post(
      "/api/driver/trip/$tripId/complete",
      data: <String, dynamic>{
        "driver_id": driverId,
        "final_cost": finalCost,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
