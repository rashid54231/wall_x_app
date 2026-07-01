import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  return PremiumNotifier();
});

class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier() : super(false) {
    _checkEntitlement();
  }

  Future<void> _checkEntitlement() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        state = false;
        return;
      }

      // Check active subscription with expiry
      final data = await Supabase.instance.client
          .from('user_subscriptions')
          .select('is_active, expires_at')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (data == null) {
        state = false;
        return;
      }

      // Check if expired
      final expiresAt = data['expires_at'] as String?;
      if (expiresAt != null) {
        final expiryDate = DateTime.parse(expiresAt);
        if (DateTime.now().isAfter(expiryDate)) {
          // Expired — auto deactivate
          state = false;
          await Supabase.instance.client
              .from('user_subscriptions')
              .update({'is_active': false})
              .eq('user_id', user.id);
          return;
        }
      }

      state = data['is_active'] == true;
    } catch (_) {
      state = false;
    }
  }

  Future<void> refresh() async {
    await _checkEntitlement();
  }
}
