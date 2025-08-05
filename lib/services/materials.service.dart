import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';

class MaterialsService extends ChangeNotifier {
  static final _logger = Logger();

  List<Map<String, dynamic>> _materials = [];
  Map<String, dynamic>? _currentMaterial;
  bool _isLoading = false;
  String? lastError;

  // Getters
  List<Map<String, dynamic>> get materials => _materials;
  Map<String, dynamic>? get currentMaterial => _currentMaterial;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    lastError = error;
    notifyListeners();
  }

  // Fetch all materials
  Future<bool> fetchAllMaterials() async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/materials');

      if (response.statusCode == 200) {
        _materials = List<Map<String, dynamic>>.from(response.data);
        _setLoading(false);
        debugPrint('Fetched ${_materials.length} materials');
        return true;
      } else {
        _setError('Failed to fetch materials: ${response.statusCode}');
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
        _setError('Matériaux introuvables');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Fetch materials error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch materials error', error: e);
      return false;
    }
  }

  // Fetch a single material by ID
  Future<bool> fetchMaterialById(String materialId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/materials/$materialId');

      if (response.statusCode == 200) {
        _currentMaterial = response.data;
        _setLoading(false);
        debugPrint('Fetched material: ${_currentMaterial?['name'] ?? materialId}');
        return true;
      } else {
        _setError('Failed to fetch material: ${response.statusCode}');
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
        _setError('Matériau introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Fetch material by ID error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch material by ID error', error: e);
      return false;
    }
  }

  // Create a new material
  Future<bool> createMaterial(Map<String, dynamic> materialData) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.post('/materials', data: materialData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Add the new material to the list
        _materials.add(response.data);
        _setLoading(false);
        debugPrint('Material created successfully');
        return true;
      } else {
        _setError('Failed to create material: ${response.statusCode}');
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
        _setError('Données de matériau invalides');
      } else if (e.response?.statusCode == 422) {
        _setError('Erreur de validation des données');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Create material error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected create material error', error: e);
      return false;
    }
  }

  // Update an existing material
  Future<bool> updateMaterial(String materialId, Map<String, dynamic> materialData) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.put('/materials/$materialId', data: materialData);

      if (response.statusCode == 200) {
        // Update the material in the list
        final index = _materials.indexWhere((material) => material['id'] == materialId);
        if (index != -1) {
          _materials[index] = response.data;
        }
        
        // Update current material if it's the same one
        if (_currentMaterial?['id'] == materialId) {
          _currentMaterial = response.data;
        }
        
        _setLoading(false);
        debugPrint('Material updated successfully');
        return true;
      } else {
        _setError('Failed to update material: ${response.statusCode}');
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
        _setError('Matériau introuvable');
      } else if (e.response?.statusCode == 400) {
        _setError('Données de matériau invalides');
      } else if (e.response?.statusCode == 422) {
        _setError('Erreur de validation des données');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Update material error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected update material error', error: e);
      return false;
    }
  }

  // Delete a material
  Future<bool> deleteMaterial(String materialId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.delete('/materials/$materialId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove the material from the list
        _materials.removeWhere((material) => material['id'] == materialId);
        
        // Clear current material if it's the deleted one
        if (_currentMaterial?['id'] == materialId) {
          _currentMaterial = null;
        }
        
        _setLoading(false);
        debugPrint('Material deleted successfully');
        return true;
      } else {
        _setError('Failed to delete material: ${response.statusCode}');
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
        _setError('Matériau introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Delete material error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected delete material error', error: e);
      return false;
    }
  }

  // Search materials
  Future<bool> searchMaterials(String query) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/materials/search', queryParameters: {'q': query});

      if (response.statusCode == 200) {
        _materials = List<Map<String, dynamic>>.from(response.data);
        _setLoading(false);
        debugPrint('Found ${_materials.length} materials matching "$query"');
        return true;
      } else {
        _setError('Failed to search materials: ${response.statusCode}');
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

      _logger.e('Search materials error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected search materials error', error: e);
      return false;
    }
  }

  // Clear current material
  void clearCurrentMaterial() {
    _currentMaterial = null;
    notifyListeners();
  }

  // Clear all materials
  void clearMaterials() {
    _materials.clear();
    _currentMaterial = null;
    notifyListeners();
  }
}
