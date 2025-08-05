import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/material_card.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Widget _buildMaterialGrid(String category) {
    final materials = [
      {
        'title': 'Coton en toile de lin épaisse bleu',
        'date': '23/11/2024',
        'image': 'assets/images/blue_fabric.jpg',
      },
      {
        'title': 'Tissu bord-côte coton tubulaire',
        'date': '23/11/2024',
        'image': 'assets/images/green_fabric.jpg',
      },
      {
        'title': 'Tissu sherpa peluche teddy léger',
        'date': '23/11/2024',
        'image': 'assets/images/beige_fabric.jpg',
      },
      {
        'title': 'Tissu taffetas doublure, bleu clair coton',
        'date': '23/11/2024',
        'image': 'assets/images/light_blue_fabric.jpg',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
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
            title: material['title'] as String,
            date: material['date'] as String,
            image: material['image'] as String,
            isFavorite: index == 1 || index == 3, // Some favorites
            onFavoritePressed: () {
              debugPrint('Favorite pressed for ${material['title']}');
            },
          );
        },
      ),
    );
  }
}