// lib/features/groups/data/groups_repository.dart
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloud_db_service.dart';
import '../../../shared/models/group.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.read(cloudDbServiceProvider));
});

class GroupsRepository {
  final CloudDbService _cloudDbService;
  final String _objectTypeName = "Group"; // Must match Cloud DB Object Type name

  GroupsRepository(this._cloudDbService);

  // Fetch all groups for a user
  Future<List<Group>> getGroups(String userId) async {
    try {
      // Query groups where user is a member
      // Note: Cloud DB queries are limited. We might need a composite index.
      // For now, let's assuming we query all groups and filter locally or use a proper query if supported.
      // AGConnect Cloud DB supports 'contains' in newer versions or array contains?
      // Actually, 'contains' on a list field is tricky.
      // Often better to specific user-groups relationship table or query simply.
      
      // Let's try querying by createdBy first as a placeholder or if supported query.
      // Since 'memberIds' is a list, we might need a separate table 'GroupMember'.
      // But for simplicity with NoSQL, we often duplicate data or fetch all.
      
      // Creating a simple query for now.
      // Since Cloud DB doesn't support 'array-contains' natively in this simple API wrapper easily,
      // and we are storing memberIds as a list, we fetch all groups and filter client-side.
      // This is inefficient for large datasets but works for MVP.
      final query = AGConnectCloudDBQuery(_objectTypeName);
      
      final result = await _cloudDbService.executeQuery(query);
      final allGroups = result.map((map) => Group.fromMap(map)).toList();
      
      return allGroups.where((group) => group.memberIds.contains(userId)).toList();
    } catch (e) {
      throw Exception('Failed to fetch groups: $e');
    }
  }

  // Create a new group
  Future<void> createGroup(Group group) async {
    try {
      await _cloudDbService.upsertObject(_objectTypeName, [group.toMap()]);
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  // Get group by ID
  Future<Group?> getGroup(String groupId) async {
     try {
      final query = AGConnectCloudDBQuery(_objectTypeName);
      query.equalTo("id", groupId);
      
      final result = await _cloudDbService.executeQuery(query);
      if (result.isNotEmpty) {
        return Group.fromMap(result.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch group: $e');
    }
  }

  // Update a group (upsert)
  Future<void> updateGroup(Group group) async {
    try {
      await _cloudDbService.upsertObject(_objectTypeName, [group.toMap()]);
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }
}
