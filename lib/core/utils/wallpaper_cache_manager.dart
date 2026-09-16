import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class WallpaperImageCacheManager {
  static const String key = 'wallx_persistent_image_cache';

  // ⚡ Dedicated CacheManager with 30-day persistence and 1000 objects
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
