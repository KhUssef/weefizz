import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/template_card.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen>
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
                  Tab(text: 'Veste'),
                  Tab(text: 'Pantalon'),
                  Tab(text: 'Chaussure'),
                  Tab(text: 'Robe'),
                  Tab(text: 'Chemise'),
                ],
              ),
            ),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTemplateList('Veste'),
                  _buildTemplateList('Pantalon'),
                  _buildTemplateList('Chaussure'),
                  _buildTemplateList('Robe'),
                  _buildTemplateList('Chemise'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList(String category) {
    final templates = [
      {
        'title': 'Veste complet moderne',
        'date': '23/11/2024',
        'image': 'assets/images/jacket1.jpg',
      },
      {
        'title': 'Veste blazeur',
        'date': '23/11/2024',
        'image': 'assets/images/jacket2.jpg',
      },
      {
        'title': 'Veste softshell Race',
        'date': '23/11/2024',
        'image': 'assets/images/jacket3.jpg',
      },
      {
        'title': 'Veste homme Norman',
        'date': '23/11/2024',
        'image': 'assets/images/jacket4.jpg',
      },
      {
        'title': 'Veste coupe-vent Flat Track',
        'date': '23/11/2024',
        'image': 'assets/images/jacket5.jpg',
      },
      {
        'title': 'Veste Softshell zippée',
        'date': '23/11/2024',
        'image': 'assets/images/jacket6.jpg',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final template = templates[index];
          return TemplateCard(
            title: template['title'] as String,
            date: template['date'] as String,
            image: template['image'] as String,
          );
        },
      ),
    );
  }
}