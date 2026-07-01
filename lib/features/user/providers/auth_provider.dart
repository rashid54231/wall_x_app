import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_user.dart' as app_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthProvider extends ChangeNotifier {
  app_auth.AuthUser? _user;
  bool _isInitialized = false;

  app_auth.AuthUser? get user => _user;
  bool get isInitialized => _isInitialized;

  bool get isLoggedIn => _user != null;

  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> restoreSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.user.id.isNotEmpty) {
        final role = await _fetchUserRole(session.user.id);
        _user = app_auth.AuthUser(
          id: session.user.id,
          email: session.user.email ?? '',
          displayName: session.user.userMetadata?['full_name'] as String?,
          role: role,
        );
        notifyListeners();
      }
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    if (response.user != null) {
      final role = await _fetchUserRole(response.user!.id);
      _user = app_auth.AuthUser(
        id: response.user!.id,
        email: response.user!.email ?? '',
        displayName: response.user!.userMetadata?['full_name'] as String?,
        role: role,
      );
      notifyListeners();
    } else {
      throw Exception('Login failed');
    }
  }

  Future<void> signup({required String email, required String password, String? fullName}) async {
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    if (response.user != null) {
      // Auto-insert role as 'user' in user_roles table
      try {
        await Supabase.instance.client.from('user_roles').insert({
          'user_id': response.user!.id,
          'role': 'user',
        });
      } catch (_) {}

      _user = app_auth.AuthUser(
        id: response.user!.id,
        email: response.user!.email ?? '',
        displayName: fullName,
        role: 'user',
      );
      notifyListeners();
    } else {
      throw Exception('Signup failed');
    }
  }

  Future<void> resetPassword(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
  }

  Future<void> refreshRole() async {
    if (_user == null) return;
    final role = await _fetchUserRole(_user!.id);
    _user = app_auth.AuthUser(
      id: _user!.id,
      email: _user!.email,
      displayName: _user!.displayName,
      role: role,
    );
    notifyListeners();
  }

  Future<String> _fetchUserRole(String userId) async {
    try {
      debugPrint('DEBUG AUTH: Fetching role for userId: $userId');
      final data = await Supabase.instance.client
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();
      debugPrint('DEBUG AUTH: Role data from DB: $data');
      final role = data?['role'] as String? ?? 'user';
      debugPrint('DEBUG AUTH: Final role: $role');
      return role;
    } catch (e) {
      debugPrint('DEBUG AUTH: ERROR fetching role: $e');
      return 'user';
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _user = null;
    notifyListeners();
  }
}

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());
