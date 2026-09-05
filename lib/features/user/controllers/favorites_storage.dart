import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesStorage {
  static const String _key = 'favorite_wallpapers_ids';
  static final _supabase = Supabase.instance.client;

  // 1. Get favorite wallpaper IDs
  static Future<List<String>> getFavorites() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('user_favorites')
            .select('wallpaper_id')
            .eq('user_id', user.id);
        return (data as List).map((e) => e['wallpaper_id'].toString()).toList();
      } catch (e) {
        // Fallback to local if cloud fails
      }
    }
    
    // Local fallback
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  // 2. Toggle favorite
  static Future<bool> toggleFavorite(String wallpaperId) async {
    final user = _supabase.auth.currentUser;
    final int wId = int.parse(wallpaperId);
    bool isNowFav = false;

    if (user != null) {
      try {
        final existing = await _supabase
            .from('user_favorites')
            .select()
            .eq('user_id', user.id)
            .eq('wallpaper_id', wId)
            .maybeSingle();

        if (existing != null) {
          await _supabase.from('user_favorites').delete().eq('id', existing['id']);
          isNowFav = false;
        } else {
          await _supabase.from('user_favorites').insert({
            'user_id': user.id,
            'wallpaper_id': wId,
          });
          isNowFav = true;
        }
        
        // Also update local for offline support
        final prefs = await SharedPreferences.getInstance();
        List<String> favorites = prefs.getStringList(_key) ?? [];
        if (isNowFav && !favorites.contains(wallpaperId)) favorites.add(wallpaperId);
        if (!isNowFav) favorites.remove(wallpaperId);
        await prefs.setStringList(_key, favorites);
        
        return isNowFav;
      } catch (e) {
        // Fallback to local
      }
    }

    // Local toggle
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];
    if (favorites.contains(wallpaperId)) {
      favorites.remove(wallpaperId);
      isNowFav = false;
    } else {
      favorites.add(wallpaperId);
      isNowFav = true;
    }
    await prefs.setStringList(_key, favorites);
    return isNowFav;
  }

  // 3. Check if favorite
  static Future<bool> isFavorite(String wallpaperId) async {
    final favorites = await getFavorites();
    return favorites.contains(wallpaperId);
  }
}