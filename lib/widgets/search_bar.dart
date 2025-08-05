import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  final VoidCallback? onCancel;
  final ValueChanged<String>? onChanged;

  const CustomSearchBar({super.key, this.onCancel, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        hintText: 'Recherche...',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: TextButton(
          onPressed: onCancel,
          child: Text(
            'Annuler',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}