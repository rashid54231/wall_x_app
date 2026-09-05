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
import '../controllers/favorites_storage.dart';
import 'package:video_player/video_player.dart';


enum PreviewMode { none, lockScreen, homeScreen }

class DetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> wallpaperData;

  const DetailScreen({super.key, required this.wallpaperData});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _isDownloading = false;
  bool _imageLoaded = false;
  bool _isFavorite = false;
  VideoPlayerController? _videoController;
  PreviewMode _previewMode = PreviewMode.none;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(premiumProvider.notifier).refresh());
    _checkIfFavorite();
    
    String url = widget.wallpaperData['url'] ?? '';
    bool isAnimated = (widget.wallpaperData['is_animated'] == true) || 
                      url.toLowerCase().contains('.mp4') || 
                      url.toLowerCase().contains('.mov');

    if (isAnimated && url.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          _videoController!.setLooping(true);
          _videoController!.setVolume(0.0);
          _videoController!.play();
          if (mounted) setState(() {});
        }).catchError((e) {
          debugPrint("Video initialize error: $e");
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _checkIfFavorite() async {
    final id = widget.wallpaperData['id'].toString();
    final isFav = await FavoritesStorage.isFavorite(id);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    final id = widget.wallpaperData['id'].toString();
    final isFav = await FavoritesStorage.toggleFavorite(id);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  bool _checkPremiumAccess(bool isPremium) {
    if (!isPremium) return true;
    return ref.read(premiumProvider);
  }

  Future<void> _downloadWallpaper(String imageUrl) async {
    setState(() => _isDownloading = true);
    try {
      if (imageUrl.isEmpty) throw "Media link missing";

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

      final bool isAnimated = widget.wallpaperData['is_animated'] ?? false;
      final String extension = isAnimated ? ".mp4" : ".jpg";
      final String fileName = "WallX_${DateTime.now().millisecondsSinceEpoch}$extension";
      final String savePath = "${appDir.path}/$fileName";

      await Dio().download(imageUrl, savePath);
      
      if (isAnimated) {
        await Gal.putVideo(savePath);
        _showSnackBar("Video wallpaper gallery mein save ho gaya!", isError: false);
      } else {
        await Gal.putImage(savePath);
        _showSnackBar("Wallpaper Gallery mein save ho gaya!", isError: false);
      }
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
    String imageUrl = widget.wallpaperData['url'] ?? '';
    bool isPremium = widget.wallpaperData['is_premium'] ?? false;
    bool isAnimated = (widget.wallpaperData['is_animated'] == true) || 
                      imageUrl.toLowerCase().contains('.mp4') || 
                      imageUrl.toLowerCase().contains('.mov');
    bool hasAccess = _checkPremiumAccess(isPremium);

    if (_previewMode != PreviewMode.none) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildSimulatorView(imageUrl, isAnimated),
      );
    }

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
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 24),
                    tooltip: "Preview on phone",
                    onPressed: _showPreviewSheet,
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? Colors.redAccent : Colors.white,
                      size: 26,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                  if (isPremium) ...[
                    const SizedBox(width: 8),
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
                ],
              ),
            ),

            // Wallpaper media
            Expanded(
              child: imageUrl.isNotEmpty
                  ? InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: isAnimated
                            ? (_videoController != null && _videoController!.value.isInitialized
                                ? AspectRatio(
                                    aspectRatio: _videoController!.value.aspectRatio,
                                    child: VideoPlayer(_videoController!),
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: AppColors.primary),
                                        SizedBox(height: 16),
                                        Text("Loading Video...", style: TextStyle(color: Colors.white54, fontSize: 14)),
                                      ],
                                    ),
                                  ))
                            : CachedNetworkImage(
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
                                      const Text("Media load nahi ho saki", style: TextStyle(color: Colors.white54, fontSize: 14)),
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
                  : const Center(child: Text("Media link missing", style: TextStyle(color: Colors.white54))),
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
              child: Row(
                children: [
                  // 👁️ Preview on Phone Button
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 22),
                      tooltip: "Preview on phone",
                      onPressed: _showPreviewSheet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Download / Set button
                  Expanded(
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
                              label: Text(_isDownloading ? "Saving..." : (isAnimated ? "Set Live Wallpaper" : "Download Wallpaper"),
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
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 📱 PREVIEW SIMULATOR METHODS (Lock Screen & Home Screen)
  // =========================================================================

  void _showPreviewSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Phone Screen Preview",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Dekhein ye wallpaper aapke phone par kaisa lagega",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12.5),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _previewMode = PreviewMode.lockScreen);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1F3C88), Color(0xFF5893D4)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1F3C88).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.lock_rounded, color: Colors.white, size: 30),
                              SizedBox(height: 10),
                              Text("Lock Screen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(height: 3),
                              Text("Clock & alerts", style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _previewMode = PreviewMode.homeScreen);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.apps_rounded, color: Colors.white, size: 30),
                              SizedBox(height: 10),
                              Text("Home Screen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(height: 3),
                              Text("Apps & widgets", style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimulatorView(String imageUrl, bool isAnimated) {
    return GestureDetector(
      onTap: () => setState(() => _previewMode = PreviewMode.none),
      child: Stack(
        children: [
          // Full Screen Wallpaper (Cover fit)
          Positioned.fill(
            child: isAnimated
                ? (_videoController != null && _videoController!.value.isInitialized
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator(color: AppColors.primary)))
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
                  ),
          ),

          // Subtle Gradient Overlays for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Simulator Content
          SafeArea(
            child: Column(
              children: [
                // Top Status Bar Simulation
                _buildSimulatedStatusBar(),

                // Main Simulator Content
                Expanded(
                  child: _previewMode == PreviewMode.lockScreen
                      ? _buildLockScreenSimulator()
                      : _buildHomeScreenSimulator(),
                ),

                // Floating Switcher Bar at bottom
                _buildFloatingControls(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getCurrentTimeString(),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.signal_cellular_4_bar_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Icon(Icons.wifi_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Icon(Icons.battery_full_rounded, color: Colors.white, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockScreenSimulator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Lock Icon
          const Icon(Icons.lock_rounded, color: Colors.white70, size: 22),
          const SizedBox(height: 8),
          // Big Digital Clock
          Text(
            _getCurrentTimeString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.w200,
              letterSpacing: -1.5,
              shadows: [
                Shadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 2)),
              ],
            ),
          ),
          // Date
          Text(
            _getCurrentDateString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 1)),
              ],
            ),
          ),
          const Spacer(),
          // Mock Notification Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.wallpaper_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("WallX", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text("Just now", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text("Wallpaper looks awesome on your phone! ✨",
                          style: TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Flashlight & Camera shortcut circles
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: const Icon(Icons.flashlight_on_rounded, color: Colors.white, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreenSimulator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Google/Search Widget simulation
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text("Search...", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ),
                Icon(Icons.mic_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Icon(Icons.camera_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 36),
          // App Grid Row 1
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPhoneAppIcon(Icons.phone_rounded, "Phone", const [Color(0xFF00C853), Color(0xFF64DD17)]),
              _buildPhoneAppIcon(Icons.chat_bubble_rounded, "Chat", const [Color(0xFF2979FF), Color(0xFF00B0FF)]),
              _buildPhoneAppIcon(Icons.public_rounded, "Browser", const [Color(0xFFFF3D00), Color(0xFFFF9100)]),
              _buildPhoneAppIcon(Icons.camera_alt_rounded, "Camera", const [Color(0xFF651FFF), Color(0xFF7C4DFF)]),
            ],
          ),
          const SizedBox(height: 24),
          // App Grid Row 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPhoneAppIcon(Icons.music_note_rounded, "Music", const [Color(0xFFFF1744), Color(0xFFFF5252)]),
              _buildPhoneAppIcon(Icons.photo_library_rounded, "Gallery", const [Color(0xFFFFD600), Color(0xFFFFEA00)]),
              _buildPhoneAppIcon(Icons.settings_rounded, "Settings", const [Color(0xFF607D8B), Color(0xFF90A4AE)]),
              _buildPhoneAppIcon(Icons.wallpaper_rounded, "WallX", const [Color(0xFF6A11CB), Color(0xFF2575FC)]),
            ],
          ),
          const Spacer(),
          // Bottom App Dock
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPhoneAppIcon(Icons.phone_rounded, "", const [Color(0xFF00C853), Color(0xFF64DD17)], isDock: true),
                _buildPhoneAppIcon(Icons.chat_bubble_rounded, "", const [Color(0xFF2979FF), Color(0xFF00B0FF)], isDock: true),
                _buildPhoneAppIcon(Icons.public_rounded, "", const [Color(0xFFFF3D00), Color(0xFFFF9100)], isDock: true),
                _buildPhoneAppIcon(Icons.camera_alt_rounded, "", const [Color(0xFF651FFF), Color(0xFF7C4DFF)], isDock: true),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPhoneAppIcon(IconData icon, String label, List<Color> gradientColors, {bool isDock = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDock ? 46 : 52,
          height: isDock ? 46 : 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: isDock ? 24 : 28),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFloatingControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lock Screen Switcher Chip
          GestureDetector(
            onTap: () => setState(() => _previewMode = PreviewMode.lockScreen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _previewMode == PreviewMode.lockScreen ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: _previewMode == PreviewMode.lockScreen ? Colors.white : Colors.white60, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "Lock",
                    style: TextStyle(
                      color: _previewMode == PreviewMode.lockScreen ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Home Screen Switcher Chip
          GestureDetector(
            onTap: () => setState(() => _previewMode = PreviewMode.homeScreen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _previewMode == PreviewMode.homeScreen ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.apps_rounded,
                      color: _previewMode == PreviewMode.homeScreen ? Colors.white : Colors.white60, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "Home",
                    style: TextStyle(
                      color: _previewMode == PreviewMode.homeScreen ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 18, color: Colors.white24),
          const SizedBox(width: 8),
          // Exit button
          GestureDetector(
            onTap: () => setState(() => _previewMode = PreviewMode.none),
            child: const Row(
              children: [
                Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                SizedBox(width: 3),
                Text("Exit", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentTimeString() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  String _getCurrentDateString() {
    final now = DateTime.now();
    const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return "$dayName, $monthName ${now.day}";
  }
}
