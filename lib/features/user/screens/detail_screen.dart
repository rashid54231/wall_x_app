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
    Future.microtask(() => ref.read(premiumProvider.notifier).refresh());
  }

  bool _checkPremiumAccess(bool isPremium) {
    if (!isPremium) return true;
    return ref.read(premiumProvider);
  }

  Future<void> _downloadWallpaper(String imageUrl) async {
    setState(() => _isDownloading = true);
    try {
      if (imageUrl.isEmpty) throw "Image link missing";

      bool hasPermission = await Gal.hasAccess();
      if (!hasPermission) hasPermission = await Gal.requestAccess();
      if (!hasPermission) {
        _showSnackBar("Gallery permission denied!", isError: true);
        return;
      }

      final picturesDir = await getExternalStorageDirectory();
      if (picturesDir == null) throw "Storage access denied";
      final appDir = Directory("${picturesDir.path}/DCIM/WallXApp");
      if (!await appDir.exists()) await appDir.create(recursive: true);

      final String fileName = "WallX_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String savePath = "${appDir.path}/$fileName";

      await Dio().download(imageUrl, savePath);
      await Gal.putImage(savePath);

      _showSnackBar("Wallpaper Gallery mein save ho gaya!", isError: false);
    } catch (e) {
      _showSnackBar("Download fail: $e", isError: true);
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
    bool hasAccess = _checkPremiumAccess(isPremium);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
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

            // Wallpaper image
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
                                Text("Loading...", style: TextStyle(color: Colors.white54, fontSize: 14)),
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
                  : const Center(child: Text("Image link missing", style: TextStyle(color: Colors.white54))),
            ),

            // Bottom Action Bar
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: hasAccess
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: _isDownloading ? null : () => _downloadWallpaper(imageUrl),
                        icon: _isDownloading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.file_download, color: Colors.white),
                        label: Text(_isDownloading ? "Saving..." : "Download Wallpaper",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final bool? result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PremiumPaywallScreen()),
                          );
                          if (result == true && mounted) {
                            setState(() {});
                            ref.read(premiumProvider.notifier).refresh();
                          }
                        },
                        icon: const Icon(Icons.workspace_premium, color: Colors.white),
                        label: const Text("Unlock Premium to Download",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
