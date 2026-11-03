import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/friends_provider.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref.invalidate(friendsProvider);
    ref.invalidate(friendRequestsProvider);
    ref.invalidate(singleFriendProvider);
    refreshFriendFinancials(ref);
    try {
      await Future.wait([
        ref.read(friendsProvider.future),
        ref.read(friendRequestsProvider.future),
      ]);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh friends: $error')),
        );
      }
    }
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, String requesterId,
      {required bool accept}) async {
    final userId = ref.read(currentUserProvider)?.uid;
    try {
      await ref
          .read(friendsNotifierProvider.notifier)
          .respondToFriendRequest(requesterId, accept: accept);
      if (context.mounted && ref.read(currentUserProvider)?.uid == userId) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              accept ? 'Friend request accepted' : 'Friend request declined'),
        ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not respond to friend request: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final requestsAsync = ref.watch(friendRequestsProvider);
    final busy = ref.watch(friendsNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('Incoming requests',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            requestsAsync.when(
              data: (requests) => requests.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No incoming requests'))
                  : Column(
                      children: requests.map((request) {
                      final name = request.displayName.trim();
                      return Card(
                          child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.getAvatarColor(name),
                                  child: Text(name.isEmpty
                                      ? '?'
                                      : name.characters.first.toUpperCase()),
                                ),
                                title:
                                    Text(name.isEmpty ? 'Split It user' : name),
                                subtitle: const Text('Wants to be your friend'),
                              ),
                              Wrap(spacing: 8, children: [
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _respond(
                                          context, ref, request.requesterId,
                                          accept: true),
                                  child: const Text('Accept'),
                                ),
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _respond(
                                          context, ref, request.requesterId,
                                          accept: false),
                                  child: const Text('Decline'),
                                ),
                              ]),
                            ]),
                      ));
                    }).toList()),
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
              error: (error, _) => _LoadError(
                message: 'Failed to load requests: $error',
                retry: () => ref.invalidate(friendRequestsProvider),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Text('Friends', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            friendsAsync.when(
              data: (friends) => friends.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        const Icon(Icons.people_outline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('No friends yet',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                            'Send a request to split expenses. Friends appear after accepting.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.push(AppRoutes.addFriend),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Send Friend Request'),
                        ),
                      ]),
                    )
                  : Column(
                      children: friends.map((friend) {
                      final name = friend.friendName.trim();
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
                          title: Text(name.isEmpty ? 'Friend' : name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              friend.friendEmail?.trim().isNotEmpty == true
                                  ? friend.friendEmail!
                                  : 'View shared expenses',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push(AppRoutes.friendDetail(friend.id)),
                        ),
                      );
                    }).toList()),
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
              error: (error, _) => _LoadError(
                message: 'Failed to load friends: $error',
                retry: () => ref.invalidate(friendsProvider),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Send friend request',
        onPressed: () => context.push(AppRoutes.addFriend),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: retry, child: const Text('Retry')),
        ]),
      );
}
