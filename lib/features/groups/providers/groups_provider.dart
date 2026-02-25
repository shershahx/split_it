// lib/features/groups/providers/groups_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/group.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/groups_repository.dart';

// Provider for groups list
final groupsProvider = FutureProvider<List<Group>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repository = ref.read(groupsRepositoryProvider);
  return await repository.getGroups(user.uid);
});

// Provider for a specific group
final groupProvider = FutureProvider.family<Group?, String>((ref, groupId) async {
  final repository = ref.read(groupsRepositoryProvider);
  return await repository.getGroup(groupId);
});

// State notifier for creating/updating groups
class GroupsNotifier extends StateNotifier<AsyncValue<void>> {
  final GroupsRepository _repository;

  GroupsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> createGroup(Group group) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createGroup(group);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Add a member to a group by their user ID.
  Future<void> addMember(String groupId, String memberId) async {
    state = const AsyncValue.loading();
    try {
      final group = await _repository.getGroup(groupId);
      if (group == null) throw Exception('Group not found');

      if (group.memberIds.contains(memberId)) {
        state = const AsyncValue.data(null);
        throw Exception('Member is already in this group');
      }

      final updatedGroup = group.copyWith(
        memberIds: [...group.memberIds, memberId],
      );
      await _repository.updateGroup(updatedGroup);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final groupsNotifierProvider = StateNotifierProvider<GroupsNotifier, AsyncValue<void>>((ref) {
  return GroupsNotifier(ref.read(groupsRepositoryProvider));
});
