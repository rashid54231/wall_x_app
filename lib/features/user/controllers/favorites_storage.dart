import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesStorage {
  static const String _key = 'favorite_wallpapers_ids';
  static final _supabase = Supabase.instance.client;

  // In-memory cache for O(1) instantaneous lookups
  static Set<String>? _memoryCache;
  static bool _isSyncingCloud = false;

  /// Get favorite wallpaper IDs with instant in-memory & local fallback
  static Future<List<String>> getFavorites({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) {
      return _memoryCache!.toList();
    }

    // Fast-path: read from SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    final localList = prefs.getStringList(_key) ?? [];
    _memoryCache ??= localList.toSet();

    // Background sync from Supabase if logged in
    final user = _supabase.auth.currentUser;
    if (user != null && !_isSyncingCloud) {
      _syncFromCloud(user.id, prefs);
    }

    return _memoryCache!.toList();
  }

  static Future<void> _syncFromCloud(String userId, SharedPreferences prefs) async {
    _isSyncingCloud = true;
    try {
      final data = await _supabase
          .from('user_favorites')
          .select('wallpaper_id')
          .eq('user_id', userId);
      final cloudIds = (data as List).map((e) => e['wallpaper_id'].toString()).toSet();
      
      // Merge cloud with memory cache
      _memoryCache ??= {};
      _memoryCache!.addAll(cloudIds);
      await prefs.setStringList(_key, _memoryCache!.toList());
    } catch (_) {
      // Offline or network error - keep local cache safe
    } finally {
      _isSyncingCloud = false;
    }
  }

  /// Toggle favorite: Updates memory & local disk instantly, syncs Supabase in background
  static Future<bool> toggleFavorite(String wallpaperId) async {
    // Ensure memory cache is initialized
    if (_memoryCache == null) {
      final prefs = await SharedPreferences.getInstance();
      _memoryCache = (prefs.getStringList(_key) ?? []).toSet();
    }

    final bool isNowFav;
    if (_memoryCache!.contains(wallpaperId)) {
      _memoryCache!.remove(wallpaperId);
      isNowFav = false;
    } else {
      _memoryCache!.add(wallpaperId);
      isNowFav = true;
    }

    // Save to local storage asynchronously
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList(_key, _memoryCache!.toList());
    });

    // Sync to Supabase in the background
    final user = _supabase.auth.currentUser;
    final int? wId = int.tryParse(wallpaperId);
    if (user != null && wId != null) {
      _syncToggleCloud(user.id, wId, isNowFav);
    }

    return isNowFav;
  }

  static Future<void> _syncToggleCloud(String userId, int wId, bool isNowFav) async {
    try {
      if (isNowFav) {
        await _supabase.from('user_favorites').upsert({
          'user_id': userId,
          'wallpaper_id': wId,
        });
      } else {
        await _supabase
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('wallpaper_id', wId);
      }
    } catch (_) {
      // Ignored for smooth offline resiliency
    }
  }

  /// Check if favorite: Instant O(1) in-memory check
  static Future<bool> isFavorite(String wallpaperId) async {
    if (_memoryCache != null) {
      return _memoryCache!.contains(wallpaperId);
    }
    final favorites = await getFavorites();
    return favorites.contains(wallpaperId);
  }

  /// Synchronous instant check when memory cache is populated
  static bool isFavoriteSync(String wallpaperId) {
    return _memoryCache?.contains(wallpaperId) ?? false;
  }
}