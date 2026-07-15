import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/colors.dart';
import 'create_catalog_screen.dart';
import 'premium_requests_screen.dart';
import '../controllers/admin_controller.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminController _controller = AdminController();
  final _picker = ImagePicker();
//no
  // Notification Form Controllers
  final _notiTitleController = TextEditingController();
  final _notiBodyController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  bool _isAnimated = false;
  bool _isPremium = false;
  bool _isSendingNoti = false;


  // Analytics Stats State
  int downloads = 0;
  int subscribers = 0;
  double revenue = 0.0;

  // State for animated carousel
  List<Map<String, dynamic>> _animatedWallpapers = [];
  late final PageController _carouselController;
  int _carouselPage = 0;
  Timer? _carouselTimer;

  // Trending Wallpapers State
  List<Map<String, dynamic>> _trendingWallpapers = [];

  // Core Categories & Catalogs State Tracking
  String _uploadTargetType = "Category";

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  List<Map<String, dynamic>> _catalogs = [];
  int? _selectedCatalogId;

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.95);
    _loadInitialData();
    _loadAnimatedWallpapers();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_animatedWallpapers.isNotEmpty && _carouselController.hasClients) {
        int nextPage = (_carouselPage + 1) % _animatedWallpapers.length;
        _carouselController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() => _carouselPage = nextPage);
      }
    });
  }

  Future<void> _loadAnimatedWallpapers() async {
    try {
      final walls = await _controller.fetchAnimatedWallpapers();
      setState(() {
        _animatedWallpapers = walls;
      });
    } catch (e) {
      // Silent fail, keep empty list
    }
  }

  // Database se dynamic data load karna (Categories, Catalogs, Stats aur Trending)
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _controller.fetchCategories();
      final stats = await _controller.fetchDashboardStats();
      final catsPacks = await _controller.fetchAllCatalogs();
      final trendingData = await _controller.fetchTrendingWallpapers();

      setState(() {
        _categories = cats;
        _catalogs = catsPacks;
        _trendingWallpapers = trendingData;
        downloads = stats['downloads'];
        subscribers = stats['subscribers'];
        revenue = stats['revenue'];
        _isLoading = false;

        if (!_categories.any((c) => c['id'].toString() == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
        if (!_catalogs.any((c) => c['id'] == _selectedCatalogId)) {
          _selectedCatalogId = null;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Data load nahi ho saka: $e", isError: true);
    }
  }

  // Notification Broadcast Submit
  Future<void> _submitNotification() async {
    final title = _notiTitleController.text.trim();
    final body = _notiBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showSnackBar("Zaroori: Title aur Body dono lazmi likhein!", isError: true);
      return;
    }

    setState(() => _isSendingNoti = true);
    try {
      await _controller.sendPushNotification(title: title, body: body);
      _notiTitleController.clear();
      _notiBodyController.clear();
      _showSnackBar("🚀 Notification successfully send aur broadcast ho chuki hai!");
    } catch (e) {
      _showSnackBar("Notification fail: $e", isError: true);
    } finally {
      setState(() => _isSendingNoti = false);
    }
  }

  // --- Nayi Category Add Karne Ka Dialog Box ---
  void _showAddCategoryDialog() {
    TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Create New Category", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: catController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter Category Name (e.g., Neon, Anime)",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purple)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = catController.text.trim();
              if (name.isNotEmpty) {
                try {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  await _controller.createCategory(name);
                  await _loadInitialData();
                  _showSnackBar("Category '$name' database mein save ho gayi!");
                } catch (e) {
                  setState(() => _isLoading = false);
                  _showSnackBar("Save failed: $e", isError: true);
                }
              }
            },
            child: const Text("Save to DB", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _notiTitleController.dispose();
    _notiBodyController.dispose();
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Admin Panel Control", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 26),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumRequestsScreen()));
              },
              tooltip: "Premium Requests",
            ),
            IconButton(
              icon: const Icon(Icons.add_box, color: Colors.blueAccent, size: 26),
              onPressed: _showAddCategoryDialog,
              tooltip: "Add Category",
            ),
            IconButton(
              icon: const Icon(Icons.create_new_folder_rounded, color: Colors.amber, size: 26),
              onPressed: () async {
                final refresh = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateCatalogScreen()),
                );
                if (refresh == true) {
                  _loadInitialData();
                }
              },
              tooltip: "Create New Catalog Pack",
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadInitialData,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.cloud_upload_rounded), text: "Upload Center"),
              Tab(icon: Icon(Icons.analytics_rounded), text: "Analytics & Alerts"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
          children: [
            // ==============================
            // TAB 1: ORIGINAL UPLOAD CENTER
            // ==============================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Analytics Row
                  Row(
                    children: [
                      _statTile("Downloads", "$downloads", Colors.blue),
                      _statTile("Premium Users", "$subscribers", Colors.green),
                      _statTile("Total Revenue", "\$$revenue", AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 25),

                  const Text("1. Select Wallpaper Image", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Image Picker Container
                  GestureDetector(
                    onTap: () async {
                      final file = await _picker.pickImage(source: ImageSource.gallery);
                      if (file != null) {
                        setState(() => _selectedImage = File(file.path));
                      }
                    },
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_selectedImage!, fit: BoxFit.cover))
                          : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 50, color: Colors.purple),
                          SizedBox(height: 10),
                          Text("Tap to select wallpaper", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  const Text("2. Select Destination Mode", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // DYNAMIC RADIO SELECTOR
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("Category", style: TextStyle(color: Colors.white, fontSize: 13)),
                          value: "Category",
                          groupValue: _uploadTargetType,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _uploadTargetType = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("Catalog Pack", style: TextStyle(color: Colors.white, fontSize: 13)),
                          value: "Catalog",
                          groupValue: _uploadTargetType,
                          activeColor: Colors.amber,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _uploadTargetType = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Text(
                      _uploadTargetType == "Category" ? "3. Assign Database Category" : "3. Assign Catalog Collection Pack",
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // CONDITIONAL DROPDOWN SWITCHER
                  _uploadTargetType == "Category"
                      ? DropdownButtonFormField<String>(
                    dropdownColor: AppColors.surface,
                    value: _selectedCategoryId,
                    hint: const Text("Choose Category", style: TextStyle(color: Colors.grey)),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _categories.isEmpty
                        ? [const DropdownMenuItem(value: null, child: Text("No Category! Click + on top to add", style: TextStyle(color: Colors.redAccent)))]
                        : _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(c['name'] ?? 'Unnamed'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  )
                      : DropdownButtonFormField<int>(
                    dropdownColor: AppColors.surface,
                    value: _selectedCatalogId,
                    hint: const Text("Choose Catalog Collection", style: TextStyle(color: Colors.grey)),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _catalogs.isEmpty
                        ? [const DropdownMenuItem(value: null, child: Text("No Catalog Pack! Click Folder + on top to create", style: TextStyle(color: Colors.amber)))]
                        : _catalogs.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['title'] ?? 'Untitled Pack'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCatalogId = val),
                  ),
                  const SizedBox(height: 20),

                  // Premium Toggle Control
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: const Text("Premium Wallpaper (Paid Subscription Required)", style: TextStyle(color: Colors.white, fontSize: 14)),
                      activeColor: AppColors.primary,
                      value: _isPremium,
                      onChanged: (val) => setState(() => _isPremium = val),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: const Text("Animated Wallpaper (Auto Slideshow)", style: TextStyle(color: Colors.white, fontSize: 14)),
                      activeColor: AppColors.primary,
                      value: _isAnimated,
                      onChanged: (val) => setState(() => _isAnimated = val),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Dynamic Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _uploadTargetType == "Category" ? AppColors.primary : Colors.amber[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      onPressed: () async {
                        if (_selectedImage == null) {
                          _showSnackBar("Zaroori: Pehle asset image select karein!", isError: true);
                          return;
                        }
                        if (_uploadTargetType == "Category" && _selectedCategoryId == null) {
                          _showSnackBar("Zaroori: Pehle target database category set karein!", isError: true);
                          return;
                        }
                        if (_uploadTargetType == "Catalog" && _selectedCatalogId == null) {
                          _showSnackBar("Zaroori: Pehle target Catalog Pack collection set karein!", isError: true);
                          return;
                        }

                        setState(() => _isLoading = true);
                        try {
                          if (_uploadTargetType == "Category") {
                            await _controller.uploadWallpaperProcess(
                                imageFile: _selectedImage!,
                                categoryId: _selectedCategoryId!,
                                isPremium: _isPremium,
                                isAnimated: _isAnimated);
                          } else {
                            await _controller.uploadWallpaperToCatalogProcess(
                              imageFile: _selectedImage!,
                              catalogId: _selectedCatalogId!,
                              isPremium: _isPremium,
                              isAnimated: _isAnimated);
                          }

                          setState(() {
                            _selectedImage = null;
                            _isLoading = false;
                          });

                          await _loadInitialData();
                          _showSnackBar("Zabardast! Wallpaper targets ke mutabiq storage aur custom DB table mein completely save ho chuka hai.");
                        } catch (e) {
                          setState(() => _isLoading = false);
                          _showSnackBar("Upload error: $e", isError: true);
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                          _uploadTargetType == "Category" ? "Upload & Save to Category" : "Upload & Save to Catalog Pack",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),

            // ==========================================
            // TAB 2: NEW ADVANCED ANALYTICS & NOTIFICATIONS
            // ==========================================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trending List Header
                  const Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 24),
                      SizedBox(width: 6),
                      Text("Top 5 Trending Wallpapers", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Animated Slideshow Banner
                  if (_animatedWallpapers.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 180,
                        child: PageView.builder(
                          controller: _carouselController,
                          itemCount: _animatedWallpapers.length,
                          itemBuilder: (context, index) {
                            final wall = _animatedWallpapers[index];
                            return Image.network(
                              wall['url'],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                    ),
                  if (_animatedWallpapers.isNotEmpty)
                    const SizedBox(height: 8),
                  if (_animatedWallpapers.isNotEmpty)
                    Center(
                      child: SmoothPageIndicator(
                        controller: _carouselController,
                        count: _animatedWallpapers.length,
                        effect: const ExpandingDotsEffect(
                          activeDotColor: AppColors.primary,
                          dotHeight: 8,
                          dotWidth: 8,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  _trendingWallpapers.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No trending data yet", style: TextStyle(color: Colors.grey))))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _trendingWallpapers.length,
                    itemBuilder: (context, index) {
                      final item = _trendingWallpapers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Text("#${index + 1}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(item['url'] ?? '', width: 45, height: 60, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("ID: ${item['id']}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(item['is_premium'] == true ? "Premium Item" : "Free Item", style: TextStyle(color: item['is_premium'] == true ? Colors.amber : Colors.green, fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("${item['downloads'] ?? 0}", style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                                const Text("downloads", style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 15),

                  // Broadcast Push Notification Section
                  const Text("Broadcast Push Notification", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text("Yahan se notification text likh kar broadcast karein.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),

                  const Text("Notification Title", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notiTitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      hintText: "e.g., New Pack Alert! 🔥",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("Message Body", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notiBodyController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      hintText: "Enter detailed notification message text...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isSendingNoti ? null : _submitNotification,
                      icon: _isSendingNoti
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(_isSendingNoti ? "Broadcasting..." : "Send Notification Now", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Card(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 5),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))
            ],
          ),
        ),
      ),
    );
  }
}
//explain