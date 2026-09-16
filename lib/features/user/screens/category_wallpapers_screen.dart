import 'package:flutter/material.dart';
import '../../shared_widgets/fast_wallpaper_image.dart';
import '../controllers/wallpaper_cache.dart';
import '../controllers/favorites_storage.dart';
import 'detail_screen.dart';
import '../../../core/constants/colors.dart';

class CategoryWallpapersScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryWallpapersScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryWallpapersScreen> createState() => _CategoryWallpapersScreenState();
}

class _CategoryWallpapersScreenState extends State<CategoryWallpapersScreen> {
  final WallpaperCache _cache = WallpaperCache();
  List<Map<String, dynamic>> _allCategoryWalls = [];
  List<Map<String, dynamic>> _latestWalls = [];
  List<Map<String, dynamic>> _mostFavoriteWalls = [];
  List<String> _favoritedIds = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  Future<void> _loadCategoryData({bool forceRefresh = false}) async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      // ⚡ Single query (or in-memory cache) instead of 3 network calls!
      final results = await Future.wait([
        _cache.fetchWallpapersByCategory(widget.categoryId, forceRefresh: forceRefresh),
        FavoritesStorage.getFavorites(forceRefresh: forceRefresh),
      ]);

      final allWalls = results[0] as List<Map<String, dynamic>>;
      final favIds = results[1] as List<String>;

      // Partition in memory in microseconds (< 0.1ms)
      final latestSince = DateTime.now().subtract(const Duration(days: 3));
      final latest = allWalls.where((w) {
        final created = DateTime.tryParse(w['created_at']?.toString() ?? '');
        return created != null && created.isAfter(latestSince);
      }).toList();

      final favSorted = List<Map<String, dynamic>>.from(allWalls);
      favSorted.sort((a, b) {
        final fA = (a['fav_count'] as num?)?.toInt() ?? 0;
        final fB = (b['fav_count'] as num?)?.toInt() ?? 0;
        return fB.compareTo(fA);
      });
      final mostFav = favSorted.take(20).toList();

      if (mounted) {
        setState(() {
          _allCategoryWalls = allWalls;
          _latestWalls = latest;
          _mostFavoriteWalls = mostFav;
          _favoritedIds = favIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString();
        });
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadCategoryData,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: "All"),
              Tab(text: "Latest"),
              Tab(text: "Most Favorite"),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 50),
              const SizedBox(height: 16),
              const Text("Data load nahi ho saka", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _loadCategoryData,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Retry", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      physics: const BouncingScrollPhysics(),
      children: [
        _buildWallpaperGrid(_allCategoryWalls, "Is category mein abhi wallpapers nahi hain."),
        _buildWallpaperGrid(_latestWalls, "Abhi koi latest wallpaper nahi."),
        _buildWallpaperGrid(_mostFavoriteWalls, "Abhi koi favorite wallpaper nahi."),
      ],
    );
  }

  Widget _buildWallpaperGrid(List<Map<String, dynamic>> wallpapers, String emptyMessage) {
    if (wallpapers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 50),
              const SizedBox(height: 12),
              Text(emptyMessage, style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: wallpapers.length,
      itemBuilder: (context, index) => _buildWallpaperCard(wallpapers[index]),
    );
  }

  Widget _buildWallpaperCard(Map<String, dynamic> wallpaper) {
    final String idString = wallpaper['id'].toString();
    bool isPremium = wallpaper['is_premium'] ?? false;
    bool isAnimated = wallpaper['is_animated'] ?? false;
    bool isSaved = _favoritedIds.contains(idString);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(wallpaperData: wallpaper)),
        );
        _loadCategoryData();
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
              child: isAnimated
                  ? Container(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      child: const Center(
                        child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 40),
                      ),
                    )
                  : FastWallpaperImage(
                      imageUrl: wallpaper['url'] ?? '',
                      memCacheWidth: 400,
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
            if (isAnimated)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
