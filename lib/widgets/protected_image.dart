import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ProtectedImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;
  final Widget? placeholder;

  const ProtectedImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  bool get _isHttp => path.toLowerCase().startsWith('http://') || path.toLowerCase().startsWith('https://');
  bool get _isWindowsFile => RegExp(r'^[a-zA-Z]:\\').hasMatch(path) || path.contains('\\');
  bool get _isUnixFile => path.startsWith('/');
  bool get _isServerRelative => path.startsWith('/uploads/') || path.startsWith('/files/') || path.startsWith('/images/');

  @override
  Widget build(BuildContext context) {
    final child = _buildInner();
    final br = borderRadius;
    if (br != null) {
      return ClipRRect(borderRadius: br, child: child);
    }
    return child;
  }

  Widget _buildInner() {
    final ph = placeholder ?? _defaultPlaceholder();
    if (path.isEmpty) return _sized(ph);
    if (_isHttp || _isServerRelative) {
      final url = _isHttp ? path : _absoluteUrl(path);
      return FutureBuilder<Map<String, String>>(
        future: ApiClient.getAuthHeaders(),
        builder: (context, snap) {
          final headers = snap.data ?? const <String, String>{};
          return Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            headers: headers.isEmpty ? null : headers,
            errorBuilder: (_, __, ___) => _sized(ph),
          );
        },
      );
    }
    if (_isUnixFile || _isWindowsFile) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _sized(ph),
      );
    }
    // Fallback: try asset
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _sized(ph),
    );
  }

  String _absoluteUrl(String rel) {
    final base = ApiClient.dio.options.baseUrl;
    if (base.isEmpty) return rel;
    if (base.endsWith('/') && rel.startsWith('/')) {
      return base.substring(0, base.length - 1) + rel;
    }
    return base + rel;
  }

  Widget _sized(Widget child) => SizedBox(width: width, height: height, child: FittedBox(fit: BoxFit.contain, child: child));

  Widget _defaultPlaceholder() => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
}
