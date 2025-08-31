import 'package:flutter/material.dart';
import '../widgets/template_card.dart';
import 'new_project_screen.dart';
import 'package:provider/provider.dart';
import '../services/templates.service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      final svc = context.read<TemplatesService>();
      if (svc.templates.isEmpty) {
        svc.fetchAllTemplates();
      }
      _fetched = true;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    if (offset >= max - 200) {
      context.read<TemplatesService>().loadMoreTemplates();
    }
  }

  @override
  Widget build(BuildContext context) {
  super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'recherche',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 20,
                          ),
                          suffixIcon: Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      debugPrint('Cancel search pressed');
                    },
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content: single infinite list
            Expanded(child: _buildTemplateList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context) {
    return Consumer<TemplatesService>(
      builder: (context, service, _) {
        final templates = service.templates;

        Widget content;
        if (service.lastError != null && templates.isEmpty) {
          content = ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: Text(
                  service.lastError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        } else if (templates.isEmpty) {
          content = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: Text('Aucun gabarit trouvé.')),
              SizedBox(height: 200),
            ],
          );
        } else {
          content = ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final id = template['id']?.toString();
                  if (id == null || id.isEmpty) return;
                  final svc = context.read<TemplatesService>();
          await svc.fetchGabaritById(id); // hydrate cache with full payload
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewProjectScreen(initialGabaritId: id),
                    ),
                  );
                },
                child: TemplateCard(
                  title: (template['title'] ?? template['name'] ?? 'Sans nom') as String,
                  date: (template['date'] ?? template['createdAt'] ?? '') as String,
                  image: (template['cachedImagePath'] ?? template['absoluteImageUrl'] ?? template['imageUrl'] ?? template['image']) as String?,
                  icon: (template['cachedIconPath'] ?? template['absoluteIconUrl'] ?? template['iconUrl']) as String?,
                ),
              );
            },
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<TemplatesService>().fetchAllTemplates(),
          child: Stack(
            children: [
              content,
              if (service.isLoading) ...[
                Positioned.fill(
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
                ),
              ],
              if (service.isLoadingMore)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}