import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/wallet_balance_model.dart';
import '../repository/wallet_repository.dart';

/// State for wallet balance and subscription
class WalletState {
  final WalletInfo? wallet;
  final SubscriptionInfo? subscription;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.wallet,
    this.subscription,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    WalletInfo? wallet,
    SubscriptionInfo? subscription,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      subscription: subscription ?? this.subscription,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get hasActiveSubscription => subscription?.isActive ?? false;
}

/// Notifier for wallet state
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _walletRepository;

  WalletNotifier(this._walletRepository) : super(const WalletState());

  /// Load wallet balance and subscription info
  Future<void> loadWalletBalance() async {
    debugPrint('[WalletNotifier] Loading wallet balance...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _walletRepository.getWalletBalance();

      if (response.success && response.data != null) {
        state = WalletState(
          wallet: response.data!.wallet,
          subscription: response.data!.subscription,
          isLoading: false,
          error: null,
        );
        debugPrint('[WalletNotifier] Wallet loaded successfully');
        debugPrint('[WalletNotifier] Has active subscription: ${state.hasActiveSubscription}');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty ? response.message : 'Failed to load wallet',
        );
      }
    } catch (e) {
      debugPrint('[WalletNotifier] Error loading wallet: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load wallet balance',
      );
    }
  }

  /// Refresh wallet balance
  Future<void> refresh() async {
    await loadWalletBalance();
  }
}

/// Provider for wallet state
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletRepo = ref.watch(walletRepositoryProvider);
  return WalletNotifier(walletRepo);
});
