import 'package:flutter/material.dart';
import '../controllers/user_controller.dart';
import 'category_wallpapers_screen.dart'; // Iske baad yeh screen banayenge
import '../../../core/constants/colors.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final UserController _userController = UserController();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _userController.fetchCategories();
      setState(() {
        _categories = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Categories load karne mein masla aaya: $e"), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("All Categories", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _categories.isEmpty
          ? const Center(child: Text("No categories found", style: TextStyle(color: Colors.white)))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,         // Ek line mein 2 categories dikhengi
          childAspectRatio: 1.3,     // Card ka size thoda wide rectangle hoga
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];

          // Har category ka unique look dene ke liye random/gradient backgrounds ya placeholder images
          return GestureDetector(
            onTap: () {
              // Category par click karne par uske andar ke wallpapers wali screen par le jayenge
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryWallpapersScreen(
                    categoryId: category['id'],
                    categoryName: category['name'],
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    AppColors.surface,
                    AppColors.primary.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Card Design Details
                  Positioned(
                    bottom: -10,
                    right: -10,
                    child: Icon(
                      Icons.folder_open_rounded,
                      size: 80,
                      color: Colors.white.withOpacity(0.03),
                    ),
                  ),
                  // Category Name Center Mein
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grid_view_rounded, color: Colors.purpleAccent, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          category['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}