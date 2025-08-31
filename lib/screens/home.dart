import 'package:flutter/material.dart';
import '../widgets/section_header.dart';
import '../widgets/template_card.dart';
import 'package:provider/provider.dart';
import '../services/fabrics.service.dart';
import '../services/templates.service.dart';
import './main_navigation.dart';
import '../widgets/featured_fabrics_strip.dart';
import '../services/auth.service.dart';
import 'new_project_screen.dart';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const HomeScreen({super.key, this.onSelectTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  bool _first = true;

  Future<void> _refreshAll(BuildContext context) async {
    await Future.wait([
      context.read<FabricsService>().fetchHomeFullFabrics(limit: 5),
      context.read<TemplatesService>().fetchAllTemplates(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_first) {
      // Initial fetch on first mount: Home-only data
      _first = false;
      _refreshAll(context);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refreshAll(context),
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Consumer<AuthService>(
                    builder: (context, auth, _) {
                      final name = auth.username;
                      final display = (name != null && name.isNotEmpty) ? name : 'Invité';
                      return Text(
                        'Bonjour, $display 👋',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Featured fabrics strip
                SectionHeader(
                  title: 'Matieres',
                  onViewAll: () {
                    // Emulate tapping the Fabrics tab (index 2)
                    if (widget.onSelectTab != null) {
                      widget.onSelectTab!(2);
                    } else {
                      // Fallback to global nav if available
                      MainNavigationScreen.selectTab(2);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const FeaturedFabricsStrip(),
                const SizedBox(height: 8),
                
                const SizedBox(height: 32),
                
                // Templates section
                SectionHeader(
                  title: 'Gabarits',
                  onViewAll: () {
                    // Emulate tapping the Templates tab (index 1)
                    if (widget.onSelectTab != null) {
                      widget.onSelectTab!(1);
                    } else {
                      // Fallback to global nav if available
                      MainNavigationScreen.selectTab(1);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Consumer<TemplatesService>(
                  builder: (context, svc, _) {
                    final templates = svc.templates;
                    if (svc.isLoading && templates.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (templates.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Aucun gabarit trouvé.')),
                      );
                    }
                    // Show a few items on Home (e.g., first 3)
                    final items = templates.take(3).toList();
                    return Column(
                      children: [
                        for (final t in items)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              final id = t['id']?.toString();
                              if (id == null || id.isEmpty) return;
                              // Hydrate cache with full payload, then go to New Project screen
                              await context.read<TemplatesService>().fetchGabaritById(id);
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NewProjectScreen(initialGabaritId: id),
                                ),
                              );
                            },
                            child: TemplateCard(
                              title: (t['title'] ?? t['name'] ?? 'Sans nom') as String,
                              date: (t['date'] ?? t['createdAt'] ?? '') as String?,
                              image: (t['cachedImagePath'] ?? t['absoluteImageUrl'] ?? t['imageUrl'] ?? t['image']) as String?,
                              icon: (t['cachedIconPath'] ?? t['absoluteIconUrl'] ?? t['iconUrl']) as String?,
                              onImagePressed: () async {
                                final id = t['id']?.toString();
                                if (id == null || id.isEmpty) return;
                                final picker = ImagePicker();
                                final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920, maxHeight: 1080);
                                if (x == null) return;
                                final svc = context.read<TemplatesService>();
                                final fields = {
                                  'title': t['title'] ?? t['name'] ?? '',
                                };
                                await svc.updateGabaritWithImage(id, fields, x.path);
                                // Refresh the single gabarit to show updated icon quickly
                                await svc.fetchGabaritById(id);
                              },
                            ),
                          ),
                        if (svc.isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
              ),
              // Floating loader overlay when either fabrics home-full or templates are loading initial fetches
              Consumer2<FabricsService, TemplatesService>(
                builder: (context, fab, tpl, _) {
                  final show = fab.isLoadingHomeFull || tpl.isLoading;
                  if (!show) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.15),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                                SizedBox(width: 12),
                                Text('Chargement...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
