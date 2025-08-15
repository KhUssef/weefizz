import 'package:flutter/material.dart';
import '../widgets/fabric_card.dart';
import 'package:provider/provider.dart';
import '../services/fabrics.service.dart';
import '../widgets/fabric_editor_sheet.dart';

class FabricsScreen extends StatefulWidget {
  const FabricsScreen({super.key});

  @override
  State<FabricsScreen> createState() => _FabricsScreenState();
}

class _FabricsScreenState extends State<FabricsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
  _scrollController.addListener(_onScroll);
  _searchController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      Provider.of<FabricsService>(context, listen: false).fetchAllFabrics();
      _fetched = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    if (offset >= max - 200) {
      // near bottom, try to load more (search-aware)
      context.read<FabricsService>().loadMore();
    }
  }

  Widget _buildFabricGrid() {
    return Consumer<FabricsService>(
      builder: (context, service, _) {
        return RefreshIndicator(
          onRefresh: () => context.read<FabricsService>().fetchAllFabrics(),
          child: Builder(
            builder: (context) {
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
              final fabrics = service.fabrics;
              if (fabrics.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('Aucun tissu trouvé.')),
                    SizedBox(height: 200),
                  ],
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: fabrics.length + (service.isLoadingMore ? 2 : 0),
                itemBuilder: (context, index) {
                  if (index >= fabrics.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final fabric = fabrics[index];
                  final img = (fabric['cachedImagePath'] ?? fabric['absoluteImageUrl'] ?? fabric['image']) as String?;
                  final title = (fabric['title'] ?? fabric['name']  ?? fabric['color'] ?? 'Sans nom') as String;
                  final date = (fabric['date'] ?? fabric['createdAt'] ?? '') as String;
                  final favored = (fabric['favorited'] ?? false) as bool;
                  final id = fabric['id'] as String?;
                  return GestureDetector(
                    onTap: () async {
                      final id = fabric['id'] as String?;
                      final svc = context.read<FabricsService>();
                      if (id != null) {
                        await svc.fetchFabricById(id);
                        if (!mounted) return;
                        final current = svc.currentFabric ?? fabric;
                        debugPrint('Fetched fabric: ${current['name'] ?? id}');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          showFabricEditorSheet(this.context, current);
                        });
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          showFabricEditorSheet(this.context, fabric);
                        });
                      }
                    },
                    child: FabricCard(
                    title: title,
                    date: date,
                    image: img,
                    isFavorite: favored,
                      onFavoritePressed: id == null
                          ? null
                          : () {
                              context.read<FabricsService>().toggleFavorite(id, !favored);
                            },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // Bottom sheet now provided by shared widget helper (fabric_editor_sheet.dart)


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
                        onChanged: (value) {
                          final svc = context.read<FabricsService>();
                          final v = value; // allow service to trim and debounce
                          if (v.trim().isEmpty) {
                            if (svc.isSearchMode) {
                              svc.cancelSearch();
                            }
                          } else {
                            svc.startSearch(v);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'recherche',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    final svc = context.read<FabricsService>();
                                    if (svc.isSearchMode) {
                                      svc.cancelSearch();
                                    }
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      context.read<FabricsService>().cancelSearch();
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
            // Content: single infinite grid
            Expanded(child: _buildFabricGrid()),
          ],
        ),
      ),
    );
  }
}

// Removed local labeled field; provided by shared editor widget