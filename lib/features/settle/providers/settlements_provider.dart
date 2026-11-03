import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/settlement.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/settlements_repository.dart';

<<<<<<< HEAD
final settlementsProvider =
    FutureProvider.family<List<Settlement>, String>((ref, groupId) async {
  if (ref.watch(currentUserProvider.select((user) => user?.uid)) == null) {
    return [];
  }
  return ref.watch(settlementsRepositoryProvider).getSettlements(groupId);
=======
final settlementsPageIndexProvider =
    StateProvider.autoDispose.family<int, String>((ref, groupId) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return 0;
});

final settlementPageProvider =
    FutureProvider.autoDispose.family<SettlementPage, String>((ref, groupId) {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  final page = ref.watch(settlementsPageIndexProvider(groupId));
  if (userId == null) {
    return const SettlementPage(settlements: [], hasNext: false);
  }
  return ref
      .watch(settlementsRepositoryProvider)
      .getSettlementPage(groupId, page: page);
});

/// Legacy first-page preview, never a financial source of truth.
final settlementsProvider = FutureProvider.autoDispose
    .family<List<Settlement>, String>((ref, groupId) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (userId == null) return [];
  final repository = ref.watch(settlementsRepositoryProvider);
  return await repository.getSettlements(groupId);
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
});

class SettlementsNotifier extends StateNotifier<AsyncValue<void>> {
  SettlementsNotifier(this._repository, {this.onChanged})
      : super(const AsyncValue.data(null));

  final SettlementsRepository _repository;
<<<<<<< HEAD
  final void Function(Settlement settlement)? onChanged;

  Future<void> _mutate(
      Settlement settlement, Future<void> Function() action) async {
    if (state.isLoading)
      throw StateError('A payment update is already in progress');
    state = const AsyncValue.loading();
    try {
      await action();
      if (!mounted) return;
      onChanged?.call(settlement);
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
=======
  final void Function(String) _onSaved;

  SettlementsNotifier(this._repository, this._onSaved)
      : super(const AsyncValue.data(null));

  Future<void> saveSettlement(Settlement settlement) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    try {
      await _repository.saveSettlement(settlement);
      if (!mounted) return;
      _onSaved(settlement.groupId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
      rethrow;
    }
  }

<<<<<<< HEAD
  Future<void> saveSettlement(Settlement settlement) =>
      _mutate(settlement, () => _repository.saveSettlement(settlement));

  Future<void> deleteSettlement(Settlement settlement) =>
      _mutate(settlement, () => _repository.deleteSettlement(settlement));
}

final settlementsNotifierProvider =
    StateNotifierProvider<SettlementsNotifier, AsyncValue<void>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return SettlementsNotifier(ref.watch(settlementsRepositoryProvider),
      onChanged: (settlement) {
    ref.invalidate(settlementsProvider(settlement.groupId));
=======
  Future<void> deleteSettlement(Settlement settlement) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    try {
      await _repository.deleteSettlement(settlement);
      if (!mounted) return;
      _onSaved(settlement.groupId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final settlementsNotifierProvider =
    StateNotifierProvider.autoDispose<SettlementsNotifier, AsyncValue<void>>(
        (ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return SettlementsNotifier(ref.watch(settlementsRepositoryProvider),
      (groupId) {
    ref.invalidate(settlementsProvider(groupId));
    ref.invalidate(settlementPageProvider(groupId));
    ref.invalidate(settlementsPageIndexProvider(groupId));
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
  });
});
