import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/financial_error.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/models/expense.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../data/expenses_repository.dart';
import '../../providers/expenses_provider.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

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
                child: const Text('Retry'),
              ),
            ]),
          )),
        ),
      ),
    );
  }
}
