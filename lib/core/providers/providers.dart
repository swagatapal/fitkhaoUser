import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';
import '../services/phone_number_service.dart';
import '../network/api_client.dart';
import '../../features/auth/repository/auth_repository.dart';
import '../../features/delivery/repository/subscription_repository.dart';
import '../../features/delivery/repository/wallet_repository.dart';
import '../../features/delivery/repository/order_repository.dart';
import '../../features/history/repository/order_history_repository.dart';
import '../../features/delivery/repository/delivery_slot_repository.dart';

/// Provider for LocalStorageService
final localStorageProvider = FutureProvider<LocalStorageService>((ref) async {
  return await LocalStorageService.getInstance();
});

/// Provider for PhoneNumberService
final phoneNumberServiceProvider = Provider<PhoneNumberService>((ref) {
  return PhoneNumberService();
});

/// Provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  return const ApiClient();
});

/// Provider for AuthRepository
/// Handles authentication with local storage and remote API
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return AuthRepository(localStorage: localStorage, apiClient: apiClient);
});

/// Provider for SubscriptionRepository
/// Handles subscription creation with remote API
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return SubscriptionRepository(apiClient: apiClient, localStorage: localStorage);
});

/// Provider for WalletRepository
/// Handles wallet balance and subscription status with remote API
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return WalletRepository(apiClient: apiClient, localStorage: localStorage);
});

/// Provider for OrderRepository
/// Handles order placement and payment with remote API
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return OrderRepository(apiClient: apiClient, localStorage: localStorage);
});

/// Provider for OrderHistoryRepository
/// Handles fetching order history with remote API
final orderHistoryRepositoryProvider = Provider<OrderHistoryRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return OrderHistoryRepository(apiClient: apiClient, localStorage: localStorage);
});

/// Provider for DeliverySlotRepository
/// Handles fetching delivery slots with remote API
final deliverySlotRepositoryProvider = Provider<DeliverySlotRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return DeliverySlotRepository(apiClient: apiClient, localStorage: localStorage);
});

