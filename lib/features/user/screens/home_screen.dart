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
  List<Map<String, dynamic>> _liveWallpapers = [];
  List<String> _favoritedIds = [];
  bool _isLoading = false;

  final List<List<Color>> _liveCardGradients = const [
    [Color(0xFF6A11CB), Color(0xFF2575FC)], // Neon Purple -> Blue
    [Color(0xFFFF416C), Color(0xFFFF4B2B)], // Coral Pink -> Fire Red
    [Color(0xFF00B4DB), Color(0xFF0083B0)], // Electric Cyan
    [Color(0xFF8A2387), Color(0xFFE94057)], // Magenta Sunset
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Emerald Teal
    [Color(0xFFF7971E), Color(0xFFFFD200)], // Amber Gold
  ];

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
      final Map<int, String> catNameMap = {
        for (final c in cats) (c['id'] as int): (c['name'] as String)
      };

      for (final wall in walls) {
        final catId = wall['category_id'] as int;
        catMap.putIfAbsent(catId, () => []).add(wall);
      }

      // Filter live / animated wallpapers
      final liveWalls = walls.where((wall) {
        final isAnim = wall['is_animated'];
        final url = (wall['url'] ?? '').toString().toLowerCase();
        return (isAnim == true || isAnim == 1 || isAnim == 'true') ||
               url.endsWith('.mp4') ||
               url.endsWith('.mov') ||
               url.endsWith('.webm') ||
               url.endsWith('.avi') ||
               url.endsWith('.mkv') ||
               url.contains('.mp4?') ||
               url.contains('.mov?') ||
               url.contains('video');
      }).toList();

      for (final wall in liveWalls) {
        final cid = wall['category_id'];
        if (cid != null && catNameMap.containsKey(cid)) {
          wall['category_name'] = catNameMap[cid];
        }
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _wallpapersByCategory = catMap;
          _liveWallpapers = liveWalls;
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
            const SizedBox(height: 6),
            // 🔥 Live Wallpapers Row right below search bar
            if (_liveWallpapers.isNotEmpty) ...[
              _buildLiveWallpapersSection(),
              const SizedBox(height: 6),
            ],
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
        const padding = 32.0; // left + right padding
        const spacing = 8.0;
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
                separatorBuilder: (_, __) => const SizedBox(width: spacing),
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

  // 🔥 Live Wallpapers Horizontal Section right under Search Bar
  Widget _buildLiveWallpapersSection() {
    if (_liveWallpapers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFFFF6B4A)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3366).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                "Live Wallpapers",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3366).withValues(alpha: 0.18),
                  border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.5), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3366),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${_liveWallpapers.length} LIVE",
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _liveWallpapers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final wallpaper = _liveWallpapers[index];
              return _buildLiveCard(wallpaper, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveCard(Map<String, dynamic> wallpaper, int index) {
    final String idString = wallpaper['id'].toString();
    final bool isPremium = wallpaper['is_premium'] ?? false;
    final bool isSaved = _favoritedIds.contains(idString);
    final gradient = _liveCardGradients[index % _liveCardGradients.length];
    final categoryName = wallpaper['category_name'] ?? 'Live Video';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(wallpaperData: wallpaper)),
        );
        final savedFavs = await FavoritesStorage.getFavorites();
        if (mounted) setState(() => _favoritedIds = savedFavs);
      },
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Glass gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),
              // Center Luminous Play button
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
              // Top-left LIVE badge
              Positioned(
                top: 9,
                left: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 6),
                      SizedBox(width: 3.5),
                      Text(
                        "LIVE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Top-right actions
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPremium) ...[
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 4),
                    ],
                    GestureDetector(
                      onTap: () => _toggleFavorite(idString),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isSaved ? Colors.redAccent : Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom category title & tap to play hint
              Positioned(
                bottom: 8,
                left: 6,
                right: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoryName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Tap to play",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildWallpaperCard(Map<String, dynamic> wallpaper) {
    final String idString = wallpaper['id'].toString();
    final bool isPremium = wallpaper['is_premium'] ?? false;
    final url = (wallpaper['url'] ?? '').toString().toLowerCase();
    final bool isAnimated = (wallpaper['is_animated'] == true) ||
                            url.endsWith('.mp4') ||
                            url.endsWith('.mov') ||
                            url.contains('.mp4?') ||
                            url.contains('.mov?') ||
                            url.contains('video');
    final bool isSaved = _favoritedIds.contains(idString);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(wallpaperData: wallpaper)),
        );
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
              child: isAnimated
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.25),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    )
                  : Image.network(
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
            if (isAnimated)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 5),
                      SizedBox(width: 3),
                      Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ],
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
