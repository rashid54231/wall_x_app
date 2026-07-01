import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<void> _loadCategoryData() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final supabase = Supabase.instance.client;

      // Parallel queries - simple and direct
      final allFuture = supabase
          .from('wallpapers')
          .select()
          .eq('category_id', widget.categoryId)
          .order('created_at', ascending: false);

      final latestSince = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      final latestFuture = supabase
          .from('wallpapers')
          .select()
          .eq('category_id', widget.categoryId)
          .gte('created_at', latestSince)
          .order('created_at', ascending: false);

      final favFuture = supabase
          .from('wallpapers')
          .select()
          .eq('category_id', widget.categoryId)
          .order('created_at', ascending: false)
          .limit(20);

      final favsFuture = FavoritesStorage.getFavorites();

      final results = await Future.wait<dynamic>([allFuture, latestFuture, favFuture, favsFuture]);

      if (mounted) {
        setState(() {
          _allCategoryWalls = List<Map<String, dynamic>>.from(results[0] as List);
          _latestWalls = List<Map<String, dynamic>>.from(results[1] as List);
          _mostFavoriteWalls = List<Map<String, dynamic>>.from(results[2] as List);
          _favoritedIds = results[3] as List<String>;
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
              child: Image.network(
                wallpaper['url'] ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 400,
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
