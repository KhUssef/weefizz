import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'camera_screen.dart';
import 'dart:async';
import '../services/api_client.dart';
import '../widgets/protected_image.dart';
import '../services/fabrics.service.dart';
import '../widgets/type_selection_sheet.dart';
import '../widgets/fabric_editor_sheet.dart';
import '../services/templates.service.dart';
import 'project_details.dart';
import '../widgets/quantity_input_sheet.dart';
import 'quantity_result_screen.dart';

class NewProjectScreen extends StatefulWidget {
  final String? initialGabaritId;
  const NewProjectScreen({super.key, this.initialGabaritId});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}


class FabricItem {
  final String? id;
  final String name;
  final String imagePath;
  final String? type;
  final String? color;
  final DateTime? createdAt;
  final String? description;
  FabricItem({
    this.id,
    required this.name,
    required this.imagePath,
    this.type,
    this.color,
    this.createdAt,
    this.description,
  });
}

class GabaritItem {
  final String id;
  final String name;
  final String iconPath;
  final String? processedImagePath; // absolute processed image URL if available
  final DateTime? createdAt;
  GabaritItem({
    required this.id,
    required this.name,
    required this.iconPath,
    this.processedImagePath,
    this.createdAt,
  });
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  // Debounced search for existing fabrics
  final TextEditingController _materialController = TextEditingController();
  final FocusNode _materialFocus = FocusNode();
  final LayerLink _materialLink = LayerLink();
  final GlobalKey _materialFieldKey = GlobalKey();
  OverlayEntry? _materialOverlay;
  OverlayEntry? _materialBarrier;
  Timer? _materialDebounce;
  static const int _materialDebounceMs = 350;
  bool _loadingMaterials = false;
  List<Map<String, dynamic>> _materialResults = [];

  // removed old prompt dialog; identify sheet handles naming now
  final TextEditingController _identificationController = TextEditingController();
  final TextEditingController _templateController = TextEditingController();
  final List<FabricItem> _fabrics = [];
  final List<GabaritItem> _gabarits = [];
  // UI state for rename button
  bool _renaming = false; // spinning
  bool? _renameOk; // null default, true success, false error (transient)
  // Template search state
  final FocusNode _templateFocus = FocusNode();
  final LayerLink _templateLink = LayerLink();
  final GlobalKey _templateFieldKey = GlobalKey();
  OverlayEntry? _templateOverlay;
  OverlayEntry? _templateBarrier;
  Timer? _templateDebounce;
  static const int _templateDebounceMs = 350;
  bool _loadingTemplates = false;
  List<Map<String, dynamic>> _templateResults = [];

  // Upload/loading state for template operations
  bool _uploadingTemplate = false;
  String _uploadingMessage = 'Envoi du gabarit...';

