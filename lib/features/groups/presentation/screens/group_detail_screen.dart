import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/balance_calculator.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../settle/providers/settlements_provider.dart';
import '../../providers/groups_provider.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Member'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Member User ID',
              hintText: 'Enter the user ID to add',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_add),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final memberId = controller.text.trim();
                if (memberId.isEmpty) return;

                Navigator.of(dialogContext).pop();

                try {
                  await ref
                      .read(groupsNotifierProvider.notifier)
                      .addMember(groupId, memberId);

                  // Refresh group and groups list
                  ref.invalidate(groupProvider(groupId));
                  ref.invalidate(groupsProvider);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$memberId added to group')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add member: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));

    return Scaffold(
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Group not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(group.name),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.getAvatarColor(group.name),
                          AppColors.getAvatarColor(group.name).withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.group,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (group.description != null) ...[
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          group.description!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        'Members (${group.memberIds.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...group.memberIds.map((memberId) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.getAvatarColor(memberId),
                              child: Text(
                                memberId[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(memberId == group.createdBy
                                ? 'You (Creator)'
                                : 'Member'),
                            subtitle: Text(memberId),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      _BalancesSection(groupId: groupId, memberIds: group.memberIds),
                      const SizedBox(height: 24),
                      Text(
                        'Recent Expenses',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _ExpensesSection(groupId: groupId),
                      const SizedBox(height: 24),
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline),
                              title: const Text('Add Expense'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                context.push(
                                  AppRoutes.groupAddExpense(groupId),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.person_add_outlined),
                              title: const Text('Add Member'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showAddMemberDialog(context, ref),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupProvider(groupId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Expenses section widget
class _ExpensesSection extends ConsumerWidget {
  final String groupId;

  const _ExpensesSection({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(groupId));

    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No expenses yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: expenses.take(5).map((expense) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.receipt, color: AppColors.primary),
                ),
                title: Text(
                  expense.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Paid by ${expense.paidBy} • ${DateFormat('MMM d, yyyy').format(expense.date)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Text(
                  '\$${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  context.push(AppRoutes.expenseDetail(expense.id));
                },
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load expenses: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

// Balances section widget — shows simplified debts for the group
class _BalancesSection extends ConsumerWidget {
  final String groupId;
  final List<String> memberIds;

  const _BalancesSection({required this.groupId, required this.memberIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final settlementsAsync = ref.watch(settlementsProvider(groupId));

    return expensesAsync.when(
      data: (expenses) {
        return settlementsAsync.when(
          data: (settlements) {
            if (expenses.isEmpty && settlements.isEmpty) {
              return const SizedBox.shrink();
            }

            final debts = BalanceCalculator.simplifyDebts(
              expenses: expenses,
              settlements: settlements,
              memberIds: memberIds,
            );

            if (debts.isEmpty) {
              return Card(
                color: AppColors.positiveBalance.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.positiveBalance),
                      SizedBox(width: 12),
                      Text(
                        'All settled up!',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.positiveBalance,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balances',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...debts.map((debt) {
                  final isCurrentUserDebtor = debt.from == currentUser?.uid;
                  final isCurrentUserCreditor = debt.to == currentUser?.uid;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        isCurrentUserDebtor
                            ? Icons.arrow_upward
                            : isCurrentUserCreditor
                                ? Icons.arrow_downward
                                : Icons.swap_horiz,
                        color: isCurrentUserDebtor
                            ? AppColors.negativeBalance
                            : isCurrentUserCreditor
                                ? AppColors.positiveBalance
                                : Colors.grey,
                      ),
                      title: Text(
                        isCurrentUserDebtor
                            ? 'You owe ${debt.to}'
                            : isCurrentUserCreditor
                                ? '${debt.from} owes you'
                                : '${debt.from} owes ${debt.to}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Text(
                        '\$${debt.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCurrentUserDebtor
                              ? AppColors.negativeBalance
                              : isCurrentUserCreditor
                                  ? AppColors.positiveBalance
                                  : null,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
