import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  // --- ADMIN FUNCTIONS ---

  // Nayi category add karne ke liye
  Future<void> addCategory(String name) async {
    await client.from('categories').insert({'name': name});
  }

  // Wallpaper upload karne ke liye (Storage + Database)
  Future<void> uploadWallpaper({
    required String filePath,
    required String fileName,
    required int categoryId,
    required bool isPremium,
  }) async {
    // 1. File upload karein
    await client.storage.from('wallpapers').upload(fileName, BigInt.from(0) as dynamic); // Placeholder for actual file logic

    // 2. Public URL hasil karein
    final String publicUrl = client.storage.from('wallpapers').getPublicUrl(fileName);

    // 3. Database mein entry karein
    await client.from('wallpapers').insert({
      'url': publicUrl,
      'category_id': categoryId,
      'is_premium': isPremium,
    });
  }

  // Analytics fetch karne ke liye
  Future<Map<String, dynamic>> getAdminStats() async {
    final wallpapers = await client.from('wallpapers').select('download_count');
    final subscribers = await client.from('user_subscriptions').select().eq('is_active', true);

    int totalDownloads = 0;
    for (var row in wallpapers) {
      totalDownloads += (row['download_count'] as int);
    }

    return {
      'total_downloads': totalDownloads,
      'active_subscribers': subscribers.length,
      'revenue': subscribers.length * 5.0,
    };
  }

  // --- USER FUNCTIONS ---

  // Saari categories lane ke liye
  Future<List<Map<String, dynamic>>> getCategories() async {
    final data = await client.from('categories').select();
    return List<Map<String, dynamic>>.from(data);
  }

  // Category ke mutabiq wallpapers lane ke liye
  Future<List<Map<String, dynamic>>> getWallpapersByCategory(int categoryId) async {
    final data = await client
        .from('wallpapers')
        .select()
        .eq('category_id', categoryId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}