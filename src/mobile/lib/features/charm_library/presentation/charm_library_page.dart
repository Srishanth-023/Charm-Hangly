import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme.dart';
import '../../../core/models/charm.dart';
import '../../../core/models/charm_catalog.dart';
import '../../../core/models/settings.dart';
import '../../../core/persistence/settings_storage.dart';
import '../../../core/widgets/charm_widget.dart';
import '../../hangly_scene/physics/charm_metrics.dart';
import '../../../core/models/rope_style.dart';

class CharmLibraryPage extends StatefulWidget {
  final Charm currentCharm;
  final HanglySettings settings;
  final SettingsStorage storage;

  const CharmLibraryPage({
    super.key,
    required this.currentCharm,
    required this.settings,
    required this.storage,
  });

  @override
  State<CharmLibraryPage> createState() => _CharmLibraryPageState();
}

class _CharmLibraryPageState extends State<CharmLibraryPage> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  late List<String> _favourites;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _favourites = List.from(widget.settings.favourites);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFavourite(String charmId) async {
    setState(() {
      if (_favourites.contains(charmId)) {
        _favourites.remove(charmId);
      } else {
        _favourites.add(charmId);
      }
    });

    final updated = widget.settings.copyWith(favourites: _favourites);
    await widget.storage.saveSettings(updated);
  }

  @override
  Widget build(BuildContext context) {
    final allCustom = widget.settings.customCharms;
    List<Charm> charms;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      charms = [
        ...CharmCatalog.search(_searchQuery),
        ...allCustom.where((c) => c.name.toLowerCase().contains(q)),
      ];
    } else {
      if (_selectedCategory == 'all') {
        charms = [...CharmCatalog.byCategory('all'), ...allCustom];
      } else if (_selectedCategory == 'favourites') {
        final allCharms = [...CharmCatalog.byCategory('all'), ...allCustom];
        charms = allCharms.where((c) => _favourites.contains(c.id)).toList();
      } else if (_selectedCategory == 'custom') {
        charms = allCustom;
      } else {
        charms = CharmCatalog.byCategory(_selectedCategory);
      }
    }

    return Scaffold(
      backgroundColor: HanglyTheme.background,
      appBar: AppBar(
        title: Text('Collections'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: HanglyTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search 70+ charms...',
                hintStyle: TextStyle(color: HanglyTheme.textSecondary),
                prefixIcon: Icon(Icons.search, color: HanglyTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: HanglyTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: HanglyTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: HanglyTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: HanglyTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: HanglyTheme.primary),
                ),
              ),
            ),
          ),

          // 2. Category Filter Chips
          if (_searchQuery.isEmpty)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: CharmCatalog.categories.length,
                itemBuilder: (context, index) {
                  final cat = CharmCatalog.categories[index];
                  final isSelected = cat.id == _selectedCategory;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected ? Colors.black : HanglyTheme.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(cat.name),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: HanglyTheme.primary,
                      backgroundColor: HanglyTheme.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : HanglyTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? HanglyTheme.primary : HanglyTheme.border,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat.id);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // 3. Charm Grid
          Expanded(
            child: charms.isEmpty
                ? Center(
                    child: Text(
                      'No charms found',
                      style: TextStyle(color: HanglyTheme.textSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: charms.length,
                    itemBuilder: (context, index) {
                      final charm = charms[index];
                      final isEquipped = charm.id == widget.currentCharm.id;
                      final isFav = _favourites.contains(charm.id);

                      return InkWell(
                        onTap: () => Navigator.pop(context, charm),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: HanglyTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isEquipped ? HanglyTheme.primary : HanglyTheme.border,
                              width: isEquipped ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: CharmWidget(charm: charm),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      charm.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isEquipped
                                            ? HanglyTheme.primary
                                            : HanglyTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      charm.category,
                                      style: TextStyle(
                                        color: HanglyTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Favorite button
                              Positioned(
                                top: 6,
                                right: 6,
                                child: IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    size: 20,
                                    color: isFav ? Colors.redAccent : HanglyTheme.textSecondary,
                                  ),
                                  onPressed: () => _toggleFavourite(charm.id),
                                ),
                              ),

                              // Equipped badge
                              if (isEquipped)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: HanglyTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ), // ends Expanded
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomCharm,
        backgroundColor: HanglyTheme.primary,
        icon: Icon(Icons.add, color: Colors.black),
        label: Text('Add Custom', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ), // ends floatingActionButton
    ); // ends Scaffold
  }

  Future<void> _addCustomCharm() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg'],
    );
    if (result == null || result.isEmpty || result.single.path == null) return;
    
    if (!mounted) return;
    final controller = TextEditingController(text: result.single.name.split('.').first);
    final customName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HanglyTheme.surfaceElevated,
          title: Text('Name your charm', style: TextStyle(color: HanglyTheme.textPrimary)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: HanglyTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Charm Name',
              hintStyle: TextStyle(color: HanglyTheme.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: HanglyTheme.primary)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: HanglyTheme.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel', style: TextStyle(color: HanglyTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('Save', style: TextStyle(color: HanglyTheme.primary)),
            ),
          ],
        );
      }
    );

    if (customName == null || customName.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = result.single.name;
    final savedImage = File('${appDir.path}/$fileName');
    await File(result.single.path!).copy(savedImage.path);
    
    final newCharm = Charm(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: customName,
      category: 'custom',
      assetPath: savedImage.path,
      metrics: const CharmMetrics(mass: 3.0, radiusRatio: 0.15, knotInset: 0.90),
      primaryColor: Colors.white,
      description: 'A custom charm added from your device.',
      isCustom: true,
    );
    
    final updatedCharms = List<Charm>.from(widget.settings.customCharms)..add(newCharm);
    final updatedSettings = widget.settings.copyWith(customCharms: updatedCharms);
    await widget.storage.saveSettings(updatedSettings);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Custom charm added!'), backgroundColor: HanglyTheme.primary),
      );
      Navigator.pop(context, newCharm);
    }
  }
}
