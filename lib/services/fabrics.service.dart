import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';

class FabricsService extends ChangeNotifier {
  static final _logger = Logger();

  List<Map<String, dynamic>> _fabrics = [];
  Map<String, dynamic>? _currentFabric;
  bool _isLoading = false;
  String? lastError;

  // Getters
  List<Map<String, dynamic>> get fabrics => _fabrics;
  Map<String, dynamic>? get currentFabric => _currentFabric;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    lastError = error;
    notifyListeners();
  }

  // Fetch all fabrics (with pagination and downsized option)
  Future<bool> fetchAllFabrics({bool downsized = true, int page = 0, int limit = 10}) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await ApiClient.dio.get(
        '/fabric',
        queryParameters: {
          'downsized': downsized,
          'page': page,
          'limit': limit,
        },
      );
      if (response.statusCode == 200) {
        _fabrics = List<Map<String, dynamic>>.from(response.data);
        _setLoading(false);
        debugPrint('Fetched [32m${_fabrics.length}[0m fabrics');
        return true;
      } else {
        _setError('Failed to fetch fabrics: ${response.statusCode}');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      _setLoading(false);
      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Fetch fabrics error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch fabrics error', error: e);
      return false;
    }
  }

  // Fetch a single fabric by ID
  Future<bool> fetchFabricById(String fabricId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await ApiClient.dio.get('/fabric/$fabricId');
      if (response.statusCode == 200) {
        _currentFabric = response.data;
        _setLoading(false);
        debugPrint('Fetched fabric: ${_currentFabric?['name'] ?? fabricId}');
        return true;
      } else {
        _setError('Failed to fetch fabric: ${response.statusCode}');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      _setLoading(false);
      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else if (e.response?.statusCode == 404) {
        _setError('Tissu introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Fetch fabric by ID error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch fabric by ID error', error: e);
      return false;
    }
  }

  // Create a new fabric (with image upload)
  Future<bool> createFabric({required String name, required File imageFile, Map<String, dynamic>? extraData}) async {
    _setLoading(true);
    _setError(null);
    try {
      final formData = FormData.fromMap({
        'name': name,
        'image': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
        ...?extraData,
      });
      final response = await ApiClient.dio.post('/fabric', data: formData);
      if (response.statusCode == 201 || response.statusCode == 200) {
        _fabrics.add(response.data);
        _setLoading(false);
        debugPrint('Fabric created successfully');
        return true;
      } else {
        _setError('Failed to create fabric: ${response.statusCode}');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      _setLoading(false);
      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else if (e.response?.statusCode == 400) {
        _setError('Données de tissu invalides');
      } else if (e.response?.statusCode == 422) {
        _setError('Erreur de validation des données');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Create fabric error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected create fabric error', error: e);
      return false;
    }
  }

  // Update an existing fabric (without image)
  Future<bool> updateFabric(String fabricId, Map<String, dynamic> fabricData) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await ApiClient.dio.put('/fabric/$fabricId', data: fabricData);
      if (response.statusCode == 200) {
        final index = _fabrics.indexWhere((fabric) => fabric['id'] == fabricId);
        if (index != -1) {
          _fabrics[index] = response.data;
        }
        if (_currentFabric?['id'] == fabricId) {
          _currentFabric = response.data;
        }
        _setLoading(false);
        debugPrint('Fabric updated successfully');
        return true;
      } else {
        _setError('Failed to update fabric: ${response.statusCode}');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      _setLoading(false);
      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else if (e.response?.statusCode == 404) {
        _setError('Tissu introuvable');
      } else if (e.response?.statusCode == 400) {
        _setError('Données de tissu invalides');
      } else if (e.response?.statusCode == 422) {
        _setError('Erreur de validation des données');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Update fabric error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected update fabric error', error: e);
      return false;
    }
  }

  // Update fabric with image
  Future<bool> updateFabricWithImage(String fabricId, {required File imageFile, Map<String, dynamic>? updateData}) async {
    _setLoading(true);
    _setError(null);
    try {
      final formData = FormData.fromMap({
        ...?updateData,
        'image': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
      });
      final response = await ApiClient.dio.put('/fabric/$fabricId/with-image', data: formData);
      if (response.statusCode == 200) {
        final index = _fabrics.indexWhere((fabric) => fabric['id'] == fabricId);
        if (index != -1) {
          _fabrics[index] = response.data;
        }
        if (_currentFabric?['id'] == fabricId) {
          _currentFabric = response.data;
        }
        _setLoading(false);
        debugPrint('Fabric updated (with image) successfully');
        return true;
      } else {
        _setError('Failed to update fabric: ${response.statusCode}');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      _setLoading(false);
      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else if (e.response?.statusCode == 404) {
        _setError('Tissu introuvable');
      } else if (e.response?.statusCode == 400) {
        _setError('Données de tissu invalides');
      } else if (e.response?.statusCode == 422) {
        _setError('Erreur de validation des données');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Update fabric with image error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected update fabric with image error', error: e);
      return false;
    }
  }

  // Delete a fabric
  Future<bool> deleteFabric(String fabricId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await ApiClient.dio.delete('/fabric/$fabricId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fabrics.removeWhere((fabric) => fabric['id'] == fabricId);
        if (_currentFabric?['id'] == fabricId) {
          _currentFabric = null;
        }
        _setLoading(false);
        debugPrint('Fabric deleted successfully');
        return true;
      } else {
        _setError('Failed to delete fabric: ${response.statusCode}');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      _setLoading(false);
      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else if (e.response?.statusCode == 404) {
        _setError('Tissu introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Delete fabric error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected delete fabric error', error: e);
      return false;
    }
  }

  // Find by color
  Future<bool> findByColor(String color) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await ApiClient.dio.get('/fabric/color/$color');
      if (response.statusCode == 200) {
        _fabrics = List<Map<String, dynamic>>.from(response.data);
        _setLoading(false);
        debugPrint('Found ${_fabrics.length} fabrics with color $color');
        return true;
      } else {
        _setError('Failed to find fabrics by color: ${response.statusCode}');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      _setLoading(false);
      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Find by color error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected find by color error', error: e);
      return false;
    }
  }

  // Clear current fabric
  void clearCurrentFabric() {
    _currentFabric = null;
    notifyListeners();
  }

  // Clear all fabrics
  void clearFabrics() {
    _fabrics.clear();
    _currentFabric = null;
    notifyListeners();
  }
}
