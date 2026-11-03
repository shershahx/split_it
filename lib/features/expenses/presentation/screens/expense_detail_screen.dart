import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
<<<<<<< HEAD
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/models/expense.dart';
import '../../../activity/providers/activity_provider.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../friends/providers/friends_provider.dart';
=======

import '../../../../core/services/financial_error.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/models/expense.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../data/expenses_repository.dart';
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
import '../../providers/expenses_provider.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}
<<<<<<< HEAD

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  bool _deleting = false;
  bool _confirming = false;

  String get expenseId => widget.expenseId;

  @override
  Widget build(BuildContext context) {
    final expenseAsync = ref.watch(singleExpenseProvider(expenseId));
    final mutationLoading = ref.watch(expensesNotifierProvider).isLoading;
=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  bool _busy = false;

  Future<void> _delete(Expense expense) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text(
            'This removes the expense and all its splits, changing the group balances. This cannot be undone.'),
        actions: [
<<<<<<< HEAD
          expenseAsync.maybeWhen(
            data: (expense) => expense != null
                ? IconButton(
                    tooltip: 'Delete expense',
                    icon: _deleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline),
                    onPressed: _deleting || _confirming || mutationLoading
                        ? null
                        : () => _confirmDelete(context, ref, expense),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: expenseAsync.when(
        data: (expense) {
          if (expense == null) {
            return _loadError('Expense not found',
                () => ref.invalidate(singleExpenseProvider(expenseId)));
          }
          final formattedDate =
              DateFormat('EEEE, MMMM d, yyyy').format(expense.date);

          final groupAsync = ref.watch(groupProvider(expense.groupId));
          return groupAsync.when(
            data: (group) {
              if (group == null || group.currency.trim().isEmpty) {
                return _loadError('Group currency is unavailable', () {
                  ref.invalidate(groupProvider(expense.groupId));
                });
              }
              final currency = group.currency.trim().toUpperCase();
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(singleExpenseProvider(expenseId));
                  ref.invalidate(groupProvider(expense.groupId));
                  try {
                    await Future.wait<Object?>([
                      ref.read(singleExpenseProvider(expenseId).future),
                      ref.read(groupProvider(expense.groupId).future),
                    ]);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Could not refresh expense: $error')),
                      );
                    }
                  }
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.receipt_long,
                                  size: 36, color: AppColors.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              expense.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${expense.amount.toStringAsFixed(2)} $currency',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Paid by
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: const Text('Paid by'),
                        trailing: Text(
                          expense.paidBy,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Split breakdown
                    if (expense.split.isNotEmpty) ...[
                      Text(
                        'Split Breakdown',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            ...expense.split.entries.map((entry) => ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AppColors.getAvatarColor(entry.key),
                                    child: Text(
                                      entry.key.isNotEmpty
                                          ? entry.key[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(entry.key),
                                  trailing: Text(
                                    '${entry.value.toStringAsFixed(2)} $currency',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                )),
                            const Divider(height: 1),
                            ListTile(
                              title: const Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Text(
                                '${expense.amount.toStringAsFixed(2)} $currency',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _loadError(
                'Could not load group currency: $error',
                () => ref.invalidate(groupProvider(expense.groupId))),
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
                onPressed: () =>
                    ref.invalidate(singleExpenseProvider(expenseId)),
=======
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(expensesRepositoryProvider).deleteExpense(expense);
      if (!mounted) return;
      ref.invalidate(singleExpenseProvider(expense.id));
      ref.read(expensePageIndexProvider(expense.groupId).notifier).state = 0;
      ref.invalidate(expensePageProvider(expense.groupId));
      ref.invalidate(groupBalancesProvider(expense.groupId));
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(financialErrorMessage(error))),
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(singleExpenseProvider(widget.expenseId));
    final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
    final expense = record.asData?.value;
    final group = expense == null
        ? null
        : ref.watch(groupProvider(expense.groupId)).asData?.value;
    final canDelete = expense != null &&
        (expense.createdBy == userId ||
            (group?.members.any(
                    (member) => member.userId == userId && member.canInvite) ??
                false));
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expense'),
          actions: [
            if (canDelete)
              IconButton(
                tooltip: 'Delete expense',
                onPressed: _busy ? null : () => _delete(expense),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: record.when(
          data: (expense) {
            if (expense == null) {
              return const Center(child: Text('Expense unavailable.'));
            }
            final names = {
              for (final member in group?.members ?? [])
                member.userId: member.displayName,
            };
            final shares = expense.splitInMinorUnits.entries.toList();
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shares.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.description,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text(
                          '${expense.currency} ${Money.formatMinorUnits(Money.toMinorUnits(expense.amount))}',
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(DateFormat.yMMMd().format(expense.date)),
                      Text('Paid by ${names[expense.paidBy] ?? 'Member'}'),
                      const SizedBox(height: 24),
                      Text('Split breakdown',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (_busy) const LinearProgressIndicator(),
                    ],
                  );
                }
                final share = shares[index - 1];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(share.key == userId
                      ? '${names[share.key] ?? 'Member'} (You)'
                      : names[share.key] ?? 'Member'),
                  trailing: Text(
                      '${expense.currency} ${Money.formatMinorUnits(share.value)}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(financialErrorMessage(error)),
              TextButton(
                onPressed: () =>
                    ref.invalidate(singleExpenseProvider(widget.expenseId)),
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
                child: const Text('Retry'),
              ),
            ]),
          )),
        ),
      ),
    );
  }
<<<<<<< HEAD

  Widget _loadError(String message, VoidCallback retry) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: retry, child: const Text('Retry')),
          ]),
        ),
      );

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Expense expense) async {
    if (_deleting || _confirming) return;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text(
            'Are you sure you want to delete this expense? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed == true && context.mounted) {
      setState(() => _deleting = true);
      try {
        await ref
            .read(expensesNotifierProvider.notifier)
            .deleteExpense(expense);
        if (!mounted) return;
        ref.invalidate(singleExpenseProvider(expenseId));
        ref.invalidate(expensesProvider(expense.groupId));
        ref.invalidate(groupProvider(expense.groupId));
        ref.invalidate(groupsProvider);
        ref.invalidate(allUserExpensesProvider);
        ref.invalidate(allExpensesProvider);
        ref.invalidate(friendFinancialsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted')),
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.groupDetail(expense.groupId));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _deleting = false);
      }
    }
  }
=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
}
