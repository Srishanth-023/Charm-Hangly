import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../../core/models/charm.dart';
import '../../../core/models/charm_catalog.dart';
import '../../../core/models/settings.dart';
import '../../../core/persistence/settings_storage.dart';

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
    List<Charm> charms;
    if (_searchQuery.isNotEmpty) {
      charms = CharmCatalog.search(_searchQuery);
    } else {
      charms = CharmCatalog.byCategory(_selectedCategory);
    }

    return Scaffold(
      backgroundColor: HanglyTheme.background,
      appBar: AppBar(
        title: const Text('Charm Library'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
              style: const TextStyle(color: HanglyTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search 70+ charms...',
                hintStyle: const TextStyle(color: HanglyTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, color: HanglyTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: HanglyTheme.textSecondary),
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
                  borderSide: const BorderSide(color: HanglyTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: HanglyTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: HanglyTheme.primary),
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
                ? const Center(
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
                                        child: SvgPicture.asset(
                                          charm.assetPath,
                                          fit: BoxFit.contain,
                                          placeholderBuilder: (_) =>
                                              const CircularProgressIndicator.adaptive(),
                                        ),
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
                                      style: const TextStyle(
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
                                    decoration: const BoxDecoration(
                                      color: HanglyTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
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
          ),
        ],
      ),
    );
  }
}
