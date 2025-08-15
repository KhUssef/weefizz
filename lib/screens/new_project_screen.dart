import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'camera_screen.dart';
import 'dart:async';
import '../services/api_client.dart';
import '../services/fabrics.service.dart';
import '../widgets/type_selection_sheet.dart';
import '../widgets/fabric_editor_sheet.dart';

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _materialFocus.addListener(_handleMaterialFocusChange);
    _templateFocus.addListener(_handleTemplateFocusChange);
  }

  @override
  void dispose() {
    _identificationController.dispose();
    _templateController.dispose();
    _materialController.dispose();
    _materialFocus.dispose();
    _materialDebounce?.cancel();
    _hideMaterialOverlay();
    _templateController.dispose();
  _templateFocus.dispose();
  _templateDebounce?.cancel();
    super.dispose();
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
        final res = await ApiClient.dio.get('/templates/search', queryParameters: {
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
                } else {
                  // Handle template if needed
                }
              },
            ),
          ),
        );
        if (capturedPath != null && mounted && type == 'fabric') {
          await _handleCapturedFabric(capturedPath!);
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
        } else {
          // Handle template if needed
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      
                      // Identification field
                      _buildInputField(
                        controller: _identificationController,
                        label: 'Identification',
                        placeholder: 'Votre projet (ex : veste coupe-vent)',
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
                        ListView.builder(
                          itemCount: _fabrics.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final f = _fabrics[index];
                            return Card(
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
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      
                      const SizedBox(height: 24),
                      
                      // Template search + plus button (same width as Tissu)
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
                  ),
                ),
              ),
              
              // Validate button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () {
                    // Handle form validation and submission
                    debugPrint('Project created:');
                    debugPrint('- Identification: ${_identificationController.text}');
                    debugPrint('- Fabrics:');
                    for (final mat in _fabrics) {
                      debugPrint('  - ${mat.name} (${mat.imagePath})');
                    }
                    debugPrint('- Template: ${_templateController.text}');
                    
                    // You can add your project creation logic here
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
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
      ),
    );
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

  bool get _isUrl => path.toLowerCase().startsWith('http://') || path.toLowerCase().startsWith('https://');

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
      child: _isUrl
          ? FutureBuilder<Map<String, String>>(
              future: ApiClient.getAuthHeaders(),
              builder: (context, snap) {
                final headers = snap.data ?? const <String, String>{};
                return Image.network(
                  path,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  headers: headers.isEmpty ? null : headers,
                  errorBuilder: (_, __, ___) => Container(
                    width: size,
                    height: size,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                );
              },
            )
          : Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: size,
                height: size,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
    );
  }
}

// IdentifyFabricSheet removed; type selection now uses TypeSelectionSheet widget
