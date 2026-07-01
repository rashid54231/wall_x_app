import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/wallpaper_cache.dart';
import '../controllers/favorites_storage.dart';
import 'detail_screen.dart';
import 'premium_purchase_screen.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/premium_provider.dart';

class PremiumTabScreen extends ConsumerStatefulWidget {
  const PremiumTabScreen({super.key});

  @override
  ConsumerState<PremiumTabScreen> createState() => _PremiumTabScreenState();
}

class _PremiumTabScreenState extends ConsumerState<PremiumTabScreen> {
  final WallpaperCache _cache = WallpaperCache();
  List<Map<String, dynamic>> _premiumWallpapers = [];
  List<String> _favoritedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPremiumWallpapers();
  }

  Future<void> _loadPremiumWallpapers() async {
    try {
      final results = await Future.wait([
        _cache.fetchPremiumWallpapers(),
        FavoritesStorage.getFavorites(),
      ]);

      if (mounted) {
        setState(() {
          _premiumWallpapers = results[0] as List<Map<String, dynamic>>;
          _favoritedIds = results[1] as List<String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _handleWallpaperTap(Map<String, dynamic> wallpaper) async {
    final isUserPremium = ref.watch(premiumProvider);

    if (isUserPremium) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetailScreen(wallpaperData: wallpaper)),
      );
    } else {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PremiumPaywallScreen()),
      );
    }
    // Refresh favorites only
    final savedFavs = await FavoritesStorage.getFavorites();
    if (mounted) setState(() => _favoritedIds = savedFavs);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _premiumWallpapers.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.amber[600]),
            const SizedBox(height: 16),
            const Text(
              "No Premium Wallpapers",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        gridDelegate: _gridDelegate(context),
        itemCount: _premiumWallpapers.length,
        itemBuilder: (context, index) {
          final wallpaper = _premiumWallpapers[index];
          final String idString = wallpaper['id'].toString();
          bool isSaved = _favoritedIds.contains(idString);

          return GestureDetector(
            onTap: () => _handleWallpaperTap(wallpaper),
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
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isSaved ? Colors.redAccent : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 1.5),
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PremiumPaywallScreen extends ConsumerStatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  ConsumerState<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen> {
  bool _isBuying = false;

  Future<void> _buySubscription() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PremiumPurchaseScreen()),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, size: 65, color: Colors.amber),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "WALL-X PREMIUM",
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Unlock unlimited access to ultimate ultra-HD wallpapers setup.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 35),
                  _buildFeatureRow(Icons.bolt_rounded, "Access 4K Ultra-HD Premium Wallpapers"),
                  _buildFeatureRow(Icons.no_accounts_rounded, "Complete Ad-Free Smooth Experience"),
                  _buildFeatureRow(Icons.palette_rounded, "Exclusive Live Pro Filters & Customizer"),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Monthly Pro Plan", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Cancel anytime. Auto-renews.", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Rs. 290", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w900)),
                            const Text("/ month", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isBuying ? null : _buySubscription,
                      child: _isBuying
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                          : const Text(
                        "Activate Premium Now",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Terms of Service & Privacy Policy apply.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
