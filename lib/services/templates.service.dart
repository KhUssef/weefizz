import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;

class TemplatesService extends ChangeNotifier {
  static final _logger = Logger();
  // Testing override: force all id-based calls to use a fixed gabarit id
  static const String _testGabaritId = '1915083e-2e89-4755-a259-b58764dd57cf';
  // IMPORTANT: keep false in normal usage; enable only for targeted backend testing
  bool _useTestIdOverride = false; // disable by default

  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _currentTemplate;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? lastError;

  // In-memory cache for processed gabarit data (pieces, outlines, processed image, etc.)
  final Map<String, Map<String, dynamic>> _processedCache = {};

  // Retrieve cached processed info for a gabarit id (if any)
  Map<String, dynamic>? getProcessedInfo(String id) => _processedCache[id];

  // Store processed info in cache
  void cacheProcessedInfo(String id, Map<String, dynamic> data) {
    _processedCache[id] = data;
  }

  // Update a gabarit's metadata with image via multipart: PUT /gabarit/:id/with-image
  Future<bool> updateGabaritWithImage(String gabaritId, Map<String, dynamic> fields, String imageFilePath) async {
    try {
      final effId = _effectiveId(gabaritId);
      final path = '/gabarit/$effId/with-image';
      final map = Map<String, dynamic>.from(fields);
      if (fields.containsKey('description')) {
        map['desc'] = fields['description'];
      }
      final form = FormData.fromMap({
        ...map,
        'file': await MultipartFile.fromFile(imageFilePath, filename: imageFilePath.split('/').last),
      });
      try {
        final hdr = await ApiClient.getAuthHeaders();
        _logger.i('[GABARIT UPDATE WITH IMAGE] PUT ${ApiClient.dio.options.baseUrl}$path\nHeaders: \\${hdr.isEmpty ? '<none>' : hdr}\nFields: \\${map.keys.toList()}');
      } catch (_) {}
      final res = await ApiClient.dio.put(path, data: form);
      _logger.i('[GABARIT UPDATE WITH IMAGE] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}');
      return res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204;
    } on DioException catch (e) {
      try { _logger.w('[GABARIT UPDATE WITH IMAGE] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nResp: ${e.response?.data}'); } catch (_) {}
      _setError('Échec de la mise à jour du gabarit (image): ${e.response?.statusCode ?? 'réseau'}');
      return false;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('updateGabaritWithImage unexpected', error: e);
      return false;
    }
  }

  // Getters
  List<Map<String, dynamic>> get templates => _templates;
  Map<String, dynamic>? get currentTemplate => _currentTemplate;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
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

