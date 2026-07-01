import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/premium_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'premium_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> wallpaperData;

  const DetailScreen({super.key, required this.wallpaperData});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _isDownloading = false;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    // Premium status refresh karo taake purana data na rahe
    Future.microtask(() => ref.read(premiumProvider.notifier).refresh());
  }

  Future<void> _downloadWallpaper(String imageUrl) async {
    setState(() => _isDownloading = true);

    try {
      if (imageUrl.isEmpty) throw "Image link missing";

      bool hasPermission = await Gal.hasAccess();
      if (!hasPermission) {
        hasPermission = await Gal.requestAccess();
      }

      if (!hasPermission) {
        _showSnackBar("Gallery permission denied! Settings se allow karein.", isError: true);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final String fileName = "wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String savePath = "${tempDir.path}/$fileName";

      final dio = Dio();
      await dio.download(imageUrl, savePath);

      await Gal.putImage(savePath);

      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      _showSnackBar("Wallpaper Gallery mein save ho gaya!", isError: false);
    } catch (e) {
      _showSnackBar("Download fail ho gaya: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPremium = widget.wallpaperData['is_premium'] ?? false;
    String imageUrl = widget.wallpaperData['url'] ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar - Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium, color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text("Premium", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Wallpaper image - Expanded to fill available space
            Expanded(
              child: imageUrl.isNotEmpty
                  ? InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppColors.primary),
                                SizedBox(height: 16),
                                Text("Loading wallpaper...", style: TextStyle(color: Colors.white54, fontSize: 14)),
                              ],
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 50),
                                const SizedBox(height: 12),
                                const Text("Image load nahi ho saki", style: TextStyle(color: Colors.white54, fontSize: 14)),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Go Back", style: TextStyle(color: Colors.blueAccent)),
                                ),
                              ],
                            ),
                          ),
                          imageBuilder: (context, imageProvider) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_imageLoaded) setState(() => _imageLoaded = true);
                            });
                            return Image(image: imageProvider, fit: BoxFit.contain);
                          },
                        ),
                      ),
                    )
                  : const Center(
                      child: Text("Image link missing", style: TextStyle(color: Colors.white54)),
                    ),
            ),

            // Bottom Download Bar
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPremium
                            ? (ref.watch(premiumProvider) ? AppColors.primary : Colors.amber)
                            : AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: _isDownloading
                          ? null
                          : () async {
                              if (isPremium) {
                                final bool userHasPremium = ref.watch(premiumProvider);
                                if (!userHasPremium) {
                                  final bool? result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const PremiumPaywallScreen()),
                                  );
                                  if (result != true) return;
                                }
                              }
                              _downloadWallpaper(imageUrl);
                            },
                      icon: _isDownloading
                          ? const SizedBox.shrink()
                          : Icon(
                              isPremium ? Icons.workspace_premium : Icons.file_download,
                              color: Colors.white,
                            ),
                      label: _isDownloading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isPremium
                                  ? (ref.watch(premiumProvider) ? "Download Wallpaper" : "Unlock Premium")
                                  : "Download Wallpaper",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
