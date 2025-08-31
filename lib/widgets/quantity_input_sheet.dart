import 'package:flutter/material.dart';

// A bottom sheet/dialog to input number of clothes to produce
class QuantityInputSheet extends StatefulWidget {
  final int? initial;
  const QuantityInputSheet({super.key, this.initial});

  @override
  State<QuantityInputSheet> createState() => _QuantityInputSheetState();
}

class _QuantityInputSheetState extends State<QuantityInputSheet> {
  final TextEditingController _ctrl = TextEditingController();
  int? _value;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null && widget.initial! > 0) {
      _ctrl.text = widget.initial.toString();
      _value = widget.initial;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
    setState(() => _value = (n != null && n >= 0) ? n : null);
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF4A6CF7);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                const Text(
                  'Estimation de la quantité nécessaire',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 12),
            const Text('Nombre de pièces'),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '(ex : 350)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _value == null || _value == 0
                  ? null
                  : () => Navigator.pop<int>(context, _value),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Calcul automatique', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
