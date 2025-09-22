import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  static late Dio dio;
  static Dio? _refreshDio; // Make it nullable and initialize properly
  static final _storage = FlutterSecureStorage();
  static bool _isRefreshing = false; // Prevent multiple simultaneous refresh attempts

  static void initialize() {
    // Load config from .env with sensible defaults
    final String baseUrl = dotenv.env['API_BASE_URL']?.trim() ?? 'http://192.168.1.113:3000';
    final int connectMs = int.tryParse((dotenv.env['CONNECT_TIMEOUT_MS'] ?? '').trim()).orNull ?? 10000;
    final int receiveMs = int.tryParse((dotenv.env['RECEIVE_TIMEOUT_MS'] ?? '').trim()).orNull ?? 10000;

    // Main dio instance with interceptors
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: connectMs),
      receiveTimeout: Duration(milliseconds: receiveMs),
    ));

    // Separate dio instance for token refresh (no interceptors)
    _refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: connectMs),
      receiveTimeout: Duration(milliseconds: receiveMs),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'accessToken');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },

      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;

        // Only retry if it's a 401 Unauthorized and hasn't already retried
        if (statusCode == 401 && error.requestOptions.headers['x-retry'] != 'true') {
          debugPrint('Got 401, attempting token refresh...');
          
          final refreshed = await _refreshToken();

          if (refreshed) {
            debugPrint('Token refreshed successfully, retrying original request');
            final newToken = await _storage.read(key: 'accessToken');

            // Create new request options with the new token
            final retryOptions = error.requestOptions.copyWith(
              headers: Map.from(error.requestOptions.headers)
                ..['Authorization'] = 'Bearer $newToken'
                ..['x-retry'] = 'true', // Mark this request as retried
            );

            try {
              final retryResponse = await dio.fetch(retryOptions);
              return handler.resolve(retryResponse);
            } catch (retryError) {
              debugPrint('Retry after token refresh failed: $retryError');
              return handler.next(error);
            }
          } else {
            // Token refresh failed, clear tokens and redirect to login
            debugPrint('Token refresh failed, clearing tokens');
            await _clearTokens();
            return handler.next(error);
          }
        }

        // If not a 401 or already retried, don't retry again
        return handler.next(error);
      },
    ));
  }

  static Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      debugPrint('Token refresh already in progress, waiting...');
      await _waitForRefresh();
      return await _storage.read(key: 'accessToken') != null;
    }
    
    _isRefreshing = true;
    
    try {
      final refreshToken = await _storage.read(key: 'refreshToken');
      if (refreshToken == null) {
        debugPrint('No refresh token available');
        return false;
      }

      debugPrint('Attempting to refresh token...');
      
      // Create a fresh dio instance if needed, using current env config
      _refreshDio ??= Dio(BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL']?.trim() ?? 'http://192.168.1.113:3000',
        connectTimeout: Duration(milliseconds: int.tryParse((dotenv.env['CONNECT_TIMEOUT_MS'] ?? '').trim()).orNull ?? 10000),
        receiveTimeout: Duration(milliseconds: int.tryParse((dotenv.env['RECEIVE_TIMEOUT_MS'] ?? '').trim()).orNull ?? 10000),
      ));
      
      // Use the separate dio instance for token refresh
      final response = await _refreshDio!.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      debugPrint('Refresh response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token']; // If your API returns a new refresh token
        
        if (newAccessToken == null) {
          debugPrint('No access token in refresh response');
          return false;
        }
        
        await _storage.write(key: 'accessToken', value: newAccessToken);
        
        // Update refresh token if provided
        if (newRefreshToken != null) {
          await _storage.write(key: 'refreshToken', value: newRefreshToken);
        }
        
        debugPrint('Access token refreshed successfully');
        return true;
      } else {
        debugPrint('Token refresh failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  static Future<void> _waitForRefresh() async {
    while (_isRefreshing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static Future<void> _clearTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }

  // Provide auth headers for non-Dio HTTP loads (e.g., Image.network)
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  // Method to check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'accessToken');
    return token != null;
  }

  // Method to manually clear tokens (for logout)
  static Future<void> logout() async {
    await _clearTokens();
  }
}

extension _IntParsingOrNull on int? {
  int? get orNull => this;
}