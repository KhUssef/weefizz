import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  SectionHeader({required this.title, required this.onViewAll, required Null Function() onSeeAllPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onViewAll,
            child: Text('Voir toutes', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
