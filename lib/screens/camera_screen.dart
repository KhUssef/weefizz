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
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
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

    return SafeArea(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF4A6CF7).withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Scanner un tissu',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
            ),
            // Camera preview with overlay (fixed aspect ratio)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(_controller!)),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.transparent,
                              const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                            ],
                            stops: const [0.0, 0.2, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom controls
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF4A6CF7).withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _isCapturing ? null : _captureImage,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFF4A6CF7), width: 3),
                        ),
                        child: _isCapturing
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A6CF7), strokeWidth: 2))
                            : const Icon(Icons.camera_alt, color: Color(0xFF4A6CF7), size: 26),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _captureImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A6CF7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Capturer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final p = _capturedImagePath!;
    return Stack(
      children: [
        Positioned.fill(child: Image.file(File(p), fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.3))),
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
                        color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.2),
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
