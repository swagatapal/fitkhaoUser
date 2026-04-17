// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../core/providers/providers.dart';
// import '../models/trending_item.dart';
// import '../repository/analytics_repository.dart';
//
// /// Provider for AnalyticsRepository
// final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
//   final localStorage = ref.watch(localStorageProvider).value;
//   final apiClient = ref.watch(apiClientProvider);
//   if (localStorage == null) {
//     throw Exception('LocalStorage not initialized');
//   }
//   return AnalyticsRepository(apiClient: apiClient, localStorage: localStorage);
// });
//
// class TrendingNotifier extends StateNotifier<AsyncValue<List<TrendingItem>>> {
//   final AnalyticsRepository _repo;
//   TrendingNotifier(this._repo) : super(const AsyncValue.loading());
//
//   Future<void> load({
//     required String kitchenId,
//     String timeSlot = 'morning',
//     int limit = 5,
//   }) async {
//     state = const AsyncValue.loading();
//     try {
//       final items = await _repo.getTrendingItems(
//         kitchenId: kitchenId,
//         timeSlot: timeSlot,
//         limit: limit,
//       );
//       state = AsyncValue.data(items);
//     } catch (e, st) {
//       state = AsyncValue.error(e, st);
//     }
//   }
// }
//
// final trendingProvider =
//     StateNotifierProvider<TrendingNotifier, AsyncValue<List<TrendingItem>>>(
//         (ref) {
//   final repo = ref.watch(analyticsRepositoryProvider);
//   return TrendingNotifier(repo);
// });
//
