import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/fabrics.service.dart';
import 'fabric_editor_sheet.dart';
import 'protected_image.dart';

class FeaturedFabricsStrip extends StatefulWidget {
  const FeaturedFabricsStrip({super.key});

  @override
  State<FeaturedFabricsStrip> createState() => _FeaturedFabricsStripState();
}

class _FeaturedFabricsStripState extends State<FeaturedFabricsStrip> {

  Future<void> _openEditorForFabric(Map<String, dynamic> fabric) async {
    final service = context.read<FabricsService>();
    final id = fabric['id'] as String?;
    if (id != null) {
      await service.fetchFabricById(id);
      if (!mounted) return;
      final current = service.currentFabric ?? fabric;
      await showFabricEditorSheet(context, current);
    } else {
      if (!mounted) return;
      await showFabricEditorSheet(context, fabric);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FabricsService>(
      builder: (context, svc, _) {
        if (svc.isLoadingHomeFull && svc.homeFullFabrics.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (svc.homeFullFabrics.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: svc.homeFullFabrics.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final fabric = svc.homeFullFabrics[index];
              // Prefer cached full-size file path to avoid extra downloads
              final img = (fabric['homeCachedImagePath'] ?? fabric['homeImageUrl'] ?? fabric['absoluteOriginalImageUrl']) as String?;
              final title = (fabric['title'] ?? fabric['name'] ?? 'Sans nom') as String;
                  final favored = (fabric['favorited'] ?? false) as bool;
                  final id = fabric['id'] as String?;
              return _FeaturedCard(
                image: img,
                title: title,
                subtitle: 'Tissus',
                    isFavorite: favored,
                    onFavoriteTap: id == null
                        ? null
                        : () {
                            final next = !favored;
                            svc.toggleFavorite(id, next);
                          },
                onTap: () => _openEditorForFabric(Map<String, dynamic>.from(fabric)),
              );
            },
          ),
        );
      },
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final String? image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  const _FeaturedCard({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildImage(String path) => ProtectedImage(
          path: path,
          fit: BoxFit.cover,
          placeholder: const Icon(Icons.broken_image, color: Colors.grey),
        );
    return AspectRatio(
      aspectRatio: 16/9,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null && image!.isNotEmpty)
                buildImage(image!)
              else
                Container(color: Colors.grey[200]),
              // Favorite button overlay
        Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onFavoriteTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isFavorite ? Colors.red : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
