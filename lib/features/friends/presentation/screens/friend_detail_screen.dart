import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../providers/friends_provider.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendId;

  const FriendDetailScreen({super.key, required this.friendId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendAsync = ref.watch(singleFriendProvider(friendId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Detail'),
        elevation: 0,
      ),
      body: friendAsync.when(
        data: (friend) {
          if (friend == null) {
            return const Center(child: Text('Friend not found'));
          }

          final isOwed = friend.balance > 0;
          final settled = friend.balance == 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.getAvatarColor(friend.friendName),
                        child: Text(
                          friend.friendName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        friend.friendName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (friend.friendEmail != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          friend.friendEmail!,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: settled
                              ? Colors.grey[100]
                              : isOwed
                                  ? AppColors.positiveBalance.withValues(alpha: 0.1)
                                  : AppColors.negativeBalance.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          settled
                              ? 'All settled up'
                              : isOwed
                                  ? '${friend.friendName} owes you \$${friend.balance.abs().toStringAsFixed(2)}'
                                  : 'You owe ${friend.friendName} \$${friend.balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: settled
                                ? Colors.grey[600]
                                : isOwed
                                    ? AppColors.positiveBalance
                                    : AppColors.negativeBalance,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Shared expenses
              Text(
                'Shared Expenses',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _SharedExpensesList(friendUserId: friend.userId2),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(singleFriendProvider(friendId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedExpensesList extends ConsumerWidget {
  final String friendUserId;

  const _SharedExpensesList({required this.friendUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExpensesAsync = ref.watch(allUserExpensesProvider);

    return allExpensesAsync.when(
      data: (allExpenses) {
        // Filter expenses involving this friend (paidBy or in split)
        final shared = allExpenses
            .where((e) => e.paidBy == friendUserId || e.split.containsKey(friendUserId))
            .toList();

        if (shared.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No shared expenses yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: shared.map((expense) {
              final date = DateFormat('MMM d').format(expense.date);
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.receipt, size: 16, color: AppColors.primary),
                ),
                title: Text(expense.description),
                subtitle: Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                trailing: Text(
                  '\$${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      )),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
