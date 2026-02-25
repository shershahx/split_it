// lib/features/settle/providers/settlements_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/settlement.dart';
import '../data/settlements_repository.dart';

/// Provider for settlements in a specific group
final settlementsProvider =
    FutureProvider.family<List<Settlement>, String>((ref, groupId) async {
  final repository = ref.read(settlementsRepositoryProvider);
  return await repository.getSettlements(groupId);
});

/// State notifier for creating/deleting settlements
class SettlementsNotifier extends StateNotifier<AsyncValue<void>> {
  final SettlementsRepository _repository;

  SettlementsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> saveSettlement(Settlement settlement) async {
    state = const AsyncValue.loading();
    try {
      await _repository.saveSettlement(settlement);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteSettlement(Settlement settlement) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteSettlement(settlement);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final settlementsNotifierProvider =
    StateNotifierProvider<SettlementsNotifier, AsyncValue<void>>((ref) {
  return SettlementsNotifier(ref.read(settlementsRepositoryProvider));
});
