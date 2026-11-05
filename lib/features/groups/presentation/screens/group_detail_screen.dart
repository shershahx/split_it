import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../friends/providers/friends_provider.dart';
import '../../../settle/providers/settlements_provider.dart';
import '../../data/groups_repository.dart';
import '../../providers/groups_provider.dart';
import '../widgets/group_finances_section.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final userId = ref.watch(currentUserProvider.select((user) => user?.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Group')),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(
              child: Text('Group unavailable. You may no longer be a member.'),
            );
          }
          final canInvite = group.members.any(
            (member) => member.userId == userId && member.canInvite,
          );
          return RefreshIndicator(
            onRefresh: () async {
              invalidateGroupFinances(ref, groupId);
              ref.invalidate(groupProvider(groupId));
              await Future.wait([
                ref.read(groupProvider(groupId).future),
                ref.read(expensePageProvider(groupId).future),
                ref.read(settlementPageProvider(groupId).future),
                ref.read(groupBalancesProvider(groupId).future),
              ]).then<void>((_) {}, onError: (Object _, StackTrace __) {});
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(children: [
                    Text(group.name,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text('${group.memberCount} members · ${group.currency}'),
                    if (group.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 12),
                      Text(group.description!),
                    ],
                    const SizedBox(height: 16),
                    GroupFinancesSection(group: group),
                    if (canInvite)
                      FilledButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => _InviteMemberDialog(groupId: groupId),
                        ),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Invite by email'),
                      ),
                    const SizedBox(height: 24),
                    Text('Members',
                        style: Theme.of(context).textTheme.titleLarge),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: group.members.length,
                    itemBuilder: (context, index) {
                      final member = group.members[index];
                      final name = member.displayName;
                      final balances =
                          ref.watch(groupBalancesProvider(groupId));
                      final units = balances.asData?.value[member.userId];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.getAvatarColor(name),
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name.characters.first.toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          member.userId == userId ? '$name (You)' : name,
                        ),
                        subtitle: Text(units == null
                            ? member.role
                            : '${member.role} · ${units < 0 ? 'Owes' : 'Owed'} '
                                '${group.currency} ${Money.formatMinorUnits(units.abs())}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(groupErrorMessage(error)),
                TextButton(
                  onPressed: () => ref.invalidate(groupProvider(groupId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteMemberDialog extends ConsumerStatefulWidget {
  final String groupId;
  const _InviteMemberDialog({required this.groupId});

  @override
  ConsumerState<_InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(groupsRepositoryProvider).inviteMember(
            widget.groupId,
            _controller.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Invitation saved. They can sign in with this email and open '
          'Groups → Group invitations to join. No email is sent.',
        ),
      ));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = groupErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Invite to group'),
          content: TextField(
            controller: _controller,
            enabled: !_busy,
            autofocus: true,
            maxLength: 254,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Email address',
              helperText: 'Use the email they sign in with.',
              errorText: _error,
              errorMaxLines: 4,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Sending…' : 'Save invitation'),
            ),
          ],
        ),
      );
}
