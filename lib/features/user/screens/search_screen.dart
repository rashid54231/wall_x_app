import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../main.dart';
import '../controllers/wallpaper_cache.dart';
import '../controllers/favorites_storage.dart';
import 'detail_screen.dart';
import '../../../core/constants/colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final WallpaperCache _cache = WallpaperCache();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _allWallpapers = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _favoritedIds = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  late AnimationController _staggerController;

  static const List<List<Color>> _gradients = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFFF093FB), Color(0xFFF5576C)],
    [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    [Color(0xFF43E97B), Color(0xFF38F9D7)],
    [Color(0xFFFA709A), Color(0xFFFEE140)],
    [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _cache.fetchAllWallpapers(),
        FavoritesStorage.getFavorites(),
      ]);
      if (mounted) {
        setState(() {
          _allWallpapers = results[0] as List<Map<String, dynamic>>;
          _favoritedIds = results[1] as List<String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      _staggerController.reset();
      return;
    }

    setState(() {
      _hasSearched = true;
      _isLoading = true;
    });

    _searchWallpapers(query.trim().toLowerCase());
  }

  Future<void> _searchWallpapers(String query) async {
    try {
      final results = await _cache.searchWallpapers(query);
      if (results.isNotEmpty && mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        _staggerController.forward(from: 0);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _searchResults = _allWallpapers.where((wall) {
          final catName = (wall['category_name'] ?? '').toString().toLowerCase();
          return catName.contains(query);
        }).toList();
        _isLoading = false;
      });
      _staggerController.forward(from: 0);
    }
  }

  Future<void> _toggleFavorite(String id) async {
    final isNowFav = await FavoritesStorage.toggleFavorite(id);
    setState(() {
      if (isNowFav) {
        _favoritedIds.add(id);
      } else {
        _favoritedIds.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8F9FA),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D0D0D), Color(0xFF000000)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0F0F5), Color(0xFFF8F9FA)],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(isDark),
              _buildSearchSection(isDark),
              Expanded(
                child: _isLoading && _hasSearched
                    ? _buildShimmerLoading(isDark)
                    : !_hasSearched
                        ? _buildInitialState(isDark)
                        : _searchResults.isEmpty
                            ? _buildEmptyState(isDark)
                            : _buildSearchResults(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _buildGlassButton(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Discover",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Find your perfect wallpaper",
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildGlassButton(
            icon: Icons.tune_rounded,
            isDark: isDark,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(icon, color: isDark ? Colors.white70 : Colors.black87, size: 20),
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Search by category...",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _performSearch,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _performSearch('');
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: isDark ? Colors.grey[500] : Colors.grey[500], size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.05)],
              ),
            ),
            child: Icon(Icons.explore_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          Text(
            "Start Exploring",
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Type a category name to discover\namazing wallpapers",
              style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500], fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          _buildSuggestionChips(isDark),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(bool isDark) {
    final suggestions = ["Nature", "Abstract", "Dark", "Anime", "Cars", "Space"];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((s) {
        return GestureDetector(
          onTap: () {
            _searchController.text = s;
            _performSearch(s);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(s, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.withValues(alpha: 0.12), Colors.deepOrange.withValues(alpha: 0.05)],
              ),
            ),
            child: const Icon(Icons.search_off_rounded, size: 48, color: Colors.orangeAccent),
          ),
          const SizedBox(height: 24),
          Text(
            "No Results Found",
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "We couldn't find anything for\n\"${_searchController.text}\"",
              style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500], fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              _searchController.clear();
              _performSearch('');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Text("Clear Search", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${_searchResults.length} found",
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "results for \"${_searchController.text}\"",
                style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) => _buildWallpaperCard(_searchResults[index], isDark, index),
          ),
        ),
      ],
    );
  }

  Widget _buildWallpaperCard(Map<String, dynamic> wallpaper, bool isDark, int index) {
    final String idString = wallpaper['id'].toString();
    bool isPremium = wallpaper['is_premium'] ?? false;
    bool isSaved = _favoritedIds.contains(idString);
    final gradient = _gradients[index % _gradients.length];

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) => DetailScreen(wallpaperData: wallpaper),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
          ),
        );
        final savedFavs = await FavoritesStorage.getFavorites();
        if (mounted) setState(() => _favoritedIds = savedFavs);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: wallpaper['url'] ?? '',
                fit: BoxFit.cover,
                memCacheWidth: 400,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradient)),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradient)),
                  child: const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 32),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () => _toggleFavorite(idString),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isSaved ? Colors.redAccent.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (isSaved) BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 8),
                      ],
                    ),
                    child: Icon(
                      isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              if (isPremium)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                  ),
                ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    "${wallpaper['category_name'] ?? 'Wallpaper'}",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
