import 'package:flutter/material.dart';
import '../services/fabrics.service.dart';
import 'package:provider/provider.dart';

class QuantityResultScreen extends StatelessWidget {
  final String gabaritId;
  final Map<String, num> quantities; // fabricId -> area in cm² (displayed in m²)
  final int count;
  const QuantityResultScreen({super.key, required this.gabaritId, required this.quantities, required this.count});

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF4A6CF7);
    final green = const Color(0xFF2E7D32);

    // Try to resolve fabric metadata from FabricsService caches
    final fabSvc = context.read<FabricsService>();
    Map<String, dynamic>? findFabric(String id) {
      for (final list in [fabSvc.fabrics, fabSvc.featuredFabrics, fabSvc.homeFullFabrics]) {
        final m = list.whereType<Map<String, dynamic>>().where((e) => (e['id']?.toString() ?? '') == id).toList();
        if (m.isNotEmpty) return m.first;
      }
      return null;
    }

    final items = quantities.entries
        .map((e) {
          final id = e.key;
          final cm = e.value;
          final fab = findFabric(id);
          final title = (fab?['title'] ?? fab?['name'] ?? 'Tissu').toString();
          final density = fab?['density'];
          final elasticity = fab?['elasticity'];
          final color = fab?['color'] ?? fab?['colour'];
          return _QuantityItem(
            title: title,
            cm: cm,
            subtitle: [
              if (density != null) 'Densité : $density',
              if (elasticity != null) 'Elasticité : $elasticity',
              if (color != null) 'Couleur : $color',
            ].join('\n'),
          );
        })
        .toList();

  final totalCm2 = quantities.values.fold<num>(0, (a, b) => a + b);
  final totalM2 = (totalCm2.toDouble() / 10000.0); // cm² -> m²

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Estimation de la quantité nécessaire', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total tissu nécessaire/pièces : $count', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (items.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tissu sélectionné', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const Text('Quantité nécessaire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${totalM2.toStringAsFixed(2)} m²', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Retour accueil', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _QuantityItem extends StatelessWidget {
  final String title;
  final num cm; // area in cm²
  final String? subtitle;
  const _QuantityItem({required this.title, required this.cm, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.texture, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Builder(builder: (_) {
            final m2 = (cm.toDouble() / 10000.0);
            return Text('${m2.toStringAsFixed(2)} m²', style: const TextStyle(fontWeight: FontWeight.w700));
          }),
        ],
      ),
    );
  }
}