  @override
  void initState() {
    super.initState();
    _materialFocus.addListener(_handleMaterialFocusChange);
    _templateFocus.addListener(_handleTemplateFocusChange);
    // If a gabarit id was provided (navigated from Templates/Home), hydrate one card from cache
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = widget.initialGabaritId;
      if (id == null || id.isEmpty) return;
      final svc = context.read<TemplatesService>();
      final cached = svc.getProcessedInfo(id) ?? await svc.fetchGabaritById(id);
      if (!mounted || cached == null) return;
      // Build a single GabaritItem for display
      final gab = cached['gabarit'] as Map<String, dynamic>?;
      final name = (gab?['name'] ?? cached['name'] ?? 'Gabarit').toString();
      final iconAbs = (cached['absoluteIconUrl'] ?? cached['absoluteImageUrl'] ?? '').toString();
      final processedAbs = (cached['absoluteProcessedImageUrl'] ?? '').toString();
      final createdAt = DateTime.tryParse((gab?['createdAt'] ?? cached['createdAt'] ?? '').toString());
      setState(() {
        final item = GabaritItem(
          id: id,
          name: name,
          iconPath: iconAbs,
          processedImagePath: processedAbs.isNotEmpty ? processedAbs : null,
          createdAt: createdAt,
        );
        if (_gabarits.isEmpty) {
          _gabarits.add(item);
        } else {
          _gabarits[0] = item;
        }
        // Prefill top rename field with the current gabarit name
        if (_identificationController.text.trim().isEmpty) {
          _identificationController.text = name;
        }
      });
  // Also hydrate fabrics from this gabarit's pieces (cache-first, then GET /fabric/:id)
  await _hydrateFabricsFromGabaritPieces(cached);
    });
  }

  @override
  void dispose() {
    _identificationController.dispose();
  _templateController.dispose();
    _materialController.dispose();
    _materialFocus.dispose();
    _materialDebounce?.cancel();
    _hideMaterialOverlay();
  _hideTemplateOverlay();
  _templateFocus.dispose();
  _templateDebounce?.cancel();
    super.dispose();
  }

  Future<void> _hydrateFabricsFromGabaritPieces(Map<String, dynamic> cached) async {
    try {
      final pieces = cached['pieces'];
      if (pieces is! List) return;
      // Collect unique fabric ids as strings
      final Set<String> fabricIds = {};
      for (final p in pieces) {
        if (p is! Map) continue;
        final fidRaw = p['fabricId'] ?? p['materialId'] ?? p['fabric']?['id'];
        if (fidRaw == null) continue;
        final fid = fidRaw.toString();
        if (fid.isEmpty) continue;
        fabricIds.add(fid);
      }
      if (fabricIds.isEmpty) return;

      final fabSvc = context.read<FabricsService>();
      final List<Map<String, dynamic>> caches = [
        ...fabSvc.fabrics,
        ...fabSvc.featuredFabrics,
        ...fabSvc.homeFullFabrics,
      ];

      // Helper to map a fabric map into a FabricItem
      FabricItem toItem(Map<String, dynamic> m) {
        final name = (m['title'] ?? m['name'] ?? 'Tissu').toString();
        final type = (m['type'] ?? m['category'])?.toString();
        final color = (m['color'] ?? m['colour'])?.toString();
        final id = m['id']?.toString();
        DateTime? createdAt;
        final createdRaw = m['createdAt'] ?? m['created_at'] ?? m['date'];
        if (createdRaw != null) {
          createdAt = DateTime.tryParse(createdRaw.toString());
        }
        final rawImg = (m['cachedImagePath'] ?? m['absoluteImageUrl'] ?? m['originalImageUrl'] ?? m['imageUrl'] ?? m['iconPath'] ?? m['filePath'] ?? m['image'] ?? m['thumbnail']) as String?;
        final img = _resolveImagePath(rawImg);
        return FabricItem(id: id, name: name, imagePath: img, type: type, color: color, createdAt: createdAt, description: m['description']?.toString());
      }

      // Resolve each fabric id, prefer caches first
      for (final fid in fabricIds) {
        if (_fabrics.any((f) => (f.id?.toString() ?? '') == fid)) continue; // already added

        Map<String, dynamic>? found = caches.firstWhere(
          (m) => (m['id']?.toString() ?? '') == fid,
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          setState(() => _fabrics.add(toItem(found)));
          continue;
        }

        // Fallback: GET /fabric/:id
        try {
          final res = await ApiClient.dio.get('/fabric/$fid');
          if (res.statusCode == 200 && res.data is Map) {
            final map = Map<String, dynamic>.from(res.data as Map);
            setState(() => _fabrics.add(toItem(map)));
          }
        } catch (_) {
          // Ignore failures quietly here; user can still add fabrics manually
        }
      }
    } catch (_) {
      // Best-effort; ignore
    }
  }

  void _handleMaterialFocusChange() {
    if (_materialFocus.hasFocus) {
      _updateMaterialOverlay();
    } else {
      _hideMaterialOverlay();
    }
  }

  void _handleTemplateFocusChange() {
    if (_templateFocus.hasFocus) {
      _updateTemplateOverlay();
    } else {
      _hideTemplateOverlay();
    }
  }

  void _hideMaterialOverlay() {
  _materialOverlay?.remove();
  _materialOverlay = null;
  _materialBarrier?.remove();
  _materialBarrier = null;
  }

  void _hideTemplateOverlay() {
  _templateOverlay?.remove();
  _templateOverlay = null;
  _templateBarrier?.remove();
  _templateBarrier = null;
  }

  void _updateMaterialOverlay() {
    if (!mounted) return;
    if (!_materialFocus.hasFocus || _materialController.text.trim().isEmpty) {
      _hideMaterialOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    final mq = MediaQuery.of(context);
    final box = _materialFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldHeight = box?.size.height ?? 52.0;
    const double pagePadding = 16.0;
    final Offset fieldGlobal = box?.localToGlobal(Offset.zero) ?? Offset(mq.padding.left + pagePadding, mq.padding.top);
    final double topY = fieldGlobal.dy + fieldHeight + 6;
    final double leftX = mq.padding.left + pagePadding;
    final double rightX = mq.padding.right + pagePadding;

    // Full-screen barrier to capture outside taps
    final barrier = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hideMaterialOverlay,
        ),
      ),
    );

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: topY,
        left: leftX,
        right: rightX,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _loadingMaterials
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : (_materialResults.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('Aucun résultat'),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (MediaQuery.of(context).size.height * 0.4).clamp(160.0, 360.0),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: _materialResults.length > 6
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: _materialResults.length.clamp(0, 20),
                          itemBuilder: (context, index) {
                            final m = _materialResults[index];
                            return _MaterialSuggestionCard(
                              data: m,
                              onTap: () => _selectMaterialFromSearch(m),
                            );
                          },
                        ),
                      )),
          ),
        ),
      ),
    );

    // Replace any existing overlay
  _materialOverlay?.remove();
  _materialBarrier?.remove();
  _materialBarrier = barrier;
  _materialOverlay = entry;
  overlay.insert(barrier);
  overlay.insert(entry);
  }

  void _updateTemplateOverlay() {
    if (!mounted) return;
    if (!_templateFocus.hasFocus || _templateController.text.trim().isEmpty) {
      _hideTemplateOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    final mq = MediaQuery.of(context);
    final box = _templateFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldHeight = box?.size.height ?? 52.0;
    const double pagePadding = 16.0;
    final Offset fieldGlobal = box?.localToGlobal(Offset.zero) ?? Offset(mq.padding.left + pagePadding, mq.padding.top);
    final double topY = fieldGlobal.dy + fieldHeight + 6;
    final double leftX = mq.padding.left + pagePadding;
    final double rightX = mq.padding.right + pagePadding;

    final barrier = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hideTemplateOverlay,
        ),
      ),
    );

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: topY,
        left: leftX,
        right: rightX,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _loadingTemplates
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : (_templateResults.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('Aucun résultat'),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (MediaQuery.of(context).size.height * 0.4).clamp(160.0, 360.0),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: _templateResults.length > 6
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: _templateResults.length,
                          itemBuilder: (context, index) {
                            final t = _templateResults[index];
                            final name = (t['title'] ?? t['name'] ?? 'Sans nom').toString();
                            return ListTile(
                              dense: true,
                              title: Text(name),
                              onTap: () {
                                _templateController.text = name;
                                setState(() => _templateResults = []);
                                _templateFocus.unfocus();
                                _hideTemplateOverlay();
                              },
                            );
                          },
                        ),
                      )),
          ),
        ),
      ),
    );

  _templateOverlay?.remove();
  _templateBarrier?.remove();
  _templateBarrier = barrier;
  _templateOverlay = entry;
  overlay.insert(barrier);
  overlay.insert(entry);
  }

  void _onMaterialChanged(String value) {
    _materialDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _materialResults = [];
        _loadingMaterials = false;
      });
  _hideMaterialOverlay();
      return;
    }
    _materialDebounce = Timer(const Duration(milliseconds: _materialDebounceMs), () async {
      setState(() => _loadingMaterials = true);
      try {
        final res = await ApiClient.dio.get('/fabric/search', queryParameters: {
          'q': q,
          'page': 0,
          'limit': 10,
          'downsized': true,
        });
        if (!mounted) return;
        if (res.statusCode == 200) {
          final list = List<Map<String, dynamic>>.from(res.data);
          setState(() {
            _materialResults = list;
            _loadingMaterials = false;
          });
          _updateMaterialOverlay();
        } else {
          setState(() {
            _materialResults = [];
            _loadingMaterials = false;
          });
          _updateMaterialOverlay();
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _materialResults = [];
          _loadingMaterials = false;
        });
        _updateMaterialOverlay();
      }
    });
  }

  void _onTemplateChanged(String value) {
    _templateDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _templateResults = [];
        _loadingTemplates = false;
      });
  _hideTemplateOverlay();
      return;
    }
    _templateDebounce = Timer(const Duration(milliseconds: _templateDebounceMs), () async {
      setState(() => _loadingTemplates = true);
      try {
  final res = await ApiClient.dio.get('/gabarit/search', queryParameters: {
          'q': q,
        });
        if (!mounted) return;
        if (res.statusCode == 200) {
          final list = List<Map<String, dynamic>>.from(res.data);
          setState(() {
            _templateResults = list;
            _loadingTemplates = false;
          });
          _updateTemplateOverlay();
        } else {
          setState(() {
            _templateResults = [];
            _loadingTemplates = false;
          });
          _updateTemplateOverlay();
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _templateResults = [];
          _loadingTemplates = false;
        });
        _updateTemplateOverlay();
      }
    });
  }

  String _resolveImagePath(String? p) {
    if (p == null || p.isEmpty) return '';
    final lower = p.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return p;
    final base = ApiClient.dio.options.baseUrl;
    if (base.endsWith('/') && p.startsWith('/')) {
      return base.substring(0, base.length - 1) + p;
    }
    if (!base.endsWith('/') && !p.startsWith('/')) {
      return '$base/$p';
    }
    return '$base$p';
  }

  void _selectMaterialFromSearch(Map<String, dynamic> item) {
    final name = (item['title'] ?? item['name'] ?? 'Tissu') as String;
    final type = (item['type'] ?? item['category'])?.toString();
    final color = (item['color'] ?? item['colour'])?.toString();
  final id = item['id']?.toString();
    DateTime? createdAt;
    final createdRaw = item['createdAt'] ?? item['created_at'] ?? item['date'];
    if (createdRaw != null) {
      createdAt = DateTime.tryParse(createdRaw.toString());
    }
  // Prefer local cached path if provided, fall back to absolute URL or image
  final rawImg = (item['cachedImagePath'] ?? item['absoluteImageUrl'] ?? item['imageUrl'] ?? item['iconPath'] ?? item['filePath'] ?? item['image'] ?? item['thumbnail']) as String?;
  final img = _resolveImagePath(rawImg);
    setState(() {
      _fabrics.add(FabricItem(
    id: id,
        name: name,
    imagePath: img,
        type: type,
        color: color,
        createdAt: createdAt,
      ));
      _materialController.clear();
      _materialResults = [];
    });
    _materialFocus.unfocus();
  _hideMaterialOverlay();
  }

  // Handle captured or picked gabarit: upload, fetch full info, then open ProjectDetails

  Future<void> _handleCapturedGabarit(String imagePath) async {
    if (!mounted) return;
    setState(() {
      _uploadingTemplate = true;
      _uploadingMessage = 'Envoi du gabarit...';
    });
  final svc = context.read<TemplatesService>();
    final name = _templateController.text.trim().isNotEmpty ? _templateController.text.trim() : null;
    final uploaded = await svc.uploadGabaritPhoto(imagePath, name: name);
    if (uploaded == null || uploaded['id'] == null) {
      if (!mounted) return;
      setState(() => _uploadingTemplate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'upload du gabarit.')),
      );
      return;
    }
    final id = uploaded['id'].toString();
    if (mounted) {
      setState(() => _uploadingMessage = 'Récupération des informations...');
    }
  // Immediately process and cache result
  final fullInfo = await svc.fetchGabaritFullInfo(id);
    if (fullInfo == null) {
      if (!mounted) return;
      setState(() => _uploadingTemplate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la récupération du gabarit.')),
      );
      return;
    }
    // Compute processed image absolute URL for card
    String processedAbs = '';
    final gab = fullInfo['gabarit'];
    if (gab is Map) {
      final pi = gab['processedImage'] as String?;
      if (pi != null) processedAbs = svc.absoluteImageUrl(pi);
    }
    // Do not navigate now. The details screen will read cached outlines.

  // Derive UI fields from upload/process payload to avoid extra GET here
  final itemName = (uploaded['name']?.toString() ?? name ?? 'Gabarit');
  final created = DateTime.tryParse((uploaded['createdAt'] ?? '').toString());
  final iconAbs = svc.absoluteImageUrl((uploaded['iconPath'] ?? uploaded['filePath'])?.toString());
  if (mounted) {
      setState(() {
        // Enforce single template: replace existing if any
        final newItem = GabaritItem(
          id: id,
          name: itemName,
          iconPath: iconAbs,
          processedImagePath: processedAbs.isNotEmpty ? processedAbs : null,
          createdAt: created,
        );
        if (_gabarits.isEmpty) {
          _gabarits.add(newItem);
        } else {
          _gabarits[0] = newItem;
        }
        _uploadingTemplate = false;
      });
    }
    // Do not navigate automatically; open details when user taps the template card
  }

  Future<void> _openCamera({required String type}) async {
    // Check camera permission
    final cameraStatus = await Permission.camera.request();
    
    if (cameraStatus.isGranted) {
      if (mounted) {
        String? capturedPath;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CameraScreen(
              captureType: type, // 'fabric' or 'template'
              onImageCaptured: (imagePath) async {
                if (type == 'fabric') {
                  capturedPath = imagePath; // handle after route pops
                } else if (type == 'template') {
                  capturedPath = imagePath;
                }
              },
            ),
          ),
        );
        if (capturedPath != null && mounted) {
          if (type == 'fabric') {
            await _handleCapturedFabric(capturedPath!);
          } else if (type == 'template') {
            await _handleCapturedGabarit(capturedPath!);
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission d\'accès à la caméra requise'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectFromGallery({required String type}) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        if (type == 'fabric') {
          await _handleCapturedFabric(image.path);
        } else if (type == 'template') {
          await _handleCapturedGabarit(image.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog({required String type, required String title}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            // Header with blue background and fabric texture
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4A6CF7),
                    const Color(0xFF667EEA),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.layers,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Title and description
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scannez vos tissus et obtenez des\ninformations détaillées automatiquement\npour une meilleure gestion des tissus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Fabric texture placeholder
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.texture,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom section with options
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'OU',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ajouter manuellement un tissu',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Camera button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openCamera(type: type);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A6CF7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sélectionner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Gallery button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _selectFromGallery(type: type);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Choisir depuis la galerie',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Handle captured or picked fabric: call identify, add immediately, then open selection for actual type
  Future<void> _handleCapturedFabric(String imagePath) async {
    final svc = context.read<FabricsService>();
    final result = await svc.identifyFabric(imagePath);
    final Map<String, dynamic> created = Map<String, dynamic>.from(result['fabric'] as Map);
    final List<Map<String, dynamic>> candidates = List<Map<String, dynamic>>.from(result['predictions'] as List);
    final firstType = (candidates.isNotEmpty ? (candidates.first['type']?.toString() ?? (created['type']?.toString() ?? 'Tissu')) : (created['type']?.toString() ?? 'Tissu'));

    // Resolve an image path for UI: prefer absoluteImageUrl or cached file; fallback to provided capture path
    String uiImagePath = imagePath;
    final abs = (created['absoluteImageUrl'] ?? created['imageUrl'] ?? created['originalImageUrl'] ?? created['filePath'] ?? '') as String?;
    if (abs != null && abs.toString().isNotEmpty) {
      final s = abs.toString();
      if (s.startsWith('http://') || s.startsWith('https://')) {
        uiImagePath = s;
      } else {
        uiImagePath = _resolveImagePath(s);
      }
    } else if ((created['cachedImagePath'] as String?)?.isNotEmpty == true) {
      uiImagePath = created['cachedImagePath'] as String;
    }

    final item = FabricItem(
  id: created['id']?.toString(),
      name: (created['title']?.toString() ?? firstType),
      imagePath: uiImagePath,
      type: (created['type']?.toString() ?? firstType),
      color: created['color']?.toString(),
      createdAt: DateTime.tryParse(created['createdAt']?.toString() ?? '') ?? DateTime.now(),
      description: created['description']?.toString(),
    );
    if (!mounted) return;
    setState(() => _fabrics.add(item));

    // Let user refine actual type
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TypeSelectionSheet(options: candidates, initial: item.type ?? firstType),
    );
    if (!mounted) return;
    if (selected != null && selected.trim().isNotEmpty) {
      final newType = selected.trim();
      // If backend returned an id, persist the update via service
      final id = created['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await svc.updateFabric(id, {'type': newType, 'title': (created['title'] ?? newType)});
      }
      // Update local UI item
      setState(() {
        final idx = _fabrics.lastIndexWhere((f) => identical(f, item));
        if (idx >= 0) {
          _fabrics[idx] = FabricItem(
            id: item.id,
            name: (created['title']?.toString() ?? newType),
            imagePath: item.imagePath,
            type: newType,
            color: item.color,
            createdAt: item.createdAt,
            description: item.description,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouveau projet',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  edgeOffset: 12,
                  displacement: 36,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: LayoutBuilder(
                      builder: (context, constraints) => ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        const SizedBox(height: 8),
                        
                        // Identification field
                        // Identification + rename button (if a gabarit is loaded)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _identificationController,
                                label: 'Identification',
                                placeholder: 'Votre projet (ex : veste coupe-vent)',
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_gabarits.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _renaming ? null : () async {
                                      if (_gabarits.isEmpty) return;
                                      final id = _gabarits.first.id;
                                      final newName = _identificationController.text.trim();
                                      if (newName.isEmpty) return;
                                      setState(() { _renaming = true; _renameOk = null; });
                                      final ok = await context.read<TemplatesService>().patchGabarit(id, { 'name': newName, 'title': newName });
                                      if (!mounted) return;
                                      if (ok) {
                                        setState(() { _renameOk = true; _renaming = false; });
                                        // Update local card immediately
                                        setState(() { _gabarits[0] = GabaritItem(id: _gabarits.first.id, name: newName, iconPath: _gabarits.first.iconPath, processedImagePath: _gabarits.first.processedImagePath, createdAt: _gabarits.first.createdAt); });
                                        await Future.delayed(const Duration(seconds: 1));
                                        if (!mounted) return;
                                        setState(() { _renameOk = null; });
                                      } else {
                                        setState(() { _renameOk = false; _renaming = false; });
                                        await Future.delayed(const Duration(seconds: 1));
                                        if (!mounted) return;
                                        setState(() { _renameOk = null; });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      side: const BorderSide(color: Color(0xFF4A6CF7)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: () {
                                      if (_renaming) {
                                        return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF4A6CF7)));
                                      }
                                      if (_renameOk == true) {
                                        return const Icon(Icons.check, color: Color(0xFF2E7D32));
                                      }
                                      if (_renameOk == false) {
                                        return const Icon(Icons.close, color: Colors.red);
                                      }
                                      return const Icon(Icons.drive_file_rename_outline, color: Color(0xFF4A6CF7));
                                    }(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Tissu search + plus button
                        Text(
                          'Tissu',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FractionallySizedBox(
                                widthFactor: 0.92,
                                child: CompositedTransformTarget(
                                  link: _materialLink,
                                  child: Container(
                                    key: _materialFieldKey,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: TextField(
                                      controller: _materialController,
                                      focusNode: _materialFocus,
                                      onChanged: _onMaterialChanged,
                                      decoration: InputDecoration(
                                        hintText: 'Nom du tissu',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 16,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showImageSourceDialog(
                                type: 'fabric',
                                title: 'Identification et Préparation\ndes Tissus',
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A4E69),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.add, color: Colors.white),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Selected fabrics list below the search
                        if (_fabrics.isNotEmpty) ...[
                          const Text(
                            'Tissus',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int index = 0; index < _fabrics.length; index++)
                                Builder(builder: (context) {
                                  final f = _fabrics[index];
                                  return SizedBox(
                                    width: double.infinity,
                                    child: Card(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: _FabricThumb(path: f.imagePath),
                                      title: Text(f.name),
                                      subtitle: (f.type != null || f.color != null || f.createdAt != null)
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (f.type != null) Text('Type: ${f.type}') else const SizedBox.shrink(),
                                                if (f.color != null) Text('Couleur: ${f.color}') else const SizedBox.shrink(),
                                                if (f.createdAt != null)
                                                  Text('Créé le: ${f.createdAt!.day.toString().padLeft(2, '0')}/${f.createdAt!.month.toString().padLeft(2, '0')}/${f.createdAt!.year}')
                                                else
                                                  const SizedBox.shrink(),
                                              ],
                                            )
                                          : null,
                                      onTap: () async {
                                        if (f.id == null || f.id!.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Ce tissu n\'est pas encore modifiable.')),
                                          );
                                          return;
                                        }
                                        final fabricMap = {
                                          'id': f.id,
                                          'title': f.name,
                                          'description': f.description,
                                          'type': f.type,
                                          'color': f.color,
                                        };
                                        await showFabricEditorSheet(context, fabricMap);
                                        if (!mounted) return;
                                        final svc = context.read<FabricsService>();
                                        final ok = await svc.fetchFabricById(f.id!);
                                        if (!ok) return;
                                        final updated = svc.currentFabric;
                                        if (updated == null) return;
                                        setState(() {
                                          _fabrics[index] = FabricItem(
                                            id: f.id,
                                            name: (updated['title']?.toString() ?? f.name),
                                            imagePath: f.imagePath,
                                            type: updated['type']?.toString() ?? f.type,
                                            color: updated['color']?.toString() ?? f.color,
                                            createdAt: DateTime.tryParse(updated['createdAt']?.toString() ?? '') ?? f.createdAt,
                                            description: updated['description']?.toString() ?? f.description,
                                          );
                                        });
                                      },
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _fabrics.removeAt(index);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  );
                                }),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Single template preview section (below fabrics)
                        if (_gabarits.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Gabarit du projet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(builder: (context) {
                            final g = _gabarits.first;
                            final absImage = (g.processedImagePath != null && g.processedImagePath!.isNotEmpty)
                                ? g.processedImagePath!
                                : (g.iconPath.isNotEmpty ? g.iconPath : '');
                            return SizedBox(
                              width: double.infinity,
                              child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: GestureDetector(
                                  onTap: () async {
                                    // Tap on the icon to change the gabarit's icon
                                    final picker = ImagePicker();
                                    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920, maxHeight: 1080);
                                    if (x == null) return;
                                    final svc = context.read<TemplatesService>();
                                    final fields = { 'title': g.name };
                                    final ok = await svc.updateGabaritWithImage(g.id, fields, x.path);
                                    if (!mounted) return;
                                    if (ok) {
                                      // Refresh from backend to get updated icon URL
                                      final map = await svc.fetchGabaritById(g.id);
                                      final newIcon = (map?['absoluteIconUrl'] ?? map?['gabarit']?['iconPath'] ?? g.iconPath).toString();
                                      setState(() {
                                        _gabarits[0] = GabaritItem(
                                          id: g.id,
                                          name: g.name,
                                          iconPath: newIcon.isNotEmpty ? newIcon : g.iconPath,
                                          processedImagePath: g.processedImagePath,
                                          createdAt: g.createdAt,
                                        );
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec de la mise à jour de l\'icône')));
                                    }
                                  },
                                  child: _FabricThumb(path: g.iconPath, size: 56),
                                ),
                                title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: (g.createdAt != null)
                                    ? Text('Créé le: ${g.createdAt!.day.toString().padLeft(2, '0')}/${g.createdAt!.month.toString().padLeft(2, '0')}/${g.createdAt!.year}')
                                    : const Text(''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _gabarits.clear();
                                    });
                                  },
                                ),
                                onTap: () async {
                                  if (absImage.isEmpty) return;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProjectDetailsScreen(
                                        imageUrl: absImage,
                                        gabaritId: g.id,
                                        avoidProcessOnInit: true,
                                        allowedFabrics: _fabrics.map((f) => {
                                          'id': f.id,
                                          'title': f.name,
                                          if (f.type != null) 'type': f.type,
                                          if (f.color != null) 'color': f.color,
                                          if (f.imagePath.isNotEmpty) 'absoluteImageUrl': f.imagePath,
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ),
                            );
                          }),
                        ],

                        
                        const SizedBox(height: 24),
                        
                        if (_gabarits.isEmpty) ...[
                          // Template search + plus button (only when none selected)
                          Text(
                            'Gabarit',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FractionallySizedBox(
                                  widthFactor: 0.92,
                                  child: CompositedTransformTarget(
                                    link: _templateLink,
                                    child: Container(
                                      key: _templateFieldKey,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: TextField(
                                        controller: _templateController,
                                        focusNode: _templateFocus,
                                        onChanged: _onTemplateChanged,
                                        decoration: InputDecoration(
                                          hintText: 'Nom du gabarit',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showImageSourceDialog(
                                  type: 'template',
                                  title: 'Identification et Préparation\ndes Gabarits',
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A4E69),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Validate button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () async {
                    // Ensure we have a gabarit id and fabrics are all assigned (best-effort check)
                    if (_gabarits.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez sélectionner un gabarit d\'abord.')),
                      );
                      return;
                    }

                    // Ask for number of clothes
                    final number = await showDialog<int>(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => const QuantityInputSheet(),
                    );
                    if (number == null || number <= 0) return;

                    // Call backend /gabarit/calculer/:id
                    final gabId = _gabarits.first.id;
                    final svc = context.read<TemplatesService>();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );
                    final result = await svc.calculateRequiredQuantities(gabaritId: gabId, number: number);
                    if (context.mounted) Navigator.of(context).pop(); // close loader
                    if (result == null || result.isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Échec du calcul.')),
                      );
                      return;
                    }

                    if (!mounted) return;
                    // Navigate to result screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuantityResultScreen(
                          gabaritId: gabId,
                          quantities: result,
                          count: number,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Valider',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
            ),
            if (_uploadingTemplate)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _uploadingMessage,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Pull-to-refresh: clear cached project and refetch using same logic
  Future<void> _onRefresh() async {
    try {
      // Determine current gabarit id to refresh
      String? id;
      if (_gabarits.isNotEmpty) {
        id = _gabarits.first.id;
      } else {
        id = widget.initialGabaritId;
      }
      if (id == null || id.isEmpty) {
        // Nothing to refresh; small delay to satisfy RefreshIndicator
        await Future.delayed(const Duration(milliseconds: 350));
        return;
      }

      final svc = context.read<TemplatesService>();
      // Drop any cached processed data for this gabarit
      svc.removeProcessedInfo(id);

      // Re-fetch from backend; prefer full info if already processed, otherwise GET by id
      final fresh = await svc.fetchGabaritById(id);
      if (!mounted) return;
      if (fresh == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de rafraîchir le gabarit')),
        );
        return;
      }

      // Rebuild the single GabaritItem card from fresh data
      final gab = fresh['gabarit'] as Map<String, dynamic>?;
      final name = (gab?['name'] ?? fresh['name'] ?? 'Gabarit').toString();
      final iconAbs = (fresh['absoluteIconUrl'] ?? fresh['absoluteImageUrl'] ?? '').toString();
      final processedAbs = (fresh['absoluteProcessedImageUrl'] ?? '').toString();
      final createdAt = DateTime.tryParse((gab?['createdAt'] ?? fresh['createdAt'] ?? '').toString());
      setState(() {
        final item = GabaritItem(
          id: id!,
          name: name,
          iconPath: iconAbs,
          processedImagePath: processedAbs.isNotEmpty ? processedAbs : null,
          createdAt: createdAt,
        );
        if (_gabarits.isEmpty) {
          _gabarits.add(item);
        } else {
          _gabarits[0] = item;
        }
        // Update identification input with latest name if empty or matches old name
        if (_identificationController.text.trim().isEmpty) {
          _identificationController.text = name;
        }
        _fabrics.clear();
      });

      // Rehydrate fabrics from fresh piece list
      await _hydrateFabricsFromGabaritPieces(fresh);
    } catch (_) {
      // Swallow errors; RefreshIndicator already gives feedback
    }
  }
}

//

// old inline selection sheet removed in favor of reusable TypeSelectionSheet

class _MaterialSuggestionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _MaterialSuggestionCard({required this.data, required this.onTap});

  String _stringOf(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    final title = _stringOf(data['title'] ?? data['name'] ?? 'Sans nom');
    final type = _stringOf(data['type'] ?? data['category'] ?? '-');
    final color = _stringOf(data['color'] ?? data['colour'] ?? '-');
    String date = '';
    final createdAt = data['createdAt'] ?? data['created_at'] ?? data['date'];
    if (createdAt != null) {
      try {
        final dt = DateTime.tryParse(createdAt.toString());
        if (dt != null) {
          date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        }
      } catch (_) {}
    }
  String thumb = _stringOf(data['cachedImagePath'] ?? data['absoluteImageUrl'] ?? data['imageUrl'] ?? data['iconPath'] ?? data['filePath'] ?? data['image'] ?? data['thumbnail']);
    if (thumb.isNotEmpty) {
      final lower = thumb.toLowerCase();
      if (!(lower.startsWith('http://') || lower.startsWith('https://'))) {
        final base = ApiClient.dio.options.baseUrl;
        thumb = thumb.startsWith('/') ? '$base$thumb' : '$base/$thumb';
      }
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FabricThumb(path: thumb, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Type: ', style: TextStyle(color: Colors.grey)),
                      Expanded(child: Text(type, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Couleur: ', style: TextStyle(color: Colors.grey)),
                      Expanded(child: Text(color, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Créé le: ', style: TextStyle(color: Colors.grey)),
                      Text(date.isEmpty ? '-' : date),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabricThumb extends StatelessWidget {
  final String path;
  final double size;
  const _FabricThumb({required this.path, this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.texture, color: Colors.grey),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ProtectedImage(
        path: path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}

// IdentifyFabricSheet removed; type selection now uses TypeSelectionSheet widget
