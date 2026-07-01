import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/colors.dart';
import '../controllers/wallpaper_cache.dart';
import '../controllers/favorites_storage.dart';
import 'home_screen.dart';
import 'premium_screen.dart';
import 'detail_screen.dart';
import 'catalog_screen.dart';
import 'user_center_screen.dart';
import 'notification_screen.dart';
import 'search_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;
  final WallpaperCache _cache = WallpaperCache();

  List<Map<String, dynamic>> _allWallpapers = [];
  List<String> _favoritedIds = [];
  bool _isLoadingFavs = false;

  @override
  void initState() {
    super.initState();
    _loadFavoritesData();
  }

  Future<void> _loadFavoritesData() async {
    setState(() { _isLoadingFavs = true; });
    try {
      final results = await Future.wait([
        _cache.fetchAllWallpapers(),
        FavoritesStorage.getFavorites(),
      ]);
      if (mounted) {
        setState(() {
          _allWallpapers = results[0] as List<Map<String, dynamic>>;
          _favoritedIds = results[1] as List<String>;
          _isLoadingFavs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingFavs = false; });
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
    final titleColor = isDark ? Colors.white : Colors.black;

    final favoriteWallpapers = _allWallpapers.where((wall) {
      return _favoritedIds.contains(wall['id'].toString());
    }).toList();

    final List<Widget> tabs = [
      const HomeScreen(),
      _buildDynamicFavoritesScreen(favoriteWallpapers),
      const PremiumTabScreen(),
      const CatalogScreen(),
      const UserCenterScreen(),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : Colors.white,
      appBar: _currentIndex == 4
          ? null
          : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Hello, Explorer", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              Text("Find Your Style", style: TextStyle(fontSize: 22, color: titleColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: IconButton(
              icon: Icon(Icons.notifications_active_rounded, color: titleColor, size: 24),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentIndex != 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SearchScreen()),
                        );
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(color: isDark ? AppColors.surface : Colors.grey[200], borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(child: Text("Search wallpapers...", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 15))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _loadFavoritesData();
                      setState(() => _currentIndex = 1);
                    },
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: _currentIndex == 1 ? Colors.redAccent.withValues(alpha: 0.2) : (isDark ? AppColors.surface : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(16),
                        border: _currentIndex == 1 ? Border.all(color: Colors.redAccent, width: 1.5) : null,
                      ),
                      child: Icon(Icons.favorite_rounded, color: _currentIndex == 1 ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87), size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 2),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: _currentIndex == 2 ? Colors.amber.withValues(alpha: 0.2) : (isDark ? AppColors.surface : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(16),
                        border: _currentIndex == 2 ? Border.all(color: Colors.amber, width: 1.5) : null,
                      ),
                      child: Icon(Icons.auto_awesome_rounded, color: _currentIndex == 2 ? Colors.amber : (isDark ? Colors.white70 : Colors.black87), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: tabs[_currentIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface.withValues(alpha: 0.9) : Colors.grey[200],
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.dashboard_customize_rounded, "Explore", isDark),
                _buildNavItem(3, Icons.folder_special_rounded, "Catalogs", isDark, activeColor: Colors.amber),
                _buildNavItem(4, Icons.account_circle_rounded, "Profile", isDark, activeColor: Colors.tealAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark, {Color activeColor = AppColors.primary}) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[600]), size: 22),
            const SizedBox(width: 6),
            if (isSelected)
              Text(
                label,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  SliverGridDelegate _gridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;
    if (width >= 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.6;
    } else if (width >= 900) {
      crossAxisCount = 3;
      childAspectRatio = 0.65;
    } else if (width >= 600) {
      crossAxisCount = 2;
      childAspectRatio = 0.7;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 0.8;
    }
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
  }

  Widget _buildDynamicFavoritesScreen(List<Map<String, dynamic>> favoriteWallpapers) {
    if (_isLoadingFavs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (favoriteWallpapers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text("No favorites added yet!", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: _gridDelegate(context),
      itemCount: favoriteWallpapers.length,
      itemBuilder: (context, index) {
        final wallpaper = favoriteWallpapers[index];
        final String idString = wallpaper['id'].toString();
        bool isPremium = wallpaper['is_premium'] ?? false;

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DetailScreen(wallpaperData: wallpaper)),
            );
            _loadFavoritesData();
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
                      child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18),
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
      },
    );
  }
}
