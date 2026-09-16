import 'package:flutter/material.dart';
import '../../shared_widgets/fast_wallpaper_image.dart';
import '../controllers/wallpaper_cache.dart';
import '../../../core/constants/colors.dart';
import 'catalog_wallpapers_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with SingleTickerProviderStateMixin {
  final WallpaperCache _cache = WallpaperCache();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allCatalogs = [];
  List<Map<String, dynamic>> _filteredCatalogs = [];
  List<Map<String, dynamic>> _categories = [];

  int? _selectedCategoryId; // null means 'All'
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isGridView = true; // Toggle between 2-col poster grid and wide banner magazine view

  @override
  void initState() {
    super.initState();
    // ⚡ Instant 0ms cache-first rendering
    if (_cache.allCatalogs.isNotEmpty) {
      _allCatalogs = _cache.allCatalogs;
      _filteredCatalogs = _allCatalogs;
      _isLoading = false;
    }
    if (_cache.allCategories.isNotEmpty) {
      _categories = _cache.allCategories;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    try {
      final results = await Future.wait([
        _cache.fetchAllCatalogs(forceRefresh: forceRefresh),
        _cache.fetchCategories(forceRefresh: forceRefresh),
      ]);

      if (mounted) {
        setState(() {
          _allCatalogs = results[0];
          _categories = results[1];
          _applyFilters();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCatalogs = _allCatalogs.where((c) {
        final matchesQuery = query.isEmpty ||
            (c['title'] ?? '').toString().toLowerCase().contains(query);

        final matchesCategory = _selectedCategoryId == null ||
            (c['category_id'] != null && c['category_id'] == _selectedCategoryId);

        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  void _openCatalog(Map<String, dynamic> catalog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CatalogWallpapersScreen(
          catalogId: catalog['id'],
          catalogTitle: catalog['title'] ?? 'Collection Pack',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 🌌 Ambient background decorative glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: -80,
            child: Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.deepPurple.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              color: Colors.amber,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                setState(() => _isRefreshing = true);
                await _loadData(forceRefresh: true);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. Sleek Modern Header
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),

                  // 2. Search Box
                  SliverToBoxAdapter(
                    child: _buildSearchBar(),
                  ),

                  // 3. Category Filter Chips (Horizontal Scroller)
                  if (_categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildCategoryPills(),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 4. Main Body Content
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: _buildSkeletonLoading(),
                    )
                  else if (_filteredCatalogs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else ...[
                    // 🌟 Spotlight Featured Banner (Shown when no search is active and category is 'All')
                    if (_searchController.text.isEmpty &&
                        _selectedCategoryId == null &&
                        _filteredCatalogs.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _buildSpotlightHeroCard(_filteredCatalogs.first),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 14)),
                      SliverToBoxAdapter(
                        child: _buildSectionLabel("EXPLORE ALL PACKS", _filteredCatalogs.length),
                      ),
                    ],

                    // 🎴 Catalogs Grid / List View
                    if (_isGridView)
                      _buildPosterGrid()
                    else
                      _buildMagazineList(),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 30),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withValues(alpha: 0.2),
                        Colors.deepOrange.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        "${_allCatalogs.length} CURATED COLLECTIONS",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Wallpaper Catalogs",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Thematic packs designed to transform your screen",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: View Toggle & Refresh
          Row(
            children: [
              // Grid / Magazine View Toggle
              GestureDetector(
                onTap: () => setState(() => _isGridView = !_isGridView),
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Icon(
                    _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh Button
              GestureDetector(
                onTap: () {
                  setState(() => _isRefreshing = true);
                  _loadData(forceRefresh: true);
                },
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: _isRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _searchController.text.isNotEmpty
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search packs, styles, or themes...",
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13.5),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CATEGORY PILLS (FILTERS)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryPills() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategoryId == null;
            return _buildPill(
              label: "All Collections",
              icon: Icons.all_inclusive_rounded,
              isSelected: isSelected,
              onTap: () {
                setState(() => _selectedCategoryId = null);
                _applyFilters();
              },
            );
          }

          final cat = _categories[index - 1];
          final catId = cat['id'] as int?;
          final catName = cat['name'] ?? 'Category';
          final isSelected = _selectedCategoryId == catId;

          return _buildPill(
            label: catName,
            icon: Icons.folder_rounded,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedCategoryId = isSelected ? null : catId;
              });
              _applyFilters();
            },
          );
        },
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                )
              : null,
          color: isSelected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.amber
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black87 : Colors.grey[400],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.grey[300],
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                height: 12,
                width: 3.5,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Text(
            "$count Sets",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPOTLIGHT FEATURED HERO CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSpotlightHeroCard(Map<String, dynamic> catalog) {
    final title = catalog['title'] ?? 'Featured Collection';
    final coverUrl = catalog['cover_url'] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: GestureDetector(
        onTap: () => _openCatalog(catalog),
        child: Container(
          height: 205,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 🖼️ Fast Hero Background Image
                FastWallpaperImage(
                  imageUrl: coverUrl,
                  memCacheWidth: 650,
                ),

                // 🎭 Rich Layered Gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),

                // 🌟 Top Badges
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Spotlight Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text(
                              "SPOTLIGHT PACK",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quality Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          "4K ULTRA",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 📝 Bottom Content Details
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 12),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.amber.withValues(alpha: 0.9),
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Tap to open complete pack",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Glowing CTA Button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "EXPLORE",
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: Colors.black87, size: 15),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POSTER GRID (2 COLUMNS)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPosterGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final catalog = _filteredCatalogs[index];
            return _buildPosterCard(catalog, index);
          },
          childCount: _filteredCatalogs.length,
        ),
      ),
    );
  }

  Widget _buildPosterCard(Map<String, dynamic> catalog, int index) {
    final title = catalog['title'] ?? 'Collection';
    final coverUrl = catalog['cover_url'] ?? '';

    return GestureDetector(
      onTap: () => _openCatalog(catalog),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppColors.surface,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Wallpaper
              FastWallpaperImage(
                imageUrl: coverUrl,
                memCacheWidth: 380,
              ),

              // Glass Vignette & Depth
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.4, 0.75, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ),

              // Top Glass Tag
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.style_rounded, color: Colors.amber[300], size: 10),
                      const SizedBox(width: 4),
                      Text(
                        "SET #${index + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Details
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        height: 1.25,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 11,
                              color: Colors.amber.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "View Pack",
                              style: TextStyle(
                                color: Colors.amber.withValues(alpha: 0.9),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 24,
                          width: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAGAZINE / WIDE BANNER VIEW (ALTERNATIVE LAYOUT)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMagazineList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final catalog = _filteredCatalogs[index];
            final title = catalog['title'] ?? 'Collection';
            final coverUrl = catalog['cover_url'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => _openCatalog(catalog),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.surface,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FastWallpaperImage(
                          imageUrl: coverUrl,
                          memCacheWidth: 600,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.88),
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "COLLECTION #${index + 1}",
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "Browse all wallpapers in this pack",
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.amber,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.arrow_forward_rounded, color: Colors.black87, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: _filteredCatalogs.length,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SKELETON SHIMMER LOADING
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Spotlight Skeleton
          Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.amber.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Grid Skeleton
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.2),
                    Colors.amber.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.folder_open_rounded, size: 40, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Collections Found",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.isNotEmpty
                  ? "No pack matches \"${_searchController.text}\""
                  : "No collections available in this category.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _selectedCategoryId = null);
                _applyFilters();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  "Reset All Filters",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
