import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/admin_controller.dart';
import '../../../core/constants/colors.dart';

class CreateCatalogScreen extends StatefulWidget {
  const CreateCatalogScreen({super.key});

  @override
  State<CreateCatalogScreen> createState() => _CreateCatalogScreenState();
}

class _CreateCatalogScreenState extends State<CreateCatalogScreen> {
  final AdminController _controller = AdminController();
  final _picker = ImagePicker();
  final _titleController = TextEditingController();

  File? _selectedCoverImage;
  bool _isLoading = false;

  // --- DROPDOWN STATE VARIABLES ---
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories(); // Screen load hote hi categories fetch hongi
  }

  // Database se categories dropdown ke liye laana
  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _controller.fetchCategories();
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Categories load nahi ho sakeen: $e", isError: true);
    }
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

  Future<void> _pickCoverImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _selectedCoverImage = File(file.path));
    }
  }

  Future<void> _submitCatalog() async {
    final title = _titleController.text.trim();

    // Validation checks updated with category validation
    if (_selectedCategoryId == null) {
      _showSnackBar("Zaroori: Pehle main category select karein!", isError: true);
      return;
    }
    if (title.isEmpty) {
      _showSnackBar("Zaroori: Catalog ka title likhna lazmi hai!", isError: true);
      return;
    }
    if (_selectedCoverImage == null) {
      _showSnackBar("Zaroori: Cover Image lagana lazmi hai!", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // AdminController ka updated method call ho raha hai categoryId ke sath
      await _controller.createNewCatalog(
        title: title,
        coverImageFile: _selectedCoverImage!,
        categoryId: _selectedCategoryId!, // Bheji gayi category_id table relation ke liye
      );

      _showSnackBar("Zabardast! Naya Catalog Pack '$title' successfully ban gaya.");

      if (mounted) {
        Navigator.pop(context, true); // True return karein taaki pichli screen refresh ho sake
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Catalog banane mein error aaya: $e", isError: true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Create Catalog Pack", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _categories.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. SELECT MAIN CATEGORY DROPDOWN ---
            const Text("Select Target Category", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: AppColors.surface,
              value: _selectedCategoryId,
              hint: const Text("Choose Parent Category", style: TextStyle(color: Colors.grey, fontSize: 14)),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: _categories.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'].toString(),
                  child: Text(c['name'] ?? 'Unnamed Category'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 25),

            // --- 2. CATALOG TITLE ---
            const Text("Catalog Title", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                hintText: "e.g., Aesthetic Anime, Minimal Pack",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 25),

            // --- 3. SELECT CATALOG COVER IMAGE ---
            const Text("Select Catalog Cover Image", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: _selectedCoverImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(_selectedCoverImage!, fit: BoxFit.cover),
                )
                    : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, size: 50, color: Colors.amber),
                    SizedBox(height: 10),
                    Text("Tap to select cover photo", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- 4. SUBMIT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                onPressed: _isLoading ? null : _submitCatalog,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.folder_special_rounded, color: Colors.white),
                label: Text(
                  _isLoading ? "Creating Pack..." : "Create & Save Pack",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}