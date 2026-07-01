import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// Riverpod provider exposing [AuthProvider] as a [ChangeNotifier].
final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider();
});
