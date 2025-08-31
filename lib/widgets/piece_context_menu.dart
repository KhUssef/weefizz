import 'package:flutter/material.dart';

class PieceContextMenu extends StatelessWidget {
  final String? pieceTitle;
  final Map<String, dynamic>? selectedFabric;
  final int quantity;
  final VoidCallback onPickFabric;
  final VoidCallback onChangeQuantity;

  const PieceContextMenu({
    super.key,
    this.pieceTitle,
    required this.selectedFabric,
    required this.quantity,
    required this.onPickFabric,
    required this.onChangeQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final hasFabric = selectedFabric != null;
    final fabricName = (selectedFabric?['title'] ?? selectedFabric?['name'] ?? 'Sélectionner une matière').toString();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pieceTitle != null && pieceTitle!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(
                  children: [
                    const Icon(Icons.label_important_outline, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pieceTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            _Tile(
              leading: const Icon(Icons.inventory_2_outlined, color: Colors.black87),
              title: 'Matière',
              subtitle: fabricName,
              subtitleStyle: TextStyle(
                color: hasFabric ? Colors.black87 : Colors.black54,
                fontWeight: hasFabric ? FontWeight.w600 : FontWeight.w400,
              ),
              onTap: onPickFabric,
              isTop: true,
            ),
            const Divider(height: 1),
            _Tile(
              leading: const Icon(Icons.layers_outlined, color: Colors.black87),
              title: 'Nombre de pièces',
              subtitle: 'x$quantity',
              subtitleStyle: const TextStyle(fontWeight: FontWeight.w600),
              onTap: onChangeQuantity,
              isBottom: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final TextStyle? subtitleStyle;
  final VoidCallback onTap;
  final bool isTop;
  final bool isBottom;

  const _Tile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleStyle,
    this.isTop = false,
    this.isBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isTop ? 12 : 0),
        topRight: Radius.circular(isTop ? 12 : 0),
        bottomLeft: Radius.circular(isBottom ? 12 : 0),
        bottomRight: Radius.circular(isBottom ? 12 : 0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: subtitleStyle ?? const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
