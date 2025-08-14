import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class FabricsService extends ChangeNotifier {
  static final _logger = Logger();

  List<Map<String, dynamic>> _fabrics = [];
  List<Map<String, dynamic>> _featuredFabrics = [];
  // Dedicated: Home full-size items
  List<Map<String, dynamic>> _homeFullFabrics = [];
  Map<String, dynamic>? _currentFabric;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingFeatured = false;
  bool _isLoadingHomeFull = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? lastError;
  String? featuredError;
  String? homeFullError;
  // Persist local favorite states across refreshes
  final Map<String, bool> _favoriteOverrides = {};

  Map<String, dynamic> _normalizeFabric(Map<String, dynamic> m) {
    final r = Map<String, dynamic>.from(m);
    // Map backend 'desc' to 'description' if needed
    if ((r['description'] == null || (r['description'] as String?)?.isEmpty == true) && r['desc'] != null) {
      r['description'] = r['desc'];
    }
    // Normalize image field
    String? img = r['imageUrl'] as String?;
    img ??= r['originalImageUrl'] as String?;
    img ??= r['iconPath'] as String?;
    img ??= r['filePath'] as String?;
    img ??= r['image'] as String?;
    if (img != null && img.isNotEmpty) {
      r['imageUrl'] = img;
    }
    return r;
  }

  // Getters
  List<Map<String, dynamic>> get fabrics => _fabrics;
  List<Map<String, dynamic>> get featuredFabrics => _featuredFabrics;
  List<Map<String, dynamic>> get homeFullFabrics => _homeFullFabrics;
  Map<String, dynamic>? get currentFabric => _currentFabric;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingFeatured => _isLoadingFeatured;
  bool get isLoadingHomeFull => _isLoadingHomeFull;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    lastError = error;
    notifyListeners();
  }

  // Featured: fetch top N full-size images for Home (downsized=false)
  Future<bool> fetchFeaturedFabrics({int limit = 5, bool downsized = false}) async {
    featuredError = null;
    _isLoadingFeatured = true; notifyListeners();
    try {
      final response = await ApiClient.dio.get('/fabric', queryParameters: {
        'limit': limit,
        'downsized': downsized,
      });
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(response.data).map(_normalizeFabric).toList();
        await _prefetchAndCacheImages(list);
        // Apply favorite overrides
        for (final m in list) {
          final id = m['id'] as String?;
          if (id != null && _favoriteOverrides.containsKey(id)) {
            m['favorited'] = _favoriteOverrides[id];
          }
        }
        _featuredFabrics = list;
        _isLoadingFeatured = false; notifyListeners();
        return true;
      } else {
        featuredError = 'Failed to fetch featured fabrics: ${response.statusCode}';
        _isLoadingFeatured = false; notifyListeners();
        return false;
      }
    } on DioException catch (e) {
      featuredError = 'Erreur: ${e.response?.statusCode ?? 'réseau'}';
      _isLoadingFeatured = false; notifyListeners();
      _logger.e('Fetch featured fabrics error', error: e);
      return false;
    } catch (e) {
      featuredError = 'Erreur de réseau';
      _isLoadingFeatured = false; notifyListeners();
      _logger.e('Unexpected fetch featured fabrics error', error: e);
      return false;
    }
  }

  // Home: fetch top N strictly full-size originals; don't let downsized/cached fields interfere
  Future<bool> fetchHomeFullFabrics({int limit = 5}) async {
    homeFullError = null;
    _isLoadingHomeFull = true; notifyListeners();
    try {
      final response = await ApiClient.dio.get('/fabric', queryParameters: {
        'limit': limit,
        'downsized': false,
      });
      if (response.statusCode == 200) {
        final rawList = List<Map<String, dynamic>>.from(response.data);
        final list = <Map<String, dynamic>>[];
        for (final m in rawList) {
          final norm = _normalizeFabric(m);
          // Prefer explicit original sources; if absent, fall back to imageUrl (downsized=false means original)
          String? orig = norm['originalImageUrl'] as String?;
          orig ??= norm['filePath'] as String?;
          orig ??= norm['image'] as String?;
          orig ??= norm['imageUrl'] as String?; // final fallback when server only returns imageUrl
          // Compute absolute full-size URL if present
          final absOrig = _absoluteImageUrl(orig);
          if (absOrig.isNotEmpty) {
            norm['absoluteOriginalImageUrl'] = absOrig;
          }
          // Keep a dedicated field used by Home; ensure absolute URL when falling back
          norm['homeImageUrl'] = absOrig.isNotEmpty ? absOrig : _absoluteImageUrl(orig);
          list.add(norm);
        }
        // Apply favorite overrides
        for (final m in list) {
          final id = m['id'] as String?;
          if (id != null && _favoriteOverrides.containsKey(id)) {
            m['favorited'] = _favoriteOverrides[id];
          }
        }
        _homeFullFabrics = list;
        _isLoadingHomeFull = false; notifyListeners();
        return true;
      } else {
        homeFullError = 'Failed to fetch home full fabrics: ${response.statusCode}';
        _isLoadingHomeFull = false; notifyListeners();
        return false;
      }
    } on DioException catch (e) {
      homeFullError = 'Erreur: ${e.response?.statusCode ?? 'réseau'}';
      _isLoadingHomeFull = false; notifyListeners();
      _logger.e('Fetch home full fabrics error', error: e);
      return false;
    } catch (e) {
      homeFullError = 'Erreur de réseau';
      _isLoadingHomeFull = false; notifyListeners();
      _logger.e('Unexpected fetch home full fabrics error', error: e);
      return false;
    }
  }

  String _absoluteImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    final base = ApiClient.dio.options.baseUrl;
    // Ensure no double slashes
    if (base.endsWith('/') && imageUrl.startsWith('/')) {
      return base.substring(0, base.length - 1) + imageUrl;
    }
    return base + imageUrl;
  }

  Future<void> _prefetchAndCacheImages(List<Map<String, dynamic>> items) async {
    for (final m in items) {
      final abs = _absoluteImageUrl(m['imageUrl'] as String?);
      if (abs.isEmpty) continue;
      try {
        final file = await DefaultCacheManager().getSingleFile(abs);
        m['cachedImagePath'] = file.path; // store local cached file path
        m['absoluteImageUrl'] = abs; // keep absolute URL too
      } catch (e) {
        _logger.w('Failed to cache image for ${m['id']}: $e');
      }
    }
  }

  // Internal: fetch a specific page
  Future<bool> _fetchFabricsPage(int page) async {
    try {
      final response = await ApiClient.dio.get('/fabric', queryParameters: {
        'page': page,
      });

      if (response.statusCode == 200) {
  final list = List<Map<String, dynamic>>.from(response.data).map(_normalizeFabric).toList();
        await _prefetchAndCacheImages(list);

        List<Map<String, dynamic>> merged;
        if (page == 1) {
          merged = list;
        } else {
          merged = [..._fabrics, ...list];
        }

        // Apply persistent favorite overrides
        for (final m in merged) {
          final id = m['id'] as String?;
          if (id != null && _favoriteOverrides.containsKey(id)) {
            m['favorited'] = _favoriteOverrides[id];
          }
        }

        _fabrics = merged;

        _currentPage = page;
        _hasMore = list.isNotEmpty;
        debugPrint('Fetched fabrics page $page; total: ${_fabrics.length}');
        return true;
      } else {
        _setError('Failed to fetch fabrics: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      if (_isLoading) _setLoading(false);
      _isLoadingMore = false; notifyListeners();

      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else if (e.response?.statusCode == 404) {
        _setError('Tissus introuvables');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Fetch fabrics page error', error: e);
      return false;
    } catch (e) {
      if (_isLoading) _setLoading(false);
      _isLoadingMore = false; notifyListeners();
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch fabrics error', error: e);
      return false;
    }
  }

  // Public: first page (refresh)
  Future<bool> fetchAllFabrics() async {
    _setError(null);
    _hasMore = true;
    _currentPage = 0;
  // Drop current list immediately
  clearFabrics();
  // Do not clear global caches here to avoid interfering with Home full-size caching
    _setLoading(true);
    final ok = await _fetchFabricsPage(0);
    _setLoading(false);
    return ok;
  }

  // Public: load next page
  Future<bool> loadMoreFabrics() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return false;
    _isLoadingMore = true; notifyListeners();
    final next = _currentPage + 1;
    final ok = await _fetchFabricsPage(next);
    _isLoadingMore = false; notifyListeners();
    return ok;
  }

  // Fetch a single fabric by ID
  Future<bool> fetchFabricById(String fabricId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/fabric/$fabricId');

      if (response.statusCode == 200) {
  _currentFabric = _normalizeFabric(Map<String, dynamic>.from(response.data));
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
        _setError('Matériau introuvable');
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

  // Create a new fabric (without image)
  Future<bool> createFabric(Map<String, dynamic> fabricData) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.post('/fabric', data: fabricData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Add the new fabric to the list (normalized)
        final created = _normalizeFabric(Map<String, dynamic>.from(response.data));
        // best-effort cache
        await _prefetchAndCacheImages([created]);
        _fabrics.add(created);
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
        _setError('Données de matériau invalides');
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

  // Update an existing fabric
  Future<bool> updateFabric(String fabricId, Map<String, dynamic> fabricData) async {
    _setLoading(true);
    _setError(null);

    try {
      // Send both 'description' and 'desc' to be compatible with backend variations
      final payload = Map<String, dynamic>.from(fabricData);
      final response = await ApiClient.dio.put('/fabric/$fabricId', data: payload);

      if (response.statusCode == 200) {
        // Merge server response with existing item to avoid losing local fields
        final index = _fabrics.indexWhere((fabric) => fabric['id'] == fabricId);
  final Map<String, dynamic> updated = _normalizeFabric(Map<String, dynamic>.from(response.data ?? {}));

        // If backend omits some simple fields, backfill from request payload
        for (final key in const ['title', 'description', 'type', 'color']) {
          if (!updated.containsKey(key) && fabricData[key] != null) {
            updated[key] = fabricData[key];
          }
        }

        // Preserve favorited: prefer server, else local override, else previous value
        if (!updated.containsKey('favorited')) {
          if (_favoriteOverrides.containsKey(fabricId)) {
            updated['favorited'] = _favoriteOverrides[fabricId];
          } else {
            final prevFav = index != -1 ? _fabrics[index]['favorited'] : _currentFabric?['favorited'];
            if (prevFav != null) updated['favorited'] = prevFav;
          }
        } else {
          // Keep overrides in sync with any explicit server change
          final fav = updated['favorited'];
          if (fav is bool) _favoriteOverrides[fabricId] = fav;
        }

        // Keep cached image helpers unless backend provides a new imageUrl
        final abs = _absoluteImageUrl(updated['imageUrl'] as String?);
        if (abs.isNotEmpty) {
          updated['absoluteImageUrl'] = abs;
          // do not recache here; keep existing cachedImagePath unless missing
          if (updated['cachedImagePath'] == null || (updated['cachedImagePath'] as String?)?.isEmpty == true) {
            try {
              final file = await DefaultCacheManager().getSingleFile(abs);
              updated['cachedImagePath'] = file.path;
            } catch (_) {}
          }
        }

        if (index != -1) {
          _fabrics[index] = {
            ..._fabrics[index],
            ...updated,
          };
        }

        if (_currentFabric?['id'] == fabricId) {
          _currentFabric = {
            ...?_currentFabric,
            ...updated,
          };
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
        _setError('Matériau introuvable');
      } else if (e.response?.statusCode == 400) {
        _setError('Données de matériau invalides');
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

  // Update a fabric with image (icon) using multipart PUT /fabric/:id/with-image
  Future<bool> updateFabricWithImage(String fabricId, Map<String, dynamic> fabricData, String imageFilePath) async {
    _setLoading(true);
    _setError(null);

    try {
      final map = Map<String, dynamic>.from(fabricData);
      if (fabricData.containsKey('description')) {
        map['desc'] = fabricData['description'];
      }
      final formData = FormData.fromMap({
        ...map,
        // Common NestJS pattern is FileInterceptor('file')
        'file': await MultipartFile.fromFile(imageFilePath, filename: imageFilePath.split('/').last),
      });

      final response = await ApiClient.dio.put('/fabric/$fabricId/with-image', data: formData);

      if (response.statusCode == 200) {
  final updated = _normalizeFabric(Map<String, dynamic>.from(response.data ?? {}));
        // Backfill simple fields from request if omitted
        for (final key in const ['title', 'description', 'type', 'color']) {
          if (!updated.containsKey(key) && fabricData[key] != null) {
            updated[key] = fabricData[key];
          }
        }
        // Enrich with caching
        final abs = _absoluteImageUrl(updated['imageUrl'] as String?);
        updated['absoluteImageUrl'] = abs;
        if (abs.isNotEmpty) {
          try {
            final file = await DefaultCacheManager().getSingleFile(abs);
            updated['cachedImagePath'] = file.path;
          } catch (_) {}
        }

        // Preserve favorited: prefer server, else local override, else previous value
        final index = _fabrics.indexWhere((fabric) => fabric['id'] == fabricId);
        if (!updated.containsKey('favorited')) {
          if (_favoriteOverrides.containsKey(fabricId)) {
            updated['favorited'] = _favoriteOverrides[fabricId];
          } else {
            final prevFav = index != -1 ? _fabrics[index]['favorited'] : _currentFabric?['favorited'];
            if (prevFav != null) updated['favorited'] = prevFav;
          }
        } else {
          final fav = updated['favorited'];
          if (fav is bool) _favoriteOverrides[fabricId] = fav;
        }
        if (index != -1) {
          _fabrics[index] = {
            ..._fabrics[index],
            ...updated,
          };
        }
        if (_currentFabric?['id'] == fabricId) {
          _currentFabric = {
            ...?_currentFabric,
            ...updated,
          };
        }

        _setLoading(false);
        notifyListeners();
        debugPrint('Fabric updated with image successfully');
        return true;
      } else {
        _setError('Failed to update fabric with image: ${response.statusCode}');
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
        _setError('Données invalides');
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
        // Remove the fabric from the list
        _fabrics.removeWhere((fabric) => fabric['id'] == fabricId);
  _favoriteOverrides.remove(fabricId);
        
        // Clear current fabric if it's the deleted one
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
        _setError('Matériau introuvable');
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

  // Search fabrics
  Future<bool> searchFabrics(String query) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.dio.get('/fabric/search', queryParameters: {'q': query});

      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(response.data).map(_normalizeFabric).toList();
        await _prefetchAndCacheImages(list);
        // Apply persistent favorite overrides
        for (final m in list) {
          final id = m['id'] as String?;
          if (id != null && _favoriteOverrides.containsKey(id)) {
            m['favorited'] = _favoriteOverrides[id];
          }
        }
        _fabrics = list;
        _setLoading(false);
        debugPrint('Found ${_fabrics.length} fabrics matching "$query"');
        return true;
      } else {
        _setError('Failed to search fabrics: ${response.statusCode}');
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

      _logger.e('Search fabrics error', error: e);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Erreur de réseau');
      _logger.e('Unexpected search fabrics error', error: e);
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

  // Toggle favorite state (optimistic update, uses PUT /fabric/:id)
  Future<bool> toggleFavorite(String fabricId, bool favorited) async {
    _setError(null);
    // optimistic update
    final idx = _fabrics.indexWhere((f) => f['id'] == fabricId);
    bool? previous;
    if (idx != -1) {
      previous = _fabrics[idx]['favorited'] as bool?;
      _fabrics[idx]['favorited'] = favorited;
    }
    if (_currentFabric?['id'] == fabricId) {
      previous ??= _currentFabric!['favorited'] as bool?;
      _currentFabric!['favorited'] = favorited;
    }
  // Persist override so refetch won't reset it
  _favoriteOverrides[fabricId] = favorited;
    notifyListeners();

    try {
      final response = await ApiClient.dio.put('/fabric/$fabricId', data: {
        'favorited': favorited,
      });

      if (response.statusCode == 200) {
  final updated = _normalizeFabric(Map<String, dynamic>.from(response.data ?? {}));
        // merge cache paths if missing
        final abs = _absoluteImageUrl(updated['imageUrl'] as String?);
        updated['absoluteImageUrl'] = updated['absoluteImageUrl'] ?? abs;
        // ensure favorited stays consistent with requested state if backend omits/mismatches
        if (updated['favorited'] == null || updated['favorited'] != favorited) {
          updated['favorited'] = favorited;
        }
        if ((updated['cachedImagePath'] == null || (updated['cachedImagePath'] as String?)?.isEmpty == true) && abs.isNotEmpty) {
          try {
            final file = await DefaultCacheManager().getSingleFile(abs);
            updated['cachedImagePath'] = file.path;
          } catch (_) {}
        }

        if (idx != -1) {
          _fabrics[idx] = {
            ..._fabrics[idx],
            ...updated,
          };
        }
        if (_currentFabric?['id'] == fabricId) {
          _currentFabric = {
            ...?_currentFabric,
            ...updated,
          };
        }
        notifyListeners();
        return true;
      } else {
        // revert
        if (idx != -1 && previous != null) {
          _fabrics[idx]['favorited'] = previous;
        }
        if (_currentFabric?['id'] == fabricId && previous != null) {
          _currentFabric!['favorited'] = previous;
        }
        notifyListeners();
        _setError('Échec de la mise à jour du favori: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      // revert
      if (idx != -1 && previous != null) {
        _fabrics[idx]['favorited'] = previous;
      }
      if (_currentFabric?['id'] == fabricId && previous != null) {
        _currentFabric!['favorited'] = previous;
      }
      notifyListeners();

      if (e.response?.statusCode == 401) {
        _setError('Non autorisé - veuillez vous reconnecter');
      } else if (e.response?.statusCode == 403) {
        _setError('Accès interdit');
      } else if (e.response?.statusCode == 404) {
        _setError('Tissu introuvable');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }
      _logger.e('Toggle favorite error', error: e);
      return false;
    } catch (e) {
      // revert
      if (idx != -1 && previous != null) {
        _fabrics[idx]['favorited'] = previous;
      }
      if (_currentFabric?['id'] == fabricId && previous != null) {
        _currentFabric!['favorited'] = previous;
      }
      notifyListeners();
      _setError('Erreur de réseau');
      _logger.e('Unexpected toggle favorite error', error: e);
      return false;
    }
  }
}
