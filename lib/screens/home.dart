import 'package:flutter/material.dart';
import '../widgets/section_header.dart';
import '../widgets/template_card.dart';
import 'package:provider/provider.dart';
import '../services/fabrics.service.dart';
import '../services/templates.service.dart';
import './main_navigation.dart';
import '../widgets/featured_fabrics_strip.dart';

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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}
