// lib/features/friends/data/friends_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloud_db_service.dart';
import '../../../shared/models/friend.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(ref.read(cloudDbServiceProvider));
});

class FriendsRepository {
  final CloudDbService _cloudDbService;
  final String _objectTypeName = "Friend"; // Must match Cloud DB Object Type name

  FriendsRepository(this._cloudDbService);

  // Fetch friends for a user
  Future<List<Friend>> getFriends(String userId) async {
    try {
      final query = CloudDBQuery(_objectTypeName);
      query.equalTo("userId1", userId);
      
      final result = await _cloudDbService.executeQuery(query);
      return result.map((map) => Friend.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch friends: $e');
    }
  }

  // Add a friend
  Future<void> addFriend(Friend friend) async {
    try {
      await _cloudDbService.upsertObject(_objectTypeName, [friend.toMap()]);
    } catch (e) {
      throw Exception('Failed to add friend: $e');
    }
  }

  // Delete a friend
  Future<void> deleteFriend(Friend friend) async {
    try {
      await _cloudDbService.deleteObject(_objectTypeName, [friend.toMap()]);
    } catch (e) {
      throw Exception('Failed to delete friend: $e');
    }
  }

  // Get a single friend by ID
  Future<Friend?> getFriendById(String friendId) async {
    try {
      final query = CloudDBQuery(_objectTypeName);
      query.equalTo('id', friendId);
      final result = await _cloudDbService.executeQuery(query);
      if (result.isEmpty) return null;
      return Friend.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch friend: $e');
    }
  }
}
