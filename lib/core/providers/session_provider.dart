import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Bumped whenever the stored auth token changes (sign-in, logout).
///
/// SharedPreferences is not reactive, so [isSignedInProvider] cannot observe
/// the token directly — this revision counter is the change signal. Only
/// [AuthNotifier] should bump it, so the two stay in lockstep.
final sessionRevisionProvider = StateProvider<int>((ref) => 0);

/// Whether a real account is signed in.
///
/// The single source of truth for guest gating: browsing the catalogue is open
/// to everyone, while anything account-scoped (cart, checkout, subscriptions,
/// profile) is gated on this. Derived from the stored token rather than from
/// [AuthState] so it survives a cold start before the profile has loaded.
final isSignedInProvider = Provider<bool>((ref) {
  ref.watch(sessionRevisionProvider);
  final storage = ref.watch(localStorageProvider).value;
  final token = storage?.getAuthToken();
  return token != null && token.isNotEmpty;
});

/// True when the app is being used without an account.
final isGuestProvider = Provider<bool>((ref) => !ref.watch(isSignedInProvider));

/// True while the auth flow was entered from a gated action rather than as the
/// app's entry point.
///
/// When set, the auth screens return to wherever the user was (popping the
/// pushed auth routes) instead of replacing the stack with home — so a guest
/// who tapped "Subscribe" lands back on the plan they chose, not the menu.
/// [AuthGate] sets and clears it.
final authReturnPendingProvider = StateProvider<bool>((ref) => false);
