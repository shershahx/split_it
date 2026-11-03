import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/group.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/groups_repository.dart';

<<<<<<< HEAD
final groupsProvider = FutureProvider<List<Group>>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (userId == null) return [];
  return ref.watch(groupsRepositoryProvider).getGroups(userId);
});

final groupProvider =
    FutureProvider.family<Group?, String>((ref, groupId) async {
  if (ref.watch(currentUserProvider.select((user) => user?.uid)) == null) {
    return null;
  }
  return ref.watch(groupsRepositoryProvider).getGroup(groupId);
});

class GroupsNotifier extends StateNotifier<AsyncValue<void>> {
  GroupsNotifier(this._repository, {this.onChanged})
      : super(const AsyncValue.data(null));

  final GroupsRepository _repository;
  final void Function(String groupId)? onChanged;

  Future<void> _mutate(String groupId, Future<void> Function() action) async {
    if (state.isLoading)
      throw StateError('A group update is already in progress');
    state = const AsyncValue.loading();
    try {
      await action();
      if (!mounted) return;
      onChanged?.call(groupId);
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
      rethrow;
    }
  }

  Future<void> createGroup(Group group) =>
      _mutate(group.id, () => _repository.createGroup(group));

  Future<void> addMember(String groupId, String memberId) =>
      _mutate(groupId, () => _repository.addMember(groupId, memberId));
}

final groupsNotifierProvider =
    StateNotifierProvider<GroupsNotifier, AsyncValue<void>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return GroupsNotifier(ref.watch(groupsRepositoryProvider), onChanged: (id) {
    ref.invalidate(groupsProvider);
    ref.invalidate(groupProvider(id));
  });
=======
final groupsPageProvider = StateProvider.autoDispose<int>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return 0;
});
final invitesPageProvider = StateProvider.autoDispose<int>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return 0;
});

// Only the current page is retained; no permanent cache per visited page.
final groupsProvider = FutureProvider.autoDispose<GroupPage>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  final page = ref.watch(groupsPageProvider);
  if (userId == null) return const GroupPage(groups: [], hasNext: false);
  return ref.watch(groupsRepositoryProvider).getGroups(page: page);
});

final groupInvitesProvider =
    FutureProvider.autoDispose<List<GroupInvite>>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  final page = ref.watch(invitesPageProvider);
  if (userId == null) return [];
  return ref.watch(groupsRepositoryProvider).getInvites(page: page);
});

final groupProvider =
    FutureProvider.autoDispose.family<Group?, String>((ref, groupId) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (userId == null) return null;
  return ref.watch(groupsRepositoryProvider).getGroup(groupId);
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
});
