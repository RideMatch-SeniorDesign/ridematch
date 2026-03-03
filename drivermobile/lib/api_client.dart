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
}
