import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/template_card.dart';
import 'package:provider/provider.dart';
import '../services/templates.service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

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
      context.read<TemplatesService>().fetchAllTemplates();
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
        return RefreshIndicator(
          onRefresh: () => context.read<TemplatesService>().fetchAllTemplates(),
          child: Builder(builder: (context) {
            if (service.isLoading) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 200),
                ],
              );
            }
            if (service.lastError != null) {
              return ListView(
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
            }
            final templates = service.templates;
            if (templates.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('Aucun gabarit trouvé.')),
                  SizedBox(height: 200),
                ],
              );
            }
            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: templates.length + (service.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= templates.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final template = templates[index];
                return TemplateCard(
                  title: (template['title'] ?? template['name'] ?? 'Sans nom') as String,
                  date: (template['date'] ?? template['createdAt'] ?? '') as String,
                  image: (template['image'] ?? template['imageUrl'] ?? '') as String,
                );
              },
            );
          }),
        );
      },
    );
  }
}