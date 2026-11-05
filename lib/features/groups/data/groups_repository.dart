import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/group.dart';
import '../../auth/providers/auth_provider.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(supabaseClientProvider));
});

class GroupPage {
  final List<Group> groups;
  final bool hasNext;

  const GroupPage({required this.groups, required this.hasNext});
}

class GroupInvite {
  final String id;
  final String groupName;
  final String invitedByName;
  final DateTime expiresAt;

  const GroupInvite({
    required this.id,
    required this.groupName,
    required this.invitedByName,
    required this.expiresAt,
  });

  factory GroupInvite.fromMap(Map<String, dynamic> map) => GroupInvite(
        id: map['id'] as String,
        groupName: map['group_name'] as String,
        invitedByName: map['invited_by_name'] as String,
        expiresAt: DateTime.parse(map['expires_at'] as String).toLocal(),
      );
}

class GroupsRepository {
  GroupsRepository(this._client);

  final SupabaseClient _client;
  static const pageSize = 20;
  static const _columns =
      'id,name,description,image_url,currency,created_by,created_at';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const GroupFailure('Please sign in again.');
    return id;
  }

  void _checkAccount(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const GroupFailure('Your account changed. Please try again.');
    }
  }

  /// RLS restricts this query to the signed-in user's memberships. Never fetch
  /// all users' groups and filter them on the device.
  Future<GroupPage> getGroups({int page = 0}) async {
    final userId = _userId;
    if (page < 0) throw ArgumentError.value(page, 'page');
    final rows = await _client
        .from('groups')
        .select('$_columns,group_members(count)')
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .range(page * pageSize, (page + 1) * pageSize);
    _checkAccount(userId);
    return GroupPage(
      groups: List.unmodifiable(rows.take(pageSize).map(Group.fromMap)),
      hasNext: rows.length > pageSize,
    );
  }

  Future<void> createGroup(Group group) async {
    if (group.createdBy != _userId) {
      throw const GroupFailure('You can only create a group for yourself.');
    }
    if (group.name.trim().isEmpty || group.name.trim().length > 100) {
      throw const GroupFailure('Use a group name of 1–100 characters.');
    }
    if ((group.description?.length ?? 0) > 500) {
      throw const GroupFailure('Keep the description under 501 characters.');
    }
    if (!supportedCurrencies.contains(group.currency)) {
      throw const GroupFailure('Please select a supported currency.');
    }
    // Not an upsert: retrying must never overwrite an existing group.
    // The trigger creates the owner in the same transaction. Avoid RETURNING:
    // member-based SELECT policies run before AFTER INSERT triggers.
    await _client.from('groups').insert(group.toMap());
  }

  Future<Group?> getGroup(String groupId) async {
    final userId = _userId;
    final row = await _client
        .from('groups')
        .select('$_columns,group_members(count)')
        .eq('id', groupId)
        .maybeSingle();
    _checkAccount(userId);
    if (row == null) return null;

    // Use the count to detect stale/incomplete membership. A server row cap
    // below the requested batch size must not silently omit participants.
    final expectedCount = Group.fromMap(row).memberCount;
    final members = <Map<String, dynamic>>[];
    const batchSize = 100;
    while (members.length < expectedCount) {
      final offset = members.length;
      final batch = await _client
          .from('group_members')
          .select('user_id,role,profiles(display_name)')
          .eq('group_id', groupId)
          .order('user_id', ascending: true)
          .range(offset, offset + batchSize - 1);
      _checkAccount(userId);
      if (batch.isEmpty) break;
      members.addAll(batch);
    }
    if (members.length != expectedCount ||
        members.map((member) => member['user_id']).toSet().length !=
            expectedCount) {
      throw const GroupFailure('Group membership changed. Please refresh.');
    }
    return Group.fromMap({...row, 'group_members': members});
  }

  Future<List<GroupInvite>> getInvites({int page = 0}) async {
    final userId = _userId;
    if (page < 0) throw ArgumentError.value(page, 'page');
    final rows = await _client.rpc(
      'list_my_group_invites',
      params: {'page_offset': page * pageSize},
    ) as List;
    _checkAccount(userId);
    return List.unmodifiable(rows.map(
      (row) => GroupInvite.fromMap(row as Map<String, dynamic>),
    ));
  }

  Future<void> inviteMember(String groupId, String email) async {
    _userId;
    final normalized = email.trim().toLowerCase();
    if (normalized.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const GroupFailure('Enter a valid email address.');
    }
    await _client.rpc('send_group_invite', params: {
      'target_group_id': groupId,
      'invite_email': normalized,
    });
  }

  Future<String> acceptInvite(String inviteId) async {
    _userId;
    return await _client.rpc(
      'accept_group_invite',
      params: {'invite_id': inviteId},
    ) as String;
  }

  Future<void> declineInvite(String inviteId) async {
    _userId;
    await _client.rpc(
      'decline_group_invite',
      params: {'invite_id': inviteId},
    );
  }
}

// Current financial calculations support two-decimal currencies only.
const supportedCurrencies = [
  'USD',
  'PKR',
  'EUR',
  'GBP',
  'INR',
  'AED',
  'SAR',
  'CAD',
  'AUD',
];

class GroupFailure implements Exception {
  final String message;
  const GroupFailure(this.message);

  @override
  String toString() => message;
}

/// Do not expose raw server responses, SQL details, or transport exceptions.
String groupErrorMessage(Object error) {
  if (error is GroupFailure) return error.message;
  if (error is PostgrestException) {
    switch (error.code) {
      case '42501':
        return 'You do not have permission for this action. Refresh and try again.';
      case '23505':
        return 'This record already exists. Refresh before trying again.';
      case 'P0001':
        const messages = {
          'Invitation is invalid or expired',
          'This person is already a member',
          'You cannot invite yourself',
          'Only group admins can invite members',
          'Enter a valid email address',
        };
        if (messages.contains(error.message)) return error.message;
      case 'PGRST202':
        return 'The groups database update is required. Run the groups workflow migration.';
    }
  }
  return 'Could not complete the request. Check your connection and try again.';
}
