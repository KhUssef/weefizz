import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/section_header.dart';
import '../widgets/material_card.dart';
import '../widgets/template_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Bonjour, Vladimir 👋',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Materials section
              SectionHeader(
                title: 'Matières',
                onSeeAllPressed: () {
                  debugPrint('See all materials pressed');
                }, onViewAll: () {  },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    SizedBox(
                      width: 160,
                      child: MaterialCard(
                        title: 'Tissu en toile de lin épaisse bleu',
                        date: '23/11/2024',
                        image: 'assets/images/blue_fabric.jpg',
                        isFavorite: true,
                        onFavoritePressed: () {
                          debugPrint('Favorite pressed');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: MaterialCard(
                        title: 'Coton biologique',
                        date: '23/11/2024',
                        onFavoritePressed: () {
                          debugPrint('Favorite pressed');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Templates section
              SectionHeader(
                title: 'Gabarits',
                onSeeAllPressed: () {
                  debugPrint('See all templates pressed');
                }, onViewAll: () {  },
              ),
              const SizedBox(height: 16),
              Column(
                children: const [
                  TemplateCard(
                    title: 'Veste complet moderne',
                    date: '23/11/2024',
                  ),
                  TemplateCard(
                    title: 'Espadrille en tissures',
                    date: '23/11/2024',
                  ),
                  TemplateCard(
                    title: 'Chemise en lin jaune',
                    date: '23/11/2024',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
