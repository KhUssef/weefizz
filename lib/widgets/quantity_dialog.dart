import 'package:flutter/material.dart';

Future<int?> showQuantityDialog(BuildContext context, {int initial = 1, bool allowZero = false}) {
  final minVal = allowZero ? 0 : 1;
  final ctrl = TextEditingController(text: initial.clamp(minVal, 9999).toString());
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Modifier la quantité'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: allowZero ? 'Entrez un nombre ≥ 0' : 'Entrez une quantité positive'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            final v = int.tryParse(ctrl.text.trim());
            if (v == null || v < minVal) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(allowZero ? 'Valeur invalide (≥ 0)' : 'Quantité invalide (> 0)')));
              return;
            }
            Navigator.pop(ctx, v);
          },
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
}
