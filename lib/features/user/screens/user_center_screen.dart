import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../../core/providers/premium_provider.dart';
import '../../../core/constants/colors.dart';
import '../providers/auth_provider.dart';
import '../controllers/favorites_storage.dart';
import 'login_screen.dart';
import 'premium_screen.dart';
import 'premium_purchase_screen.dart';
import '../../admin/screens/admin_dashboard.dart';

class UserCenterScreen extends ConsumerStatefulWidget {
  const UserCenterScreen({super.key});

  @override
  ConsumerState<UserCenterScreen> createState() => _UserCenterScreenState();
}

class _UserCenterScreenState extends ConsumerState<UserCenterScreen> {
  int _favoriteCount = 0;
  bool _isAutoChangerOn = false;
  String _autoInterval = "Turn Off";

  @override
  void initState() {
    super.initState();
    _loadUserCenterData();
  }

  Future<void> _loadUserCenterData() async {
    final savedFavs = await FavoritesStorage.getFavorites();
    final prefs = await SharedPreferences.getInstance();
    final interval = prefs.getString('auto_changer_interval') ?? "Turn Off";

    setState(() {
      _favoriteCount = savedFavs.length;
      _autoInterval = interval;
      _isAutoChangerOn = interval != "Turn Off";
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    setState(() {});
  }

  void _showAutoChangerDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surface : Colors.white,
          title: Text("Set Auto Interval", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogOption("Every 5 minutes", isDark),
              _buildDialogOption("Every 1 Hours", isDark),
              _buildDialogOption("Every 24 Hours (Daily)", isDark),
              _buildDialogOption("Turn Off", isDark, isDisable: true),
            ],
          ),
        );
      },
    ).then((_) => _loadUserCenterData());
  }

  Widget _buildDialogOption(String title, bool isDark, {bool isDisable = false}) {
    return ListTile(
      title: Text(title, style: TextStyle(color: isDisable ? Colors.redAccent : (isDark ? Colors.white : Colors.black))),
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        if (isDisable) {
          await prefs.remove('auto_changer_interval');
        } else {
          await prefs.setString('auto_changer_interval', title);
        }
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showLogoutDialog() {
    final isDark = themeNotifier.value == ThemeMode.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Kya aap apne account se logout karna chahte hain?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Logged out successfully!"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final isPremium = ref.watch(premiumProvider);
    final auth = ref.watch(authProvider);
    final textColor = isDark ? Colors.white : Colors.black;
    final bool isAdmin = auth.isAdmin;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : Colors.grey[50],
      appBar: AppBar(
        title: const Text("User Center", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            // --- 1. USER PROFILE CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: isAdmin
                        ? Colors.purpleAccent.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.2),
                    child: Icon(
                      isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                      size: 40,
                      color: isAdmin ? Colors.purpleAccent : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                auth.isLoggedIn ? (auth.user?.displayName ?? "User") : "Guest Explorer",
                                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.purpleAccent, width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_rounded, size: 12, color: Colors.purpleAccent),
                                    SizedBox(width: 4),
                                    Text("Admin", style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.isLoggedIn ? (auth.user?.email ?? "") : "explorer@wallpaperapp.com",
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPremium ? Colors.amber.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isPremium ? Colors.amber : Colors.grey, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isPremium ? Icons.workspace_premium_rounded : Icons.auto_awesome_rounded,
                                  size: 12, color: isPremium ? Colors.amber : Colors.grey),
                              const SizedBox(width: 4),
                              Text(isPremium ? "Premium Plan" : "Free Plan",
                                  style: TextStyle(color: isPremium ? Colors.amber : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (!auth.isLoggedIn) ...[
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                            },
                            child: const Text('Login / Register', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 2. QUICK STATS ROW ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text("$_favoriteCount", style: const TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text("Favorites", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(_isAutoChangerOn ? "Active" : "Off", style: TextStyle(color: _isAutoChangerOn ? Colors.green : Colors.grey, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text("Auto Changer", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!isPremium) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PremiumPurchaseScreen()),
                  );
                  setState(() {});
                },
                child: const Text("Upgrade to Premium", style: TextStyle(color: Colors.white)),
              ),
            ],
            const SizedBox(height: 25),

            // --- 3. FUNCTIONAL SETTINGS LIST ---
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text("APPLICATION SETTINGS", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: Colors.amber),
                    title: Text("Midnight Dark Theme", style: TextStyle(color: textColor, fontSize: 15)),
                    trailing: Switch(
                      value: isDark,
                      activeColor: AppColors.primary,
                      onChanged: (value) => _toggleTheme(value),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.autorenew_rounded, color: Colors.blueAccent),
                    title: Text("Auto Wallpaper Changer", style: TextStyle(color: textColor, fontSize: 15)),
                    subtitle: Text("Current Interval: $_autoInterval", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () => _showAutoChangerDialog(isDark),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded, color: Colors.teal),
                    title: Text("Clear App Cache", style: TextStyle(color: textColor, fontSize: 15)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("App Cache cleared successfully!"), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  // Admin Panel - ONLY visible to admin role
                  if (isAdmin) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.purpleAccent),
                      title: Text("Admin Panel", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: const Text("Manage wallpapers & catalogs", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 4. PORTALS & SUPPORT ---
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text("SUPPORT", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.share_rounded, color: Colors.orangeAccent),
                    title: Text("Share App With Friends", style: TextStyle(color: textColor, fontSize: 15)),
                    onTap: () {},
                  ),
                  if (auth.isLoggedIn) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.w500)),
                      onTap: () => _showLogoutDialog(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
