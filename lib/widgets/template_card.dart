import 'package:flutter/material.dart';

class TemplateCard extends StatelessWidget {
  final String title;
  final String? date;
  final String? image;

  const TemplateCard({
    super.key,
    required this.title,
    this.date,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
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
          // Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      image!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.description,
                    size: 30,
                    color: Colors.grey[400],
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
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    date!,
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
