import 'package:dio/dio.dart';

class ApiClient {
  // Override at build time:
  // flutter build apk --dart-define=API_BASE_URL=https://your-domain/api
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://example.invalid/api',
  );

  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Replace with secure token storage when auth is connected.
          handler.next(options);
        },
        onError: (error, handler) async {
          final method = error.requestOptions.method.toUpperCase();
          final retryable = method == 'GET' &&
              (error.type == DioExceptionType.connectionTimeout ||
               error.type == DioExceptionType.receiveTimeout ||
               error.type == DioExceptionType.connectionError);

          if (retryable) {
            await Future.delayed(const Duration(milliseconds: 600));
            try {
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (_) {}
          }
          handler.next(error);
        },
      ),
    );
  }
}
