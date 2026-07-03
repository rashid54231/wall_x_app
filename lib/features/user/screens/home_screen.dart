import 'package:flutter/material.dart';
import '../controllers/wallpaper_cache.dart';
import '../controllers/favorites_storage.dart';
import 'detail_screen.dart';
import 'category_wallpapers_screen.dart';
import '../../../core/constants/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WallpaperCache _cache = WallpaperCache();

  List<Map<String, dynamic>> _categories = [];
  Map<int, List<Map<String, dynamic>>> _wallpapersByCategory = {};
  List<String> _favoritedIds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialUserData();
  }

  Future<void> _loadInitialUserData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _cache.fetchCategories(),
        _cache.fetchAllWallpapers(),
        FavoritesStorage.getFavorites(),
      ]);

      final cats = results[0] as List<Map<String, dynamic>>;
      final walls = results[1] as List<Map<String, dynamic>>;
      final savedFavs = results[2] as List<String>;

      // Pre-compute category map to avoid filtering in itemBuilder
      final Map<int, List<Map<String, dynamic>>> catMap = {};
      for (final wall in walls) {
        final catId = wall['category_id'] as int;
        catMap.putIfAbsent(catId, () => []).add(wall);
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _wallpapersByCategory = catMap;
          _favoritedIds = savedFavs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Data load karne mein masla aaya: $e", isError: true);
      }
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildCategoryPortionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPortionsList() {
    if (_categories.isEmpty) {
      return const Center(child: Text("No categories available.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      itemBuilder: (context, catIndex) {
        final category = _categories[catIndex];
        final int catId = category['id'];
        final String catName = category['name'];

        // O(1) lookup instead of O(n) filter per frame
        final categoryWalls = _wallpapersByCategory[catId] ?? [];

        if (categoryWalls.isEmpty) return const SizedBox.shrink();

        // Screen size ke hisab se kitne wallpapers dikhane hain
        final screenWidth = MediaQuery.of(context).size.width;
        final padding = 32.0; // left + right padding
        final spacing = 8.0;
        int cardsVisible;
        if (screenWidth < 360) {
          cardsVisible = 2;
        } else if (screenWidth < 500) {
          cardsVisible = 3;
        } else if (screenWidth < 700) {
          cardsVisible = 4;
        } else {
          cardsVisible = 5;
        }
        final displayCount = cardsVisible < categoryWalls.length ? cardsVisible : categoryWalls.length;
        final displayWalls = categoryWalls.take(displayCount).toList();
        final cardWidth = (screenWidth - padding - (spacing * (cardsVisible - 1))) / cardsVisible;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    catName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryWallpapersScreen(
                            categoryId: catId,
                            categoryName: catName,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        if (categoryWalls.length > displayCount)
                          Text("View All (${categoryWalls.length - displayCount} more) ",
                              style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        if (categoryWalls.length <= displayCount)
                          const Text("View All", style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.blueAccent, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 240,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: displayWalls.length,
                separatorBuilder: (_, __) => SizedBox(width: spacing),
                itemBuilder: (context, wallIndex) {
                  final wallpaper = displayWalls[wallIndex];
                  return SizedBox(
                    width: cardWidth,
                    child: _buildWallpaperCard(wallpaper),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildWallpaperCard(Map<String, dynamic> wallpaper) {
    final String idString = wallpaper['id'].toString();
    bool isPremium = wallpaper['is_premium'] ?? false;
    bool isSaved = _favoritedIds.contains(idString);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(wallpaperData: wallpaper)),
        );
        // Only refresh favorites, not the entire dataset
        final savedFavs = await FavoritesStorage.getFavorites();
        if (mounted) setState(() => _favoritedIds = savedFavs);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.network(
                wallpaper['url'],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 300,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: child,
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 32),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () => _toggleFavorite(idString),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isSaved ? Colors.redAccent : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            if (isPremium)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 1.2),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
