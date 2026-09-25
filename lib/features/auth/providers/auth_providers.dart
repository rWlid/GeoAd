import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors.dart';
import '../../../core/utils/image_compress.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/auth_repository.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => AuthRepository(Supabase.instance.client),
    );

final StreamProvider<AuthState> authStateChangesProvider =
    StreamProvider<AuthState>(
      (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges,
    );

final Provider<AsyncValue<String?>> currentUserIdProvider =
    Provider<AsyncValue<String?>>(
      (Ref ref) => ref
          .watch(authStateChangesProvider)
          .whenData((AuthState state) => state.session?.user.id),
    );

final AsyncNotifierProvider<ProfileNotifier, Profile?> profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile?>(
      ProfileNotifier.new,
      retry: (int retryCount, Object error) => null,
    );

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final String? userId = ref.watch(
      currentUserIdProvider.select((AsyncValue<String?> id) => id.value),
    );
    if (userId == null) {
      return null;
    }
    return ref.read(authRepositoryProvider).fetchProfile();
  }

  Future<void> completeOnboarding({
    required String name,
    required bool isBusiness,
    String? businessName,
    CompressedImage? logo,
  }) async {
    final Ref buildRef = ref;
    final Profile? before = state.value;
    if (before == null) {
      throw const AppException(AppErrorKind.unknown);
    }
    if (normalizeProfileName(name) == null) {
      throw const AppException(AppErrorKind.invalidName);
    }
    if (isBusiness && normalizeBusinessName(businessName ?? '') == null) {
      throw const AppException(AppErrorKind.invalidBusinessName);
    }
    final ProfileRepository repository = ref.read(profileRepositoryProvider);

    final String? uploaded = isBusiness && logo != null
        ? await repository.uploadLogo(logo)
        : null;
    final ({String name, String? businessName}) saved;
    try {
      saved = await repository.completeOnboarding(
        name: name,
        isBusiness: isBusiness,
        businessName: isBusiness ? businessName : null,
        logoPath: uploaded,
      );
    } catch (_) {
      if (uploaded != null) {
        await repository.deleteLogo(uploaded);
      }
      rethrow;
    }
    if (buildRef.mounted) {
      state = AsyncData<Profile?>(
        before.afterOnboarding(
          name: saved.name,
          isBusiness: isBusiness,
          businessName: saved.businessName,
        ),
      );
    }
  }
}

enum AuthGate { loading, signedOut, error, needsName, ready }

final Provider<AuthGate> authGateProvider = Provider<AuthGate>((Ref ref) {
  final AsyncValue<String?> userId = ref.watch(currentUserIdProvider);
  if (!userId.hasValue) {
    return AuthGate.loading;
  }
  if (userId.value == null) {
    return AuthGate.signedOut;
  }

  final AsyncValue<Profile?> profile = ref.watch(profileProvider);
  if (profile.isLoading) {
    return AuthGate.loading;
  }
  if (profile.hasError) {
    return AuthGate.error;
  }
  return profile.value?.name == null ? AuthGate.needsName : AuthGate.ready;
});
