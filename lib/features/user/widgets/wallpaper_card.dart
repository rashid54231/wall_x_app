import 'package:cached_network_image/cached_network_image.dart'; // <-- YAHAN SINGLE QUOTE AUR .dart LAGA DIYA
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class WallpaperCard extends StatelessWidget {
  final String imageUrl;
  final bool isPremium;
  final VoidCallback onTap;

  const WallpaperCard({
    super.key,
    required this.imageUrl,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Wallpaper Image with Caching
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
              ),
            ),
          ),

          // Top Premium Crown Badge (Agar wallpaper paid hai)
          if (isPremium)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium, // Crown style icon
                  color: AppColors.accent, // Gold Color
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}