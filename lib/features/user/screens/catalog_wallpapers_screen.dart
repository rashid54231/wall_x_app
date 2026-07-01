import 'package:flutter/material.dart';
import '../controllers/wallpaper_cache.dart';
import '../../../core/constants/colors.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalogWallpapers();
  }

  Future<void> _loadCatalogWallpapers() async {
    try {
      final data = await _cache.fetchCatalogWallpapers(widget.catalogId);
      if (mounted) {
        setState(() {
          _wallpapersList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Wallpapers load karne mein masla aaya: $e"),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.catalogTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _wallpapersList.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Is collection mein abhi tak koi wallpaper upload nahi hua!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      )
          : RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadCatalogWallpapers,
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.6,
          ),
          itemCount: _wallpapersList.length,
          itemBuilder: (context, index) {
            final wallpaper = _wallpapersList[index];
            final bool isPremium = wallpaper['is_premium'] ?? false;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailScreen(wallpaperData: wallpaper),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.network(
                        wallpaper['url'] ?? '',
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
                    if (isPremium)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber[600],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.black
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
    );
  }
}
