import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<int?> showQuantityDialog(BuildContext context, {int initial = 1, bool allowZero = false}) {
  final minVal = allowZero ? 0 : 1;
  final ctrl = TextEditingController(text: initial.clamp(minVal, 9999).toString());
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        title: Row(
          children: [
            const Expanded(
              child: Text('Modifier la quantité', overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: 'Fermer',
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: allowZero ? 'Entrez un nombre ≥ 0' : 'Entrez une quantité positive',
                ),
                onSubmitted: (_) {
                  final v = int.tryParse(ctrl.text.trim());
                  if (v == null || v < minVal) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(allowZero ? 'Valeur invalide (≥ 0)' : 'Quantité invalide (> 0)')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, v);
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final v = int.tryParse(ctrl.text.trim());
                        if (v == null || v < minVal) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(allowZero ? 'Valeur invalide (≥ 0)' : 'Quantité invalide (> 0)')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, v);
                      },
                      child: const Text('Confirmer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
