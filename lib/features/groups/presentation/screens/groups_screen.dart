import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/groups_repository.dart';
import '../../providers/groups_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      ref.invalidate(groupsProvider);
      await ref.read(groupsProvider.future);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh groups: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
<<<<<<< HEAD
      appBar: AppBar(title: const Text('Groups')),
      body: groupsAsync.when(
        data: (groups) => RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: groups.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  children: [
                    const SizedBox(height: 64),
                    const Icon(Icons.group_outlined,
                        size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('No groups yet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Create a group to start splitting expenses.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.createGroup),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Group'),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final name = group.name.trim();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.getAvatarColor(name),
                          child: Text(
                              name.isEmpty
                                  ? '?'
                                  : name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 24, color: Colors.white)),
                        ),
                        title: Text(name.isEmpty ? 'Unnamed group' : name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (group.description?.trim().isNotEmpty ?? false)
                              Text(group.description!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                                '${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'} • ${group.currency}'),
                          ],
=======
      appBar: AppBar(
        title: const Text('Groups'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Group invitations',
            icon: const Icon(Icons.mail_outline),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              isDismissible: false,
              enableDrag: false,
              builder: (_) => const FractionallySizedBox(
                heightFactor: 0.85,
                child: _InvitationsSheet(),
              ),
            ),
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (page) {
          final groups = page.groups;
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ref.watch(groupsPageProvider) == 0
                        ? 'No groups yet'
                        : 'No groups on this page',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group to start splitting expenses',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(groupsPageProvider.notifier).state = 0;
                      ref.invalidate(groupsProvider);
                    },
                    child: const Text('Refresh groups'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(groupsProvider.future).then<void>(
                  (_) {},
                  onError: (Object _, StackTrace __) {},
                ),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == groups.length) {
                  return _PageControls(
                    page: ref.watch(groupsPageProvider),
                    hasNext: page.hasNext,
                    onChanged: (page) {
                      ref.read(groupsPageProvider.notifier).state = page;
                    },
                  );
                }
                final group = groups[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.getAvatarColor(group.name),
                      child: Text(
                        group.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('${AppRoutes.groups}/${group.id}'),
                      ),
<<<<<<< HEAD
                    );
                  },
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Failed to load groups: $error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () => ref.invalidate(groupsProvider),
                    child: const Text('Retry')),
              ],
            ),
=======
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (group.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            group.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${group.memberCount} member${group.memberCount != 1 ? 's' : ''} · ${group.currency}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('${AppRoutes.groups}/${group.id}');
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(groupErrorMessage(error)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupsProvider),
                child: const Text('Retry'),
              ),
            ],
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create group',
<<<<<<< HEAD
        onPressed: () => context.push(AppRoutes.createGroup),
=======
        onPressed: () {
          context.push(AppRoutes.createGroup);
        },
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  final int page;
  final bool hasNext;
  final ValueChanged<int> onChanged;

  const _PageControls({
    required this.page,
    required this.hasNext,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 0 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${page + 1}'),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
}

class _InvitationsSheet extends ConsumerStatefulWidget {
  const _InvitationsSheet();

  @override
  ConsumerState<_InvitationsSheet> createState() => _InvitationsSheetState();
}

class _InvitationsSheetState extends ConsumerState<_InvitationsSheet> {
  bool _busy = false;

  Future<void> _answer(GroupInvite invite, {required bool accept}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(groupsRepositoryProvider);
      if (accept) {
        final groupId = await repository.acceptInvite(invite.id);
        if (!mounted) return;
        ref.invalidate(groupProvider(groupId));
        ref.read(groupsPageProvider.notifier).state = 0;
        ref.invalidate(groupsProvider);
      } else {
        await repository.declineInvite(invite.id);
      }
      if (!mounted) return;
      // Go back to page one so a removed last item cannot strand an empty page.
      ref.read(invitesPageProvider.notifier).state = 0;
      ref.invalidate(groupInvitesProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(accept ? 'You joined the group.' : 'Invitation declined.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(groupErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(groupInvitesProvider);
    return PopScope(
      canPop: !_busy,
      child: Column(
        children: [
          ListTile(
            title: const Text('Group invitations'),
            subtitle:
                const Text('Invites appear here, not in a separate email.'),
            trailing: IconButton(
              tooltip: 'Close invitations',
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: invites.when(
              data: (rows) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(groupInvitesProvider.future).then<void>(
                          (_) {},
                          onError: (Object _, StackTrace __) {},
                        ),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      rows.length.clamp(0, GroupsRepository.pageSize) + 2,
                  itemBuilder: (context, index) {
                    final count =
                        rows.length.clamp(0, GroupsRepository.pageSize);
                    if (index == count) {
                      return count == 0
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No pending invitations.'),
                            )
                          : const SizedBox.shrink();
                    }
                    if (index == count + 1) {
                      return _PageControls(
                        page: ref.watch(invitesPageProvider),
                        hasNext: rows.length > GroupsRepository.pageSize,
                        onChanged: (page) {
                          if (!_busy) {
                            ref.read(invitesPageProvider.notifier).state = page;
                          }
                        },
                      );
                    }
                    final invite = rows[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(invite.groupName,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('Invited by ${invite.invitedByName}'),
                            Text(
                              'Expires ${MaterialLocalizations.of(context).formatMediumDate(invite.expiresAt)}',
                            ),
                            Wrap(
                              spacing: 12,
                              children: [
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _answer(invite, accept: true),
                                  child: const Text('Join'),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _answer(invite, accept: false),
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(groupErrorMessage(error)),
                      TextButton(
                        onPressed: () => ref.invalidate(groupInvitesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
