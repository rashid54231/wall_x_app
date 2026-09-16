import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/wallpaper_cache_manager.dart';

class FastWallpaperImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final int memCacheWidth;
  final BorderRadius? borderRadius;

  const FastWallpaperImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 380,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        color: const Color(0xFF1E1E28),
        child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
      );
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: WallpaperImageCacheManager.instance,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A26), Color(0xFF252538)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.white.withValues(alpha: 0.12),
            size: 26,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF1E1E28),
        child: const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }
}