  String absoluteImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    // Normalize any backslashes returned by backend
    String p = imageUrl.replaceAll('\\', '/');
    if (p.startsWith('http://') || p.startsWith('https://')) {
      return p;
    }
    final base = ApiClient.dio.options.baseUrl;
    if (!p.startsWith('/')) p = '/$p';
    if (base.endsWith('/') && p.startsWith('/')) {
      return base.substring(0, base.length - 1) + p;
    }
    return base + p;
  }

  // For testing: pick the fixed test id instead of provided id
  String _effectiveId(String id) {
    if (_useTestIdOverride) {
      // Make it very obvious in logs when we override IDs
      _logger.w('[GABARIT] Using TEST ID override: requested=$id -> effective=$_testGabaritId');
      return _testGabaritId;
    }
    return id;
  }

  Map<String, dynamic> _normalizeTemplate(Map<String, dynamic> m) {
    final r = Map<String, dynamic>.from(m);
    // Normalize title/name field
    r['title'] = r['title'] ?? r['name'];
    // Normalize image field
    String? img = r['imageUrl'] as String?;
    img ??= r['image'] as String?;
    if (img != null && img.isNotEmpty) {
      r['imageUrl'] = img;
      r['absoluteImageUrl'] = absoluteImageUrl(img);
    }
    // Keep iconUrl absolute too if present
    final icon = r['iconUrl'] as String?;
    if (icon != null && icon.isNotEmpty) {
      r['absoluteIconUrl'] = absoluteImageUrl(icon);
    }
    return r;
  }

  Future<void> _prefetchAndCacheImages(List<Map<String, dynamic>> items) async {
    for (final m in items) {
  final abs = absoluteImageUrl(m['imageUrl'] as String?);
      if (abs.isEmpty) continue;
      try {
        final file = await DefaultCacheManager().getSingleFile(abs);
        m['cachedImagePath'] = file.path;
        m['absoluteImageUrl'] = abs;
      } catch (e) {
        _logger.w('Failed to cache template image for ${m['id']}: $e');
      }
      // Also prefetch icon if available
  final iconAbs = absoluteImageUrl(m['iconUrl'] as String?);
      if (iconAbs.isNotEmpty) {
        try {
          final iconFile = await DefaultCacheManager().getSingleFile(iconAbs);
          m['cachedIconPath'] = iconFile.path;
          m['absoluteIconUrl'] = iconAbs;
        } catch (e) {
          _logger.w('Failed to cache template icon for ${m['id']}: $e');
        }
      }
    }
  }

  // Internal: fetch specific page
  Future<bool> _fetchTemplatesPage(int page) async {
    try {
      // Use gabarit controller (no downsized parameter)
      final response = await ApiClient.dio.get('/gabarit', queryParameters: {
        'page': page,
      });

      if (response.statusCode == 200) {
        final raw = List<Map<String, dynamic>>.from(response.data);
        final list = raw.map(_normalizeTemplate).toList();
        await _prefetchAndCacheImages(list);

        // Replace on first page (0), append otherwise. Preserve if empty on refresh.
        List<Map<String, dynamic>> merged;
        if (page == 0) {
          merged = list.isEmpty ? _templates : list;
        } else {
          merged = [..._templates, ...list];
        }

        _templates = merged;
        _currentPage = page;
        _hasMore = list.isNotEmpty;
        debugPrint('Fetched gabarits page $page; total: ${_templates.length}');
        return true;
      } else {
        _setError('Failed to fetch templates: ${response.statusCode}');
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
        _setError('Modèles introuvables');
      } else {
        _setError('Erreur: ${e.response?.statusCode ?? 'réseau'}');
      }

      _logger.e('Fetch templates page error', error: e);
      return false;
    } catch (e) {
      if (_isLoading) _setLoading(false);
      _isLoadingMore = false; notifyListeners();
      _setError('Erreur de réseau');
      _logger.e('Unexpected fetch templates error', error: e);
      return false;
    }
  }

  // Public: first page (refresh)
  Future<bool> fetchAllTemplates() async {
    _setError(null);
    _hasMore = true;
    _currentPage = 0;
  // Drop current list immediately
  clearTemplates();
    _setLoading(true);
  final ok = await _fetchTemplatesPage(0);
    _setLoading(false);
    return ok;
  }

  // Public: load next page
  Future<bool> loadMoreTemplates() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return false;
    _isLoadingMore = true; notifyListeners();
    final next = _currentPage + 1;
    final ok = await _fetchTemplatesPage(next);
    _isLoadingMore = false; notifyListeners();
    return ok;
  }


  // Upload a gabarit image and return created resource map (expects { id, filePath, ... })
  Future<Map<String, dynamic>?> uploadGabaritPhoto(String imagePath, {String? name}) async {
    try {
      final fileName = imagePath.split('/').last;
      name ??= fileName;
      final form = FormData.fromMap({
        if (name.isNotEmpty) 'name': name,
        'image': await MultipartFile.fromFile(imagePath, filename: fileName),
      });
      final path = '/gabarit';
      try {
        final hdr = await ApiClient.getAuthHeaders();
        _logger.i('[GABARIT UPLOAD] POST ${ApiClient.dio.options.baseUrl}$path\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}\nForm fields: ${form.fields.map((e)=>e.key).toList()} Files: ${form.files.map((e)=>e.key).toList()}');
      } catch (_) {}
      final res = await ApiClient.dio.post(path, data: form);
      _logger.i('[GABARIT UPLOAD] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}\nResp headers: ${res.headers.map}\nBody: ${res.data}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final map = Map<String, dynamic>.from(res.data as Map);
        // enrich with absolute path if filePath present
        final fp = map['filePath'] as String?;
        if (fp != null) map['absoluteImageUrl'] = absoluteImageUrl(fp);
        return map;
      }
      _setError('Échec de l\'upload du gabarit: ${res.statusCode}');
      return null;
    } on DioException catch (e) {
      try {
        _logger.w('[GABARIT UPLOAD] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nReq headers: ${e.requestOptions.headers}\nResp headers: ${e.response?.headers.map}\nResp data: ${e.response?.data}');
      } catch (_) {}
      _setError('Upload gabarit erreur: ${e.response?.statusCode ?? 'réseau'}');
      _logger.e('uploadGabaritPhoto error', error: e);
      return null;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('uploadGabaritPhoto unexpected', error: e);
      return null;
    }
  }

  // Trigger server-side processing and fetch full info for a gabarit by id
  Future<Map<String, dynamic>?> fetchGabaritFullInfo(String id) async {
    final effId = _effectiveId(id);
    final path = '/gabarit/process/$effId';
    int attempts = 0;
    const maxAttempts = 3; // 1 initial + 2 retries
    const backoffMs = 450; // small delay to let the backend persist the file
    while (true) {
      attempts++;
      try {
        // Log what we're about to call (with token if present)
        try {
          final hdr = await ApiClient.getAuthHeaders();
          _logger.i('[GABARIT PROCESS] GET ${ApiClient.dio.options.baseUrl}$path\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}');
        } catch (_) {}
        final res = await ApiClient.dio.get(path);
        _logger.i('[GABARIT PROCESS] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}\nResponse headers: ${res.headers.map}\nBody: ${res.data}');
        if (res.statusCode == 200 || res.statusCode == 201) {
          if (res.data is! Map) {
            _setError('Réponse invalide du serveur pour process');
            return null;
          }
          final map = Map<String, dynamic>.from(res.data as Map);
          _logger.d('process[$effId]: ${map.keys.toList()}');

          // New shape: { gabarit: {...}, pieces: [...], totalPieces, imageDimensions }
          final gabarit = map['gabarit'];
          if (gabarit is Map) {
            final gm = Map<String, dynamic>.from(gabarit);
            final processed = gm['processedImage'] as String?;
            final original = gm['originalImage'] as String?;
            final icon = gm['iconPath'] as String?;
            if (processed != null && processed.isNotEmpty) {
              map['absoluteProcessedImageUrl'] = absoluteImageUrl(processed);
            }
            if (original != null && original.isNotEmpty) {
              map['absoluteOriginalImageUrl'] = absoluteImageUrl(original);
            }
            if (icon != null && icon.isNotEmpty) {
              map['absoluteIconUrl'] = absoluteImageUrl(icon);
            }
          }
          // Cache processed result for later reuse in details screen
          try {
            cacheProcessedInfo(effId, map);
          } catch (_) {}
          return map;
        }
        _setError('Échec de la récupération du gabarit: ${res.statusCode}');
        return null;
      } on DioException catch (e) {
        // If the image file isn't found yet on disk, retry a couple times
        final code = e.response?.statusCode;
        final data = e.response?.data;
        final msg = data is Map ? (data['message']?.toString() ?? '') : (data?.toString() ?? '');
        final isTransient404 = code == 404 && msg.toLowerCase().contains('image') && msg.toLowerCase().contains('not') && msg.toLowerCase().contains('found');
        final canRetry = isTransient404 && attempts < maxAttempts;
        try {
          _logger.w('[GABARIT PROCESS] ERROR ${code ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nReq headers: ${e.requestOptions.headers}\nReq data: ${e.requestOptions.data}\nResp headers: ${e.response?.headers.map}\nResp data: ${e.response?.data}${canRetry ? '\nWill retry...' : ''}');
        } catch (_) {}
        if (canRetry) {
          await Future.delayed(const Duration(milliseconds: backoffMs));
          continue;
        }
        _setError('Récupération gabarit erreur: ${code ?? 'réseau'}');
        _logger.e('fetchGabaritFullInfo error', error: e);
        return null;
      } catch (e) {
        _setError('Erreur de réseau');
        _logger.e('fetchGabaritFullInfo unexpected', error: e);
        return null;
      }
    }
  }

  // Fetch a single gabarit by ID
  Future<Map<String, dynamic>?> fetchGabaritById(String id) async {
    try {
      final effId = _effectiveId(id);
      final path = '/gabarit/$effId';
      try {
        final hdr = await ApiClient.getAuthHeaders();
        _logger.i('[GABARIT BY ID] GET ${ApiClient.dio.options.baseUrl}$path\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}');
      } catch (_) {}
      final res = await ApiClient.dio.get(path);
      _logger.i('[GABARIT BY ID] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}\nResp headers: ${res.headers.map}\nBody: ${res.data}');
      if (res.statusCode == 200) {
        final body = Map<String, dynamic>.from(res.data as Map);
        // If server returns process-like shape, normalize and cache
        final hasFull = body.containsKey('gabarit') || body.containsKey('pieces');
        if (hasFull) {
          final map = Map<String, dynamic>.from(body);
          final gabarit = map['gabarit'];
          if (gabarit is Map) {
            final gm = Map<String, dynamic>.from(gabarit);
            final processed = gm['processedImage'] as String?;
            final original = gm['originalImage'] as String?;
            final icon = gm['iconPath'] as String?;
            if (processed != null && processed.isNotEmpty) {
              map['absoluteProcessedImageUrl'] = absoluteImageUrl(processed);
            }
            if (original != null && original.isNotEmpty) {
              map['absoluteOriginalImageUrl'] = absoluteImageUrl(original);
            }
            if (icon != null && icon.isNotEmpty) {
              map['absoluteIconUrl'] = absoluteImageUrl(icon);
            }
          }
          // Cache full processed-like payload for reuse
          cacheProcessedInfo(effId, map);
          return map;
        } else {
          // Legacy/simple shape
          final fp = body['filePath'] as String?;
          final ip = body['iconPath'] as String?;
          if (fp != null) body['absoluteImageUrl'] = absoluteImageUrl(fp);
          if (ip != null) body['absoluteIconUrl'] = absoluteImageUrl(ip);
          return body;
        }
      }
      _setError('Échec de la récupération du gabarit: ${res.statusCode}');
      return null;
    } on DioException catch (e) {
      try {
        _logger.w('[GABARIT BY ID] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nReq headers: ${e.requestOptions.headers}\nResp headers: ${e.response?.headers.map}\nResp data: ${e.response?.data}');
      } catch (_) {}
      _setError('Récupération gabarit erreur: ${e.response?.statusCode ?? 'réseau'}');
      _logger.e('fetchGabaritById error', error: e);
      return null;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('fetchGabaritById unexpected', error: e);
      return null;
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

  // Update gabarit scale: PUT /gabarit/:id { scale }
  Future<bool> updateGabaritScale(String gabaritId, double scale) async {
    try {
      final effId = _effectiveId(gabaritId);
      final path = '/gabarit/$effId';
      final body = { 'scale': scale };
      try {
        final hdr = await ApiClient.getAuthHeaders();
  final url = '${ApiClient.dio.options.baseUrl}$path';
  final jsonBody = jsonEncode(body);
  _logger.i('[GABARIT UPDATE SCALE] PUT $url\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}\nBody(JSON): $jsonBody');
      } catch (_) {}
      final res = await ApiClient.dio.put(path, data: body);
      _logger.i('[GABARIT UPDATE SCALE] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}');
      return res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 201;
    } on DioException catch (e) {
      try {
        _logger.w('[GABARIT UPDATE SCALE] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nResp: ${e.response?.data}');
      } catch (_) {}
      _setError('Échec de la mise à jour de l\'échelle: ${e.response?.statusCode ?? 'réseau'}');
      return false;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('updateGabaritScale unexpected', error: e);
      return false;
    }
  }

  // Generic PATCH /gabarit/:id with provided fields
  Future<bool> patchGabarit(String gabaritId, Map<String, dynamic> fields) async {
    try {
      final effId = _effectiveId(gabaritId);
      final path = '/gabarit/$effId';
      try {
        final hdr = await ApiClient.getAuthHeaders();
  final url = '${ApiClient.dio.options.baseUrl}$path';
  final jsonBody = jsonEncode(fields);
  _logger.i('[GABARIT PATCH] PATCH $url\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}\nBody(JSON): $jsonBody');
      } catch (_) {}
      final res = await ApiClient.dio.patch(path, data: fields);
      _logger.i('[GABARIT PATCH] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}');
      return res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 201;
    } on DioException catch (e) {
      try { _logger.w('[GABARIT PATCH] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nResp: ${e.response?.data}'); } catch (_) {}
      _setError('Échec de la mise à jour du gabarit: ${e.response?.statusCode ?? 'réseau'}');
      return false;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('patchGabarit unexpected', error: e);
      return false;
    }
  }

  // Convenience: PATCH gabarit scale
  Future<bool> updateGabaritScalePatch(String gabaritId, double scale) => patchGabarit(gabaritId, { 'scale': scale });

  // PATCH /piece/:id with provided fields (NumberOfPieces, fabricId, scale, ...)
  Future<bool> patchPiece(String pieceId, Map<String, dynamic> fields) async {
    try {
      final path = '/piece/$pieceId';
      try {
        final hdr = await ApiClient.getAuthHeaders();
        final url = '${ApiClient.dio.options.baseUrl}$path';
        final jsonBody = jsonEncode(fields);
        final types = fields.map((k, v) => MapEntry(k, v == null ? 'null' : v.runtimeType.toString()));
        if (!fields.containsKey('fabricId') || fields['fabricId'] == null) {
          _logger.w('[PIECE PATCH] fabricId is missing or null for piece=$pieceId');
        }
        _logger.i('[PIECE PATCH] PATCH $url\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}\nBody(JSON): $jsonBody\nBody(Types): $types');
      } catch (_) {}
      final res = await ApiClient.dio.patch(path, data: fields);
      _logger.i('[PIECE PATCH] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}');
      return res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 201;
    } on DioException catch (e) {
      try { _logger.w('[PIECE PATCH] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nResp: ${e.response?.data}'); } catch (_) {}
      _setError('Échec de la mise à jour de la pièce: ${e.response?.statusCode ?? 'réseau'}');
      return false;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('patchPiece unexpected', error: e);
      return false;
    }
  }

  // Update piece quantities for a gabarit in bulk: PUT /gabarit/:id/pieces
  // Payload example: { pieces: [ { id: 'pieceId', NumberOfPieces: 2 }, ... ] }
  Future<bool> updateGabaritPieceQuantities(String gabaritId, Map<String, int> quantities) async {
    try {
      final effId = _effectiveId(gabaritId);
      final path = '/gabarit/$effId/pieces';
      final pieces = quantities.entries.map((e) => {
        'id': e.key,
        'NumberOfPieces': e.value,
      }).toList();
      final body = { 'pieces': pieces };
      try {
        final hdr = await ApiClient.getAuthHeaders();
        _logger.i('[GABARIT UPDATE PIECES] PUT ${ApiClient.dio.options.baseUrl}$path\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}\nBody: ${body.toString()}');
      } catch (_) {}
      final res = await ApiClient.dio.put(path, data: body);
      _logger.i('[GABARIT UPDATE PIECES] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}');
      return res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 201;
    } on DioException catch (e) {
      try {
        _logger.w('[GABARIT UPDATE PIECES] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nResp: ${e.response?.data}');
      } catch (_) {}
      _setError('Échec de la mise à jour des pièces: ${e.response?.statusCode ?? 'réseau'}');
      return false;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('updateGabaritPieceQuantities unexpected', error: e);
      return false;
    }
  }

  // Apply scale to gabarit and all its pieces using PATCH endpoints.
  // pieces: list of maps with at least { id } and optionally { NumberOfPieces, fabricId } to also update.
  Future<bool> applyScaleToGabaritAndPieces({
    required String gabaritId,
    required double scale,
    required List<Map<String, dynamic>> pieces,
  }) async {
    // 1) Patch gabarit scale
    final okG = await updateGabaritScalePatch(gabaritId, scale);
    if (!okG) return false;
    // 2) Patch each piece with scale (+ optional fields)
    bool allOk = true;
    for (final p in pieces) {
      final id = p['id']?.toString();
      if (id == null) continue;
      final fields = <String, dynamic>{ 'scale': scale };
      if (p.containsKey('NumberOfPieces')) fields['NumberOfPieces'] = p['NumberOfPieces'];
      if (p.containsKey('fabricId')) fields['fabricId'] = p['fabricId'];
      try {
        final url = '${ApiClient.dio.options.baseUrl}/piece/$id';
        final jsonBody = jsonEncode(fields);
        _logger.i('[APPLY SCALE] PATCH $url\nBody(JSON): $jsonBody');
      } catch (_) {}
      final ok = await patchPiece(id, fields);
      allOk = allOk && ok;
    }
    return allOk;
  }

  // Calculate required fabric quantities for a gabarit and a number of clothes
  // Calls: GET /gabarit/calculer/:id?number=<n>
  // Returns a map { fabricId: numberInCm, ... }
  Future<Map<String, num>?> calculateRequiredQuantities({
    required String gabaritId,
    required int number,
  }) async {
    try {
      final effId = _effectiveId(gabaritId);
      final path = '/gabarit/calcul/$effId';
      try {
        final hdr = await ApiClient.getAuthHeaders();
        _logger.i('[GABARIT CALCUL] GET ${ApiClient.dio.options.baseUrl}$path?number=$number\nHeaders: ${hdr.isEmpty ? '<none>' : hdr}');
      } catch (_) {}
      final res = await ApiClient.dio.get(path, queryParameters: { 'number': number });
      _logger.i('[GABARIT CALCUL] <- ${res.statusCode} ${res.requestOptions.method} ${res.requestOptions.uri}\nBody: ${res.data}');
      if (res.statusCode == 200) {
        if (res.data is Map) {
          final raw = Map<String, dynamic>.from(res.data as Map);
          // Convert any numeric-like values to num
          final out = <String, num>{};
          raw.forEach((k, v) {
            if (v is num) {
              out[k.toString()] = v;
            } else if (v is String) {
              final parsed = num.tryParse(v);
              if (parsed != null) out[k.toString()] = parsed;
            }
          });
          return out;
        }
        // Non-map response
        _setError('Réponse invalide du serveur (calcul)');
        return null;
      }
      _setError('Échec du calcul: ${res.statusCode}');
      return null;
    } on DioException catch (e) {
      try {
        _logger.w('[GABARIT CALCUL] ERROR ${e.response?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.uri}\nResp: ${e.response?.data}');
      } catch (_) {}
      _setError('Calcul erreur: ${e.response?.statusCode ?? 'réseau'}');
      return null;
    } catch (e) {
      _setError('Erreur de réseau');
      _logger.e('calculateRequiredQuantities unexpected', error: e);
      return null;
    }
  }
}
