import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/cloud_db_service.dart';
import '../../../shared/models/friend.dart';
import '../../auth/providers/auth_provider.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(ref.watch(supabaseClientProvider));
});

/// A pending relationship, deliberately not represented as an accepted Friend.
/// Profile details describe the other participant; email is not disclosed.
class FriendRequest {
  const FriendRequest({
    required this.requesterId,
    required this.addresseeId,
    required this.displayName,
    required this.createdAt,
    this.avatarUrl,
  });

  final String requesterId;
  final String addresseeId;
  final String displayName;
  final DateTime createdAt;
  final String? avatarUrl;
}

class FriendsRepository {
  FriendsRepository(this._client);

  final SupabaseClient _client;

  /// Friend.id is the other user's UUID, stable from either relationship side.
  /// Only accepted relationships are returned; pending requests use a separate API.
  /// Balance is not stored on friendships; financial providers derive balances.
  Future<List<Friend>> getFriends(String userId) async {
    final rows = await CloudDbService.readAll(() => _client
        .rpc<PostgrestList>('list_friends', params: {'p_user_id': userId}));
    final friends = rows
        .map((row) => Friend(
              id: row['id'] as String,
              userId1: userId,
              userId2: row['id'] as String,
              friendName: row['display_name'] as String,
              friendEmail: row['email'] as String?,
              friendImageUrl: row['avatar_url'] as String?,
            ))
        .toList();
    friends.sort((a, b) {
      final name = a.friendName.compareTo(b.friendName);
      return name != 0 ? name : a.id.compareTo(b.id);
    });
    return friends;
  }

  /// Requests friendship, not acceptance. Success deliberately does not reveal
  /// whether the email exists. The existing form passes email in userId2 and a
  /// temporary relationship ID; neither placeholder is persisted.
  Future<void> addFriend(Friend friend) async {
    final email = (friend.friendEmail ??
            (friend.userId2.contains('@') ? friend.userId2 : ''))
        .trim();
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw ArgumentError(
          'An existing account email is required to add a friend');
    }
    await _client.rpc('add_friend_by_email', params: {'p_email': email});
  }

  Future<void> deleteFriend(Friend friend) => removeFriend(friend.id);

  /// Also cancels an outgoing request or dismisses an incoming request.
  Future<void> removeFriend(String friendId) async {
    await _client.rpc('remove_friend', params: {'p_friend_id': friendId});
  }

  /// Incoming requests only. Outgoing targets stay private until acceptance.
  Future<List<FriendRequest>> getFriendRequests() async {
    final rows = await CloudDbService.readAll(
      () => _client.rpc<PostgrestList>('list_friend_requests'),
      keyColumn: 'requester_id',
    );
    final requests = rows
        .map((row) => FriendRequest(
              requesterId: row['requester_id'] as String,
              addresseeId: row['addressee_id'] as String,
              displayName: row['display_name'] as String,
              createdAt: DateTime.parse(row['created_at'] as String),
              avatarUrl: row['avatar_url'] as String?,
            ))
        .toList();
    requests.sort((a, b) {
      final date = b.createdAt.compareTo(a.createdAt);
      return date != 0 ? date : b.requesterId.compareTo(a.requesterId);
    });
    return requests;
  }

  /// Only the addressee may accept/decline an incoming pending request.
  Future<void> respondToFriendRequest(
    String requesterId, {
    required bool accept,
  }) async {
    await _client.rpc('respond_friend_request', params: {
      'p_requester_id': requesterId,
      'p_accept': accept,
    });
  }

  Future<Friend?> getFriendById(String friendId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to view friends');
    final friends = await getFriends(userId);
    for (final friend in friends) {
      if (friend.id == friendId) return friend;
    }
    return null;
  }
}
