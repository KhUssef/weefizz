import 'package:flutter/material.dart';

class TypeSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> options; // expects {'type': String, 'confidence': num}
  final String initial;
  final String title;

  const TypeSelectionSheet({
    super.key,
    required this.options,
    required this.initial,
    this.title = 'Sélectionnez le type du tissu',
  });

  @override
  State<TypeSelectionSheet> createState() => _TypeSelectionSheetState();
}

class _TypeSelectionSheetState extends State<TypeSelectionSheet> {
  late String _selected;
  final TextEditingController _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  Color _confidenceColor(double pct) {
    if (pct >= 80) return const Color(0xFF16A34A); // green
    if (pct >= 50) return const Color(0xFFF59E0B); // amber
    return const Color(0xFFEF4444); // red
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final opts = widget.options.take(5).toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF4A6CF7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sell, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final m in opts)
                        _TypeOptionTile(
                          label: (m['type']?.toString() ?? '').isEmpty ? 'inconnu' : m['type'].toString(),
                          confidence: (m['confidence'] is num) ? (m['confidence'] as num).toDouble() : 0,
                          selected: _selected == (m['type']?.toString() ?? ''),
                          onSelect: () => setState(() => _selected = (m['type']?.toString() ?? '')),
                          colorOf: _confidenceColor,
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ou bien entrez un type personnalisé',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6CF7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final custom = _customCtrl.text.trim();
                      Navigator.pop(context, custom.isNotEmpty ? custom : _selected);
                    },
                    child: const Text('Confirmer'),
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

class _TypeOptionTile extends StatelessWidget {
  final String label;
  final double confidence; // 0..100
  final bool selected;
  final VoidCallback onSelect;
  final Color Function(double) colorOf;

  const _TypeOptionTile({
    required this.label,
    required this.confidence,
    required this.selected,
    required this.onSelect,
    required this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
  final pct = confidence.clamp(0, 100).toDouble();
  final color = colorOf(pct);
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF4A6CF7) : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: label,
              groupValue: selected ? label : null,
              onChanged: (_) => onSelect(),
              activeColor: const Color(0xFF4A6CF7),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
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
