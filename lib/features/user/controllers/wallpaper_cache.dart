import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WallpaperCache {
  static final WallpaperCache _instance = WallpaperCache._internal();
  factory WallpaperCache() => _instance;
  WallpaperCache._internal();

  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _allWallpapers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allCatalogs = [];
  final Map<int, List<Map<String, dynamic>>> _categoryWallpapersCache = {};
  final Map<int, List<Map<String, dynamic>>> _catalogWallpapersCache = {};

  DateTime? _lastFetchTime;
  static const _cacheExpiry = Duration(minutes: 5);

  // In-flight Future deduplication so simultaneous callers don't duplicate network calls
  Future<List<Map<String, dynamic>>>? _pendingWallpapersFuture;
  Future<List<Map<String, dynamic>>>? _pendingCategoriesFuture;
  Future<List<Map<String, dynamic>>>? _pendingCatalogsFuture;

  // Notifier to let listening screens update seamlessly when background fetch completes
  final ValueNotifier<int> dataVersionNotifier = ValueNotifier<int>(0);

  bool _isDiskLoaded = false;

  List<Map<String, dynamic>> get allWallpapers => _allWallpapers;
  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get allCategories => _categories;
  List<Map<String, dynamic>> get allCatalogs => _allCatalogs;

  bool get _isCacheValid =>
      _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;

  void invalidate() {
    _lastFetchTime = null;
    _categoryWallpapersCache.clear();
    _catalogWallpapersCache.clear();
  }

  /// Fast startup: Pre-warm from local disk in 1-3 milliseconds
  Future<void> initFromDisk() async {
    if (_isDiskLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cachedCats = prefs.getString('cached_categories');
      if (cachedCats != null && cachedCats.isNotEmpty && _categories.isEmpty) {
        final decoded = jsonDecode(cachedCats);
        if (decoded is List) {
          _categories = List<Map<String, dynamic>>.from(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }

      final cachedWalls = prefs.getString('cached_wallpapers');
      if (cachedWalls != null && cachedWalls.isNotEmpty && _allWallpapers.isEmpty) {
        final decoded = jsonDecode(cachedWalls);
        if (decoded is List) {
          _allWallpapers = List<Map<String, dynamic>>.from(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }

      final cachedCatsList = prefs.getString('cached_catalogs');
      if (cachedCatsList != null && cachedCatsList.isNotEmpty && _allCatalogs.isEmpty) {
        final decoded = jsonDecode(cachedCatsList);
        if (decoded is List) {
          _allCatalogs = List<Map<String, dynamic>>.from(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }

      _isDiskLoaded = true;
      dataVersionNotifier.value++;
    } catch (e) {
      debugPrint("Disk cache init error: $e");
    }
  }

  Future<void> _saveToDisk(String key, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep disk cache lightweight: limit to top 150 wallpapers to avoid heavy storage
      final toSave = data.length > 150 ? data.take(150).toList() : data;
      await prefs.setString(key, jsonEncode(toSave));
    } catch (e) {
      debugPrint("Error saving to disk for $key: $e");
    }
  }

  /// Categories with deduplication and stale-while-revalidate
  Future<List<Map<String, dynamic>>> fetchCategories({bool forceRefresh = false}) async {
    if (!_isDiskLoaded) await initFromDisk();

    if (!forceRefresh && _categories.isNotEmpty && _isCacheValid) {
      return _categories;
    }

    if (_pendingCategoriesFuture != null) {
      return _pendingCategoriesFuture!;
    }

    _pendingCategoriesFuture = () async {
      try {
        final data = await _supabase.from('categories').select().order('name');
        _categories = List<Map<String, dynamic>>.from(data);
        _saveToDisk('cached_categories', _categories);
        dataVersionNotifier.value++;
        return _categories;
      } catch (e) {
        if (_categories.isNotEmpty) return _categories;
        throw Exception("Categories load karne mein masla aaya: $e");
      } finally {
        _pendingCategoriesFuture = null;
      }
    }();

    // If we have cached categories from disk, return them immediately
    // while the background request updates fresh data!
    if (_categories.isNotEmpty && !forceRefresh) {
      return _categories;
    }

    return _pendingCategoriesFuture!;
  }

  /// Wallpapers with deduplication, local caching, and background revalidation
  Future<List<Map<String, dynamic>>> fetchAllWallpapers({bool forceRefresh = false}) async {
    if (!_isDiskLoaded) await initFromDisk();

    if (!forceRefresh && _allWallpapers.isNotEmpty && _isCacheValid) {
      return _allWallpapers;
    }

    if (_pendingWallpapersFuture != null) {
      return _pendingWallpapersFuture!;
    }

    _pendingWallpapersFuture = () async {
      try {
        final data = await _supabase
            .from('wallpapers')
            .select()
            .order('created_at', ascending: false);
        _allWallpapers = List<Map<String, dynamic>>.from(data);
        _lastFetchTime = DateTime.now();
        _saveToDisk('cached_wallpapers', _allWallpapers);
        dataVersionNotifier.value++;
        return _allWallpapers;
      } catch (e) {
        if (_allWallpapers.isNotEmpty) return _allWallpapers;
        throw Exception("Wallpapers load karne mein masla aaya: $e");
      } finally {
        _pendingWallpapersFuture = null;
      }
    }();

    // Fast-path: return cached data immediately if available
    if (_allWallpapers.isNotEmpty && !forceRefresh) {
      return _allWallpapers;
    }

    return _pendingWallpapersFuture!;
  }

  Future<List<Map<String, dynamic>>> fetchWallpapersByCategory(int categoryId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _categoryWallpapersCache.containsKey(categoryId)) {
      return _categoryWallpapersCache[categoryId]!;
    }

    // Check if we can satisfy this from _allWallpapers in memory!
    if (_allWallpapers.isNotEmpty && !forceRefresh) {
      final inMemory = _allWallpapers.where((w) => w['category_id'] == categoryId).toList();
      if (inMemory.isNotEmpty) {
        _categoryWallpapersCache[categoryId] = inMemory;
        return inMemory;
      }
    }

    try {
      final data = await _supabase
          .from('wallpapers')
          .select()
          .eq('category_id', categoryId)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      _categoryWallpapersCache[categoryId] = list;
      return list;
    } catch (e) {
      if (_categoryWallpapersCache.containsKey(categoryId)) {
        return _categoryWallpapersCache[categoryId]!;
      }
      throw Exception("Category wallpapers load karne mein masla: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchLatestByCategory(int categoryId, {int days = 3}) async {
    // Compute from category wallpapers to avoid redundant query
    final walls = await fetchWallpapersByCategory(categoryId);
    final since = DateTime.now().subtract(Duration(days: days));
    return walls.where((w) {
      final created = DateTime.tryParse(w['created_at']?.toString() ?? '');
      return created != null && created.isAfter(since);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMostFavoriteByCategory(int categoryId) async {
    final walls = await fetchWallpapersByCategory(categoryId);
    final sorted = List<Map<String, dynamic>>.from(walls);
    sorted.sort((a, b) {
      final favA = (a['fav_count'] as num?)?.toInt() ?? 0;
      final favB = (b['fav_count'] as num?)?.toInt() ?? 0;
      return favB.compareTo(favA);
    });
    return sorted.take(20).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPremiumWallpapers({bool forceRefresh = false}) async {
    // If all wallpapers are already in memory, filter in 0ms!
    if (!forceRefresh && _allWallpapers.isNotEmpty) {
      final inMem = _allWallpapers.where((w) => w['is_premium'] == true).toList();
      if (inMem.isNotEmpty) return inMem;
    }

    try {
      final data = await _supabase
          .from('wallpapers')
          .select()
          .eq('is_premium', true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (_allWallpapers.isNotEmpty) {
        return _allWallpapers.where((w) => w['is_premium'] == true).toList();
      }
      throw Exception("Premium wallpapers load karne mein masla: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllCatalogs({bool forceRefresh = false}) async {
    if (!_isDiskLoaded) await initFromDisk();

    if (!forceRefresh && _allCatalogs.isNotEmpty && _isCacheValid) return _allCatalogs;

    if (_pendingCatalogsFuture != null) {
      return _pendingCatalogsFuture!;
    }

    _pendingCatalogsFuture = () async {
      try {
        final data = await _supabase
            .from('catalogs')
            .select()
            .order('created_at', ascending: false);
        _allCatalogs = List<Map<String, dynamic>>.from(data);
        _saveToDisk('cached_catalogs', _allCatalogs);
        return _allCatalogs;
      } catch (e) {
        if (_allCatalogs.isNotEmpty) return _allCatalogs;
        throw Exception("Catalogs load karne mein masla aaya: $e");
      } finally {
        _pendingCatalogsFuture = null;
      }
    }();

    if (_allCatalogs.isNotEmpty && !forceRefresh) {
      return _allCatalogs;
    }

    return _pendingCatalogsFuture!;
  }

  Future<List<Map<String, dynamic>>> fetchCatalogWallpapers(int catalogId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _catalogWallpapersCache.containsKey(catalogId)) {
      return _catalogWallpapersCache[catalogId]!;
    }

    try {
      final data = await _supabase
          .from('catalog_wallpapers')
          .select()
          .eq('catalog_id', catalogId)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      _catalogWallpapersCache[catalogId] = list;
      return list;
    } catch (e) {
      if (_catalogWallpapersCache.containsKey(catalogId)) {
        return _catalogWallpapersCache[catalogId]!;
      }
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
      final q = query.trim();

      final categories = await _supabase
          .from('categories')
          .select('id')
          .ilike('name', '%$q%');

      final categoryIds = (categories as List).map((c) => c['id'] as int).toList();

      List<dynamic> data;
      if (categoryIds.isNotEmpty) {
        data = await _supabase
            .from('wallpapers')
            .select()
            .or('tags.ilike.%$q%,category_id.in.(${categoryIds.join(',')})')
            .order('created_at', ascending: false);
      } else {
        data = await _supabase
            .from('wallpapers')
            .select()
            .ilike('tags', '%$q%')
            .order('created_at', ascending: false);
      }
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception("Search karne mein masla aaya: $e");
    }
  }
}
