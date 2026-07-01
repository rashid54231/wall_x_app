import 'package:supabase_flutter/supabase_flutter.dart';

class WallpaperCache {
  static final WallpaperCache _instance = WallpaperCache._internal();
  factory WallpaperCache() => _instance;
  WallpaperCache._internal();

  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _allWallpapers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allCatalogs = [];
  DateTime? _lastFetchTime;
  static const _cacheExpiry = Duration(minutes: 5);

  List<Map<String, dynamic>> get allWallpapers => _allWallpapers;
  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get allCatalogs => _allCatalogs;

  bool get _isCacheValid =>
      _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;

  void invalidate() {
    _lastFetchTime = null;
  }

  Future<List<Map<String, dynamic>>> fetchCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categories.isNotEmpty && _isCacheValid) return _categories;
    try {
      final data = await _supabase.from('categories').select().order('name');
      _categories = List<Map<String, dynamic>>.from(data);
      return _categories;
    } catch (e) {
      throw Exception("Categories load karne mein masla aaya: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllWallpapers({bool forceRefresh = false}) async {
    if (!forceRefresh && _allWallpapers.isNotEmpty && _isCacheValid) return _allWallpapers;
    try {
      final data = await _supabase.from('wallpapers').select().order('created_at', ascending: false);
      _allWallpapers = List<Map<String, dynamic>>.from(data);
      _lastFetchTime = DateTime.now();
      return _allWallpapers;
    } catch (e) {
      throw Exception("Wallpapers load karne mein masla aaya: $e");
    }
  }

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

  Future<List<Map<String, dynamic>>> fetchLatestByCategory(int categoryId, {int days = 3}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();
      final data = await _supabase
          .from('wallpapers')
          .select()
          .eq('category_id', categoryId)
          .gte('created_at', since)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Latest wallpapers load karne mein masla: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchMostFavoriteByCategory(int categoryId) async {
    try {
      final data = await _supabase
          .from('wallpapers')
          .select()
          .eq('category_id', categoryId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Favorite wallpapers load karne mein masla: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchPremiumWallpapers() async {
    try {
      final data = await _supabase
          .from('wallpapers')
          .select()
          .eq('is_premium', true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Premium wallpapers load karne mein masla: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllCatalogs({bool forceRefresh = false}) async {
    if (!forceRefresh && _allCatalogs.isNotEmpty && _isCacheValid) return _allCatalogs;
    try {
      final data = await _supabase
          .from('catalogs')
          .select()
          .order('created_at', ascending: false);
      _allCatalogs = List<Map<String, dynamic>>.from(data);
      return _allCatalogs;
    } catch (e) {
      throw Exception("Catalogs load karne mein masla aaya: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchCatalogWallpapers(int catalogId) async {
    try {
      final data = await _supabase
          .from('catalog_wallpapers')
          .select()
          .eq('catalog_id', catalogId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Catalog wallpapers load karne mein masla: $e");
    }
  }

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

  Future<List<Map<String, dynamic>>> searchWallpapers(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      final categories = await _supabase
          .from('categories')
          .select('id')
          .ilike('name', '%${query.trim()}%');
      if (categories.isEmpty) return [];
      final categoryIds = (categories as List).map((c) => c['id'] as int).toList();
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
