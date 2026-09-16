import 'package:flutter/material.dart';
import '../../shared_widgets/fast_wallpaper_image.dart';
import '../controllers/wallpaper_cache.dart';
import '../controllers/favorites_storage.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/wallpaper_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail_screen.dart';

class CatalogWallpapersScreen extends StatefulWidget {
  final int catalogId;
  final String catalogTitle;

  const CatalogWallpapersScreen({
    super.key,
    required this.catalogId,
    required this.catalogTitle,
  });

  @override
  State<CatalogWallpapersScreen> createState() => _CatalogWallpapersScreenState();
}

class _CatalogWallpapersScreenState extends State<CatalogWallpapersScreen> {
  final WallpaperCache _cache = WallpaperCache();
  List<Map<String, dynamic>> _wallpapersList = [];
  List<String> _favoritedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalogWallpapers();
  }

  Future<void> _loadCatalogWallpapers({bool forceRefresh = false}) async {
    try {
      final results = await Future.wait([
        _cache.fetchCatalogWallpapers(widget.catalogId, forceRefresh: forceRefresh),
        FavoritesStorage.getFavorites(),
      ]);

      final data = results[0] as List<Map<String, dynamic>>;
      final favs = results[1] as List<String>;

      if (mounted) {
        setState(() {
          _wallpapersList = data;
          _favoritedIds = favs;
          _isLoading = false;
        });

        // ⚡ Pre-cache visible wallpapers
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (final w in data.take(12)) {
            final u = w['url'] as String?;
            if (u != null && u.isNotEmpty && !u.contains('.mp4') && !u.contains('.mov')) {
              precacheImage(
                CachedNetworkImageProvider(u, cacheManager: WallpaperImageCacheManager.instance),
                context,
              ).catchError((_) {});
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Wallpapers load nahi ho sake: $e"),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(String id) async {
    final isNowFav = await FavoritesStorage.toggleFavorite(id);
    if (mounted) {
      setState(() {
        if (isNowFav) {
          _favoritedIds.add(id);
        } else {
          _favoritedIds.remove(id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.catalogTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!_isLoading)
              Text(
                "${_wallpapersList.length} wallpapers in pack",
                style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _wallpapersList.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey[600]),
              const SizedBox(height: 16),
              const Text(
                "Pack Empty",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "Is collection mein abhi tak koi wallpaper upload nahi hua!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        color: Colors.amber,
        onRefresh: () => _loadCatalogWallpapers(forceRefresh: true),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemCount: _wallpapersList.length,
          itemBuilder: (context, index) {
            final wallpaper = _wallpapersList[index];
            final String idString = wallpaper['id'].toString();
            final bool isPremium = wallpaper['is_premium'] ?? false;
            final bool isSaved = _favoritedIds.contains(idString);

            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailScreen(wallpaperData: wallpaper),
                  ),
                );
                final favs = await FavoritesStorage.getFavorites();
                if (mounted) setState(() => _favoritedIds = favs);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FastWallpaperImage(
                        imageUrl: wallpaper['url'] ?? '',
                        memCacheWidth: 400,
                      ),
                      // Favorite button top-left
                      Positioned(
                        top: 8,
                        left: 8,
                        child: GestureDetector(
                          onTap: () => _toggleFavorite(idString),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isSaved ? Colors.redAccent : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      // Premium badge top-right
                      if (isPremium)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.amber, width: 1),
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              size: 13,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
