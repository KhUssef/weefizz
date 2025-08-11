import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/material_card.dart';
import 'package:provider/provider.dart';
import '../services/materials.service.dart';
import 'package:provider/provider.dart';
import '../services/materials.service.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({Key? key}) : super(key: key);

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      Provider.of<MaterialsService>(context, listen: false).fetchAllMaterials();
      _fetched = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildMaterialGrid(String category) {
    return Consumer<MaterialsService>(
      builder: (context, service, _) {
        return RefreshIndicator(
          onRefresh: () => context.read<MaterialsService>().fetchAllMaterials(),
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
              final materials = (service.materials).where((mat) {
                final cat = (mat['category'] ?? '').toString().toLowerCase();
                return cat == category.toLowerCase();
              }).toList();
              if (materials.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('Aucun matériau trouvé.')),
                    SizedBox(height: 200),
                  ],
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: materials.length,
                itemBuilder: (context, index) {
                  final material = materials[index];
                  return MaterialCard(
                    title: material['name'] ?? 'Sans nom',
                    date: material['date'] ?? '',
                    image: material['image'] ?? null,
                    isFavorite: false,
                    onFavoritePressed: null,
                  );
                },
              );
            },
          ),
        );
      },
    );
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
            // Tab bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                tabs: const [
                  Tab(text: 'Coton'),
                  Tab(text: 'Feutrine'),
                  Tab(text: 'Recyclé'),
                  Tab(text: 'Polyester'),
                  Tab(text: 'Velours'),
                ],
              ),
            ),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMaterialGrid('Coton'),
                  _buildMaterialGrid('Feutrine'),
                  _buildMaterialGrid('Recyclé'),
                  _buildMaterialGrid('Polyester'),
                  _buildMaterialGrid('Velours'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}