import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/fabrics.service.dart';

Future<Map<String, dynamic>?> showFabricPickerSheet(
  BuildContext context, {
  bool resetList = false,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _FabricPickerSheet(resetList: resetList),
  );
}

class _FabricPickerSheet extends StatefulWidget {
  final bool resetList;
  const _FabricPickerSheet({this.resetList = false});

  @override
  State<_FabricPickerSheet> createState() => _FabricPickerSheetState();
}

class _FabricPickerSheetState extends State<_FabricPickerSheet> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final svc = context.read<FabricsService>();
    // If coming from another screen with an active search/list, optionally reset and fetch a neutral set for picking
    if (widget.resetList) {
      // Cancel any search mode and prioritize a small featured list for the picker
      // We don't await to keep the sheet snappy; UI will refresh via Consumer
      svc.cancelSearch();
      svc.fetchFeaturedFabrics(limit: 20, downsized: true);
    } else {
      if (svc.featuredFabrics.isEmpty && svc.fabrics.isEmpty) {
        // Best effort: fetch a small set for picking
        svc.fetchFeaturedFabrics(limit: 20, downsized: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Consumer<FabricsService>(
        builder: (context, svc, _) {
          final items = svc.featuredFabrics.isNotEmpty ? svc.featuredFabrics : svc.fabrics;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A6CF7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Choisir une matière', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (svc.isLoadingFeatured && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Aucune matière disponible'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final m = items[index];
                      final title = (m['title'] ?? m['name'] ?? 'Sans nom').toString();
                      final subtitle = (m['type'] ?? '').toString();
                      final img = (m['cachedImagePath'] ?? m['absoluteImageUrl'] ?? m['imageUrl']) as String?;
                      return ListTile(
                        leading: _Thumb(image: img),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle),
                        onTap: () => Navigator.pop(context, Map<String, dynamic>.from(m)),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? image;
  const _Thumb({this.image});

  @override
  Widget build(BuildContext context) {
    if (image == null || image!.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.texture));
    }
    final lower = image!.toLowerCase();
    final isUrl = lower.startsWith('http://') || lower.startsWith('https://');
    if (isUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Image.network(image!, width: 40, height: 40, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const CircleAvatar(child: Icon(Icons.texture))),
      );
    }
    // Fallback: no file IO dependency, just show placeholder
    return const CircleAvatar(child: Icon(Icons.texture));
  }
}
