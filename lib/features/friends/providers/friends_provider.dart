// lib/features/friends/providers/friends_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/friend.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/friends_repository.dart';

// Provider for friends list
final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repository = ref.read(friendsRepositoryProvider);
  return await repository.getFriends(user.uid);
});

// State notifier for managing friends
class FriendsNotifier extends StateNotifier<AsyncValue<void>> {
  final FriendsRepository _repository;

  FriendsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> addFriend(Friend friend) async {
    state = const AsyncValue.loading();
    try {
      await _repository.addFriend(friend);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteFriend(Friend friend) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteFriend(friend);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final friendsNotifierProvider = StateNotifierProvider<FriendsNotifier, AsyncValue<void>>((ref) {
  return FriendsNotifier(ref.read(friendsRepositoryProvider));
});

// Provider for a single friend by ID
final singleFriendProvider = FutureProvider.family<Friend?, String>((ref, friendId) async {
  final repository = ref.read(friendsRepositoryProvider);
  return repository.getFriendById(friendId);
});
