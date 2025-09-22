import 'package:flutter/material.dart';
import 'protected_image.dart';

class TemplateCard extends StatelessWidget {
  final String title;
  final String? date;
  // Accept either image or icon; service now provides absolute/cached paths
  final String? image;
  final String? icon;
  final VoidCallback? onImagePressed;

  const TemplateCard({
    super.key,
    required this.title,
    this.date,
    this.image,
    this.icon,
  this.onImagePressed,
  });

  // Removed legacy image provider; using ProtectedImage for auth/relative URLs

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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
  child: Row(
        children: [
          // Image (prefer icon when available)
          GestureDetector(
            onTap: onImagePressed,
            behavior: HitTestBehavior.opaque,
            child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: (icon ?? image) != null
                ? ProtectedImage(
                    path: (icon ?? image)!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    placeholder: const Icon(Icons.description, size: 28, color: Colors.grey),
                  )
                : Icon(
                    Icons.description,
                    size: 30,
                    color: Colors.grey[400],
                  ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
        if (formattedDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
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
