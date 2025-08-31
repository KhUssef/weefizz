import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  final String captureType;
  final Function(String imagePath) onImageCaptured;

  const CameraScreen({
    super.key,
    required this.captureType,
    required this.onImageCaptured,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _capturedImagePath;

  // Minimal controls
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      // Enforce rear camera only; if not found, show error and exit
      final maybeBack = cameras.where((c) => c.lensDirection == CameraLensDirection.back);
      if (maybeBack.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune caméra arrière trouvée'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
        return;
      }
      final description = maybeBack.first;
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur initialisation caméra: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile image = await _controller!.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImagePath = image.path;
        _isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la capture: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cycleFlashMode() async {
    if (_controller == null) return;
    final next = () {
      switch (_flashMode) {
        case FlashMode.off:
          return FlashMode.auto;
        case FlashMode.auto:
          return FlashMode.always;
        case FlashMode.always:
          return FlashMode.off;
        case FlashMode.torch:
          return FlashMode.off;
      }
    }();
    try {
      await _controller!.setFlashMode(next);
      if (!mounted) return;
      setState(() => _flashMode = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flash non supporté: $e'), backgroundColor: Colors.red),
      );
    }
  }

  IconData _flashIconFor(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  // Pinch-to-zoom removed for a simpler UI

  Future<void> _onTapToFocus(TapDownDetails details, BoxConstraints c) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
  // Convert to 0..1 within the preview area and set focus/exposure silently
    final size = Size(c.maxWidth, c.maxHeight);
    final localPos = details.localPosition;
    final dx = (localPos.dx / size.width).clamp(0.0, 1.0);
    final dy = (localPos.dy / size.height).clamp(0.0, 1.0);
    final point = Offset(dx, dy);
    try {
      await _controller!.setFocusPoint(point);
    } catch (_) {}
    try {
      await _controller!.setExposurePoint(point);
    } catch (_) {}
  }

  void _retakePhoto() {
    setState(() => _capturedImagePath = null);
  }

  void _usePhoto() {
    final p = _capturedImagePath;
    if (p != null) {
      widget.onImageCaptured(p);
      Navigator.pop(context);
    }
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4A6CF7)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Preview with gestures
            GestureDetector(
              onTapDown: (d) => _onTapToFocus(d, constraints),
              behavior: HitTestBehavior.opaque,
              child: Builder(builder: (context) {
                final pv = _controller!.value.previewSize;
                if (pv == null) {
                  // Fallback
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    ),
                  );
                }
                final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                final previewW = isPortrait ? pv.height : pv.width;
                final previewH = isPortrait ? pv.width : pv.height;
                return Center(
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: previewW,
                        height: previewH,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                );
              }),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      _roundBtn(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
            const Expanded(child: SizedBox()),
                      Row(
                        children: [
                          _roundBtn(
                            onTap: _cycleFlashMode,
                            child: Icon(_flashIconFor(_flashMode), color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom shutter
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _isCapturing ? null : _captureImage,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: _isCapturing ? 40 : 56,
                                  height: _isCapturing ? 40 : 56,
                                  decoration: BoxDecoration(
                                    color: _isCapturing ? Colors.white54 : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isCapturing
                                      ? const Padding(
                                          padding: EdgeInsets.all(10.0),
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreview() {
    final p = _capturedImagePath!;
    return Stack(
      children: [
        Positioned.fill(child: Image.file(File(p), fit: BoxFit.cover)),
  Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _retakePhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Reprendre', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _usePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Utiliser cette photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _capturedImagePath != null ? _buildImagePreview() : _buildCameraPreview(),
    );
  }
}

Widget _roundBtn({required VoidCallback? onTap, required Widget child}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(child: child),
    ),
  );
}

