import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminController {
  final _supabase = Supabase.instance.client;

  // ==========================================
  // --- CATEGORIES & STATS METHODS (EXISTING) ---
  // ==========================================

  // 1. Saari categories database se fetch karna
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final data = await _supabase.from('categories').select().order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Categories load karne mein masla: $e");
    }
  }

  // 2. Nayi Category database mein save karna
  Future<void> createCategory(String name) async {
    try {
      await _supabase.from('categories').insert({'name': name});
    } catch (e) {
      throw Exception("Category database mein save nahi hui: $e");
    }
  }

  // 3. Purani Category ka naam badalna (Update)
  Future<void> updateCategory(String id, String newName) async {
    try {
      await _supabase.from('categories').update({'name': newName}).eq('id', id);
    } catch (e) {
      throw Exception("Category update nahi ho saki: $e");
    }
  }

  // 4. Category ko delete karna (Agar zaroorat pade)
  Future<void> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (e) {
      throw Exception("Category delete nahi ho saki: $e");
    }
  }

  // 5. Dashboard ke REAL Stats laana (BY DEFAULT AB 0 SE START HOGA)
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      // 'wallpapers' table se saare wallpapers ke downloads ka data nikalna
      final response = await _supabase.from('wallpapers').select('downloads');

      int totalDownloads = 0;
      if (response != null && response is List) {
        for (var row in response) {
          totalDownloads += (row['downloads'] as int? ?? 0);
        }
      }

      return {
        'downloads': totalDownloads, // Real downloads ka total count
        'subscribers': 0,            // Default 0 jab tak active users nahi aate
        'revenue': 0.0,              // Default 0.0 jab tak actual payments nahi hotin
      };
    } catch (e) {
      return {
        'downloads': 0,
        'subscribers': 0,
        'revenue': 0.0,
      };
    }
  }

  // 6. Complete Wallpaper Upload Process (Storage + Database for Categories)
  Future<void> uploadWallpaperProcess({
    required File imageFile,
    required String categoryId,
    required bool isPremium,
    required bool isAnimated,
  }) async {
    try {
      // A. Unique file name
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = 'wallpapers/$fileName';

      // B. Upload to Supabase Storage
      await _supabase.storage.from('wallpapers').upload(path, imageFile);

      // C. Get Public URL
      final imageUrl = _supabase.storage.from('wallpapers').getPublicUrl(path);

      // D. Insert into wallpapers table with is_animated flag
      await _supabase.from('wallpapers').insert({
        'url': imageUrl,
        'category_id': int.parse(categoryId),
        'is_premium': isPremium,
        'is_animated': isAnimated,
        'downloads': 0,
      });
    } catch (e) {
      throw Exception("Wallpaper upload/save failed: $e");
    }
  }

  // ==========================================
  // ----- NEW CATALOG SYSTEM METHODS -----
  // ==========================================

  // 7. Naya Catalog (Collection) Create karna (UPDATED WITH CATEGORY ID RELATION)
  Future<void> createNewCatalog({
    required String title,
    required File coverImageFile,
    required String categoryId, // Naya parameter dropdown se linkage ke liye
  }) async {
    try {
      // A. Unique image name for catalog cover
      final fileName = "catalog_cover_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = 'catalogs/$fileName';

      // B. Upload cover image to Supabase Storage bucket
      await _supabase.storage.from('wallpapers').upload(path, coverImageFile);

      // C. Get Public URL
      final coverUrl = _supabase.storage.from('wallpapers').getPublicUrl(path);

      // D. Insert into 'catalogs' table with parent category_id
      await _supabase.from('catalogs').insert({
        'title': title,
        'cover_url': coverUrl,
        'category_id': int.parse(categoryId), // Dropdown wali ID integer mein insert hogi
      });
    } catch (e) {
      throw Exception("Naya Catalog create karne mein masla aaya: $e");
    }
  }

  // 8. Upload screen ke dropdown mein show karne ke liye saare Catalogs laana
  Future<List<Map<String, dynamic>>> fetchAllCatalogs() async {
    try {
      final data = await _supabase.from('catalogs').select('id, title').order('title');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Catalogs list load karne mein masla: $e");
    }
  }

  // 9. Complete Catalog Wallpaper Upload Process (Storage + catalog_wallpapers DB Table)
  Future<void> uploadWallpaperToCatalogProcess({
    required File imageFile,
    required int catalogId,
    required bool isPremium,
    required bool isAnimated,
  }) async {
    try {
      // A. Unique file name banana
      final fileName = "cat_wall_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = 'catalog_wallpapers/$fileName';

      // B. Upload wallpaper file to storage bucket
      await _supabase.storage.from('wallpapers').upload(path, imageFile);

      // C. Get Public URL
      final imageUrl = _supabase.storage.from('wallpapers').getPublicUrl(path);

      // D. Insert details into 'catalog_wallpapers' table
      await _supabase.from('catalog_wallpapers').insert({
        'catalog_id': catalogId,
        'url': imageUrl,
        'is_premium': isPremium,
        'is_animated': isAnimated,
      });
    } catch (e) {
      throw Exception("Catalog wallpaper upload karne mein masla: $e");
    }
  }

  // 10. Catalog ko delete karna (Optional/For safety)
  Future<void> deleteCatalog(int catalogId) async {
    try {
      await _supabase.from('catalogs').delete().eq('id', catalogId);
    } catch (e) {
      throw Exception("Catalog delete karne mein masla: $e");
    }
  }

  // ==========================================
  // ----- ADVANCED ADMIN PANEL FEATURES -----
  // ==========================================

  // 11. Top 5 Trending Wallpapers laana (Based on Downloads)
  Future<List<Map<String, dynamic>>> fetchTrendingWallpapers() async {
    try {
      final data = await _supabase
          .from('wallpapers')
          .select('id, url, downloads, is_premium')
          .order('downloads', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Trending wallpapers load karne mein masla: $e");
    }
  }

  // 13. Fetch latest animated wallpapers for carousel (top 4 recent)
  Future<List<Map<String, dynamic>>> fetchAnimatedWallpapers() async {
    try {
      final data = await _supabase
          .from('wallpapers')
          .select('id, url')
          .eq('is_animated', true)
          .order('created_at', ascending: false)
          .limit(4);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Animated wallpapers fetch error: $e");
    }
  }

  // 12. Push Notification Console
  Future<void> sendPushNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'title': title,
        'body': body,
      });
    } catch (e) {
      throw Exception("Notification send karne mein masla aaya: $e");
    }
  }
}