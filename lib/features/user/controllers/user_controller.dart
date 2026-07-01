import 'package:supabase_flutter/supabase_flutter.dart';

class UserController {
  final _supabase = Supabase.instance.client;

  // ==========================================
  // --- CATEGORIES & WALLPAPERS (EXISTING) ---
  // ==========================================

  // 1. Database se saari categories laana (Direct List format mein)
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final data = await _supabase.from('categories').select().order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Categories load karne mein masla aaya: $e");
    }
  }

  // 2. Saare wallpapers fetch karna
  Future<List<Map<String, dynamic>>> fetchAllWallpapers() async {
    try {
      final data = await _supabase.from('wallpapers').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Wallpapers load karne mein masla aaya: $e");
    }
  }

  // 3. Kisi specific Category ke wallpapers filter karke laana
  Future<List<Map<String, dynamic>>> fetchWallpapersByCategory(int categoryId) async {
    try {
      final data = await _supabase
          .from('wallpapers')
          .select()
          .eq('category_id', categoryId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Category wallpapers load karne mein masla: $e");
    }
  }

  // ==========================================
  // ----- NEW CATALOG SYSTEM METHODS -----
  // ==========================================

  // 4. Saare Catalogs (Collection Packs) fetch karna unke cover images ke sath
  Future<List<Map<String, dynamic>>> fetchAllCatalogs() async {
    try {
      final data = await _supabase
          .from('catalogs')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Catalogs load karne mein masla aaya: $e");
    }
  }

  // 5. Kisi specific Catalog Pack ke andar ke saare wallpapers laana
  Future<List<Map<String, dynamic>>> fetchCatalogWallpapers(int catalogId) async {
    try {
      final data = await _supabase
          .from('catalog_wallpapers')
          .select()
          .eq('catalog_id', catalogId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Catalog wallpapers load karne mein masla aaya: $e");
    }
  }

  // ==========================================
  // ----- NEW NOTIFICATION SYSTEM METHODS -----
  // ==========================================

  // 6. Saari notifications database se fetch karna (Newest First)
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Notifications load karne mein masla aaya: $e");
    }
  }

  // ==========================================
  // ----- SEARCH METHOD -----
  // ==========================================

  // 7. Category name ke basis pe wallpapers search karna
  Future<List<Map<String, dynamic>>> searchWallpapers(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      // Pehle matching categories dhoondho
      final categories = await _supabase
          .from('categories')
          .select('id')
          .ilike('name', '%${query.trim()}%');

      if (categories.isEmpty) return [];

      final categoryIds = (categories as List).map((c) => c['id'] as int).toList();

      // Phir un categories ke wallpapers fetch karo
      final data = await _supabase
          .from('wallpapers')
          .select()
          .inFilter('category_id', categoryIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Search karne mein masla aaya: $e");
    }
  }
}