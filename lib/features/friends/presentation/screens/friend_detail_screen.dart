import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/friends_provider.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendId;

  const FriendDetailScreen({super.key, required this.friendId});

  Future<void> _remove(BuildContext context, WidgetRef ref, String name) async {
    final userId = ref.read(currentUserProvider)?.uid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
            'Remove $name from your friends? Shared expenses and payments will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        ref.read(currentUserProvider)?.uid != userId) {
      return;
    }
    try {
      await ref.read(friendsNotifierProvider.notifier).removeFriend(friendId);
      if (context.mounted && ref.read(currentUserProvider)?.uid == userId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Friend removed')));
        context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove friend: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendAsync = ref.watch(singleFriendProvider(friendId));
    final busy = ref.watch(friendsNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Friend Detail')),
      body: friendAsync.when(
        data: (friend) {
          if (friend == null) {
            return _Retry(
              message: 'Friend not found',
              retry: () => ref.invalidate(friendsProvider),
            );
          }
          final name = friend.friendName.trim().isEmpty
              ? 'Friend'
              : friend.friendName.trim();
          final financials = ref.watch(friendFinancialsProvider(friendId));
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(friendsProvider);
              refreshFriendFinancials(ref);
              try {
                await Future.wait<Object?>([
                  ref.read(singleFriendProvider(friendId).future),
                  ref.read(friendFinancialsProvider(friendId).future),
                ]);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not refresh friend: $error')),
                  );
                }
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.getAvatarColor(name),
                      child: Text(name.characters.first.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 16),
                    Text(name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    if (friend.friendEmail?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(friend.friendEmail!),
                    ],
                  ]),
                )),
                const SizedBox(height: 16),
                financials.when(
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Balances by currency',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (data.balances.isEmpty)
                        const Card(
                            child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('All settled up'),
                        )),
                      for (final currency
                          in data.balances.keys.toList()..sort())
                        Card(
                            child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            data.balances[currency]! > 0
                                ? '$name owes you $currency ${Money.formatMinorUnits(Money.toMinorUnits(data.balances[currency]!).abs())}'
                                : 'You owe $name $currency ${Money.formatMinorUnits(Money.toMinorUnits(data.balances[currency]!).abs())}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: data.balances[currency]! > 0
                                  ? AppColors.positiveBalance
                                  : AppColors.negativeBalance,
                            ),
                          ),
                        )),
                      const SizedBox(height: 16),
                      Text('Shared Expenses',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (data.expenses.isEmpty)
                        const Card(
                            child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No shared expenses yet'),
                        )),
                      for (final shared in data.expenses)
                        Card(
                            child: ListTile(
                          leading: const Icon(Icons.receipt_outlined),
                          title: Text(shared.expense.description),
                          subtitle: Text(
                              '${shared.groupName} · ${DateFormat.yMMMd().format(shared.expense.date)}'),
                          trailing: Text(
                              '${shared.currency} ${Money.formatMinorUnits(Money.toMinorUnits(shared.expense.amount))}'),
                          onTap: () => context
                              .push(AppRoutes.expenseDetail(shared.expense.id)),
                        )),
                    ],
                  ),
                  loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator())),
                  error: (error, _) => _Retry(
                    message:
                        'Could not load balances and shared expenses: $error',
                    retry: () => refreshFriendFinancials(ref),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _remove(context, ref, name),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Remove Friend'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Retry(
          message: 'Could not load friend: $error',
          retry: () => ref.invalidate(friendsProvider),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Retry')),
        ]),
      ));
}
