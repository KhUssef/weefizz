import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  final _storage = FlutterSecureStorage();
  static final _logger = Logger();

  String? accessToken;
  String? refreshToken;
  String? username;
  bool _connected = false;
  String? lastError;

  // Getter for connected state
  bool get connected => _connected;

  // Global navigation key to access navigation from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Method to update connected state and notify listeners
  void _setConnected(bool value) {
    _connected = value;
    notifyListeners();
    
    // Redirect to login if disconnected
    if (!value) {
      _redirectToLogin();
    }
  }

  AuthService() {
    _hydrateFromStorage();
  }

  Future<void> _hydrateFromStorage() async {
    try {
      accessToken = await _storage.read(key: 'accessToken');
      refreshToken = await _storage.read(key: 'refreshToken');
      username = await _storage.read(key: 'username');
      _setConnected(accessToken != null);
    } catch (e) {
      _logger.w('Failed to hydrate auth from storage', error: e);
    }
  }

  // Method to redirect to login page
  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login', 
        (route) => false,
      );
    });
  }

  Future<void> login(String email, String password) async {
    lastError = null;

    try {
      final response = await ApiClient.dio.post('/auth',
        data: {'email': email, 'password': password},
      );

      accessToken = response.data['access_token'];
      refreshToken = response.data['refresh_token'];
      username = response.data['username'];

      await _storage.write(key: 'accessToken', value: accessToken);
      await _storage.write(key: 'refreshToken', value: refreshToken);
      if (username != null) {
        await _storage.write(key: 'username', value: username);
      }
      _setConnected(true);

      debugPrint('Login success');
    } on DioException catch (e) {
      _setConnected(false);

      if (e.response?.statusCode == 401) {
        lastError = 'Email ou mot de passe incorrect';
      } else if (e.response?.statusCode == 400) {
        lastError = 'Données de connexion invalides';
      } else {
        lastError = 'Erreur: ${e.response?.statusCode ?? 'réseau'}';
      }

      _logger.e('Login error', error: e);
    } catch (e) {
      _setConnected(false);
      lastError = 'Erreur de réseau.';
      _logger.e('Unexpected login error', error: e);
    }
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
  username = null;
    lastError = null;

    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  await _storage.delete(key: 'username');

    _setConnected(false);
    debugPrint('Logout complete');
  }

  // Method to handle token refresh failures
  void handleTokenRefreshFailure() {
    _logger.w('Token refresh failed, logging out user');
    logout();
  }

  static Future<bool> signup(String email, String password, String username) async {
    try {
      final response = await ApiClient.dio.post('/auth/signup',
        data: {'email': email, 'password': password, 'username': username},
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      _logger.e('Signup failed', error: e.response?.data ?? e.message);
      return false;
    }
  }

  Future<bool> sayhey() async {
    final token = await _storage.read(key: 'accessToken');
    
    if (token == null) {
      _logger.e('No access token found');
      return false;
    }

    try {
      final response = await ApiClient.dio.post('/auth/hey',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      debugPrint('Say hey response: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('Say hey response: ${response.data}');
        return true;
      } else {
        _logger.e('Say hey failed', error: response.data);
        return false;
      }
    } on DioException catch (e) {
      _logger.e('Say hey error', error: e);
      return false;
    }
  }
}