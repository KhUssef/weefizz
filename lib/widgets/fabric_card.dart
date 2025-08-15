import 'package:flutter/material.dart';
import 'dart:io';

class FabricCard extends StatelessWidget {
  final String title;
  final String? date; // ISO 8601 or already formatted
  final String? image;
  final bool isFavorite;
  final VoidCallback? onFavoritePressed;

  const FabricCard({
    super.key,
    required this.title,
    this.date,
    this.image,
    this.isFavorite = false,
    this.onFavoritePressed,
  });

  ImageProvider? _buildImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    if (path.startsWith('/')) {
      return FileImage(File(path));
    }
    return AssetImage(path);
  }

  @override
  Widget build(BuildContext context) {
    String? formattedDate;
    if (date != null && date!.isNotEmpty) {
      try {
        final dt = DateTime.tryParse(date!);
        if (dt != null) {
          final d = dt.toLocal();
          formattedDate = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        } else {
          formattedDate = date; // fallback
        }
      } catch (_) {
        formattedDate = date;
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey[100],
                ),
                child: image != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image(
                          image: _buildImageProvider(image!)!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.category,
                        size: 40,
                        color: Colors.grey[400],
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onFavoritePressed,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isFavorite ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        if (formattedDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
