import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';

class TemplatesService extends ChangeNotifier {
  static final _logger = Logger();

  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _currentTemplate;
  bool _isLoading = false;
  String? lastError;

  // Getters
  List<Map<String, dynamic>> get templates => _templates;
  Map<String, dynamic>? get currentTemplate => _currentTemplate;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    lastError = error;
    notifyListeners();
  }

  // Fetch all templates
  Future<bool> fetchAllTemplates() async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/templates');

      if (response.statusCode == 200) {
        _templates = List<Map<String, dynamic>>.from(response.data);
        _setLoading(false);
        debugPrint('Fetched ${_templates.length} templates');
        return true;
      } else {
        _setError('Failed to fetch templates: ${response.statusCode}');
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
        _setError('Modèles introuvables');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Fetch templates error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch templates error', error: e);
      return false;
    }
  }

  // Fetch a single template by ID
  Future<bool> fetchTemplateById(String templateId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/templates/$templateId');

      if (response.statusCode == 200) {
        _currentTemplate = response.data;
        _setLoading(false);
        debugPrint('Fetched template: ${_currentTemplate?['name'] ?? templateId}');
        return true;
      } else {
        _setError('Failed to fetch template: ${response.statusCode}');
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
        _setError('Modèle introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Fetch template by ID error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch template by ID error', error: e);
      return false;
    }
  }

  // Create a new template
  Future<bool> createTemplate(Map<String, dynamic> templateData) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.post('/templates', data: templateData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Add the new template to the list
        _templates.add(response.data);
        _setLoading(false);
        debugPrint('Template created successfully');
        return true;
      } else {
        _setError('Failed to create template: ${response.statusCode}');
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
        _setError('Données de modèle invalides');
      } else if (e.response?.statusCode == 422) {
        _setError('Erreur de validation des données');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Create template error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected create template error', error: e);
      return false;
    }
  }

  // Update an existing template
  Future<bool> updateTemplate(String templateId, Map<String, dynamic> templateData) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.put('/templates/$templateId', data: templateData);

      if (response.statusCode == 200) {
        // Update the template in the list
        final index = _templates.indexWhere((template) => template['id'] == templateId);
        if (index != -1) {
          _templates[index] = response.data;
        }
        
        // Update current template if it's the same one
        if (_currentTemplate?['id'] == templateId) {
          _currentTemplate = response.data;
        }
        
        _setLoading(false);
        debugPrint('Template updated successfully');
        return true;
      } else {
        _setError('Failed to update template: ${response.statusCode}');
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
        _setError('Modèle introuvable');
      } else if (e.response?.statusCode == 400) {
        _setError('Données de modèle invalides');
      } else if (e.response?.statusCode == 422) {
        _setError('Erreur de validation des données');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Update template error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected update template error', error: e);
      return false;
    }
  }

  // Delete a template
  Future<bool> deleteTemplate(String templateId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.delete('/templates/$templateId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove the template from the list
        _templates.removeWhere((template) => template['id'] == templateId);
        
        // Clear current template if it's the deleted one
        if (_currentTemplate?['id'] == templateId) {
          _currentTemplate = null;
        }
        
        _setLoading(false);
        debugPrint('Template deleted successfully');
        return true;
      } else {
        _setError('Failed to delete template: ${response.statusCode}');
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
        _setError('Modèle introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Delete template error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected delete template error', error: e);
      return false;
    }
  }

  // Search templates
  Future<bool> searchTemplates(String query) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/templates/search', queryParameters: {'q': query});

      if (response.statusCode == 200) {
        _templates = List<Map<String, dynamic>>.from(response.data);
        _setLoading(false);
        debugPrint('Found ${_templates.length} templates matching "$query"');
        return true;
      } else {
        _setError('Failed to search templates: ${response.statusCode}');
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

      _logger.e('Search templates error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected search templates error', error: e);
      return false;
    }
  }

  // Fetch templates by category
  Future<bool> fetchTemplatesByCategory(String category) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/templates/category/$category');

      if (response.statusCode == 200) {
        _templates = List<Map<String, dynamic>>.from(response.data);
        _setLoading(false);
        debugPrint('Fetched ${_templates.length} templates in category "$category"');
        return true;
      } else {
        _setError('Failed to fetch templates by category: ${response.statusCode}');
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
        _setError('Catégorie introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Fetch templates by category error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch templates by category error', error: e);
      return false;
    }
  }

  // Duplicate a template
  Future<bool> duplicateTemplate(String templateId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.post('/templates/$templateId/duplicate');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Add the duplicated template to the list
        _templates.add(response.data);
        _setLoading(false);
        debugPrint('Template duplicated successfully');
        return true;
      } else {
        _setError('Failed to duplicate template: ${response.statusCode}');
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
        _setError('Modèle introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Duplicate template error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected duplicate template error', error: e);
      return false;
    }
  }

  // Clear current template
  void clearCurrentTemplate() {
    _currentTemplate = null;
    notifyListeners();
  }

  // Clear all templates
  void clearTemplates() {
    _templates.clear();
    _currentTemplate = null;
    notifyListeners();
  }
}
