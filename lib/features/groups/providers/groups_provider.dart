import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/group.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/groups_repository.dart';

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
    FutureProvider.family<Group?, String>((ref, groupId) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (userId == null) return null;
  return ref.watch(groupsRepositoryProvider).getGroup(groupId);
});

class GroupsNotifier extends StateNotifier<AsyncValue<void>> {
  GroupsNotifier(this._repository) : super(const AsyncValue.data(null));

  final GroupsRepository _repository;

  Future<void> addMember(String groupId, String memberId) async {
    await _repository.addMember(groupId, memberId);
  }
}

final groupsNotifierProvider =
    StateNotifierProvider.autoDispose<GroupsNotifier, AsyncValue<void>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return GroupsNotifier(ref.watch(groupsRepositoryProvider));
});
