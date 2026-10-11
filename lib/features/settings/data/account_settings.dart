import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

import '../../auth/data/current_user_provider.dart';
import '../../auth/data/auth_error_mapper.dart';
import '../../auth/data/auth_exception.dart';

class SettingsAccount {
  const SettingsAccount({
    required this.id,
    required this.email,
    this.name = '',
    this.avatarUrl = '',
  });
  final String id;
  final String email;
  final String name;
  final String avatarUrl;

  factory SettingsAccount.fromUser(User user) => SettingsAccount(
    id: user.id,
    email: user.email ?? '',
    name: user.userMetadata?['display_name'] as String? ?? '',
    avatarUrl: user.userMetadata?['avatar_url'] as String? ?? '',
  );
}

final settingsAuthProvider = Provider<GoTrueClient>(
  (ref) => Supabase.instance.client.auth,
);

final settingsAccountProvider = StreamProvider<SettingsAccount?>((ref) async* {
  final owner = ref.watch(currentUserIdProvider);
  if (owner == null) {
    yield null;
    return;
  }
  final auth = ref.watch(settingsAuthProvider);
  SettingsAccount? account() => auth.currentUser?.id == owner
      ? SettingsAccount.fromUser(auth.currentUser!)
      : null;
  yield account();
  await for (final _ in auth.onAuthStateChange) {
    yield account();
  }
});

typedef UpdateSettingsAccount =
    Future<void> Function(String owner, UserAttributes attributes);
final updateSettingsAccountProvider = Provider<UpdateSettingsAccount>((ref) {
  final auth = ref.watch(settingsAuthProvider);
  return (owner, attributes) async {
    if (ref.read(currentUserIdProvider) != owner ||
        auth.currentUser?.id != owner) {
      throw const AuthFailureException(
        'Sign in again before changing your account.',
      );
    }
    try {
      await auth.updateUser(
        attributes,
        emailRedirectTo: attributes.email == null
            ? null
            : SupabaseConfig.emailRedirectTo,
      );
    } on AuthException catch (error) {
      throw mapAuthException(error);
    }
  };
});

String? validateProfile(String name, String avatar) {
  if (name.trim().length > 200) {
    return 'Display name must be at most 200 characters.';
  }
  avatar = avatar.trim();
  if (avatar.length > 2000) {
    return 'Avatar URL must be at most 2000 characters.';
  }
  if (avatar.isNotEmpty) {
    final uri = Uri.tryParse(avatar);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return 'Avatar URL must be an http(s) link.';
    }
  }
  return null;
}
