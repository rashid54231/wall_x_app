import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStorage {
  static const String _key = 'favorite_wallpapers_ids';

  // 1. Phone ki memory se saare saved wallpaper IDs laana
  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  // 2. Kisi wallpaper ko favorite mein add ya remove karna (Toggle)
  static Future<bool> toggleFavorite(String wallpaperId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];

    if (favorites.contains(wallpaperId)) {
      favorites.remove(wallpaperId); // Agar pehle se hai to remove kar do
    } else {
      favorites.add(wallpaperId);    // Agar nahi hai to add kar do
    }

    await prefs.setStringList(_key, favorites);
    return favorites.contains(wallpaperId); // Return karega ke ab item saved hai ya nahi
  }

  // 3. Check karna ke kya koi specific wallpaper pehle se favorite hai ya nahi
  static Future<bool> isFavorite(String wallpaperId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];
    return favorites.contains(wallpaperId);
  }
}