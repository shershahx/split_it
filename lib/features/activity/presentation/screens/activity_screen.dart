import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../providers/activity_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref.invalidate(groupsProvider);
    ref.invalidate(allUserExpensesProvider);
    ref.invalidate(allExpensesProvider);
    try {
      await Future.wait<Object>([
        ref.read(groupsProvider.future),
        ref.read(allExpensesProvider.future),
      ]);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh activity: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(allExpensesProvider);
    final groupsAsync = ref.watch(groupsProvider);

    Widget loadError(String message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _refresh(context, ref),
                child: const Text('Retry'),
              ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(context, ref),
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) => groupsAsync.when(
          data: (groups) {
            final groupsById = {for (final group in groups) group.id: group};
            final sortedExpenses = [...expenses]
              ..sort((a, b) => b.date.compareTo(a.date));

            return RefreshIndicator(
              onRefresh: () => _refresh(context, ref),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount:
                    sortedExpenses.isEmpty ? 2 : sortedExpenses.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                          'Expense history • Pull to refresh. Not a live feed.'),
                    );
                  }
                  if (sortedExpenses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64),
                      child: Column(children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No activity yet',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text('Your expense history will appear here'),
                      ]),
                    );
                  }
                  final expense = sortedExpenses[index - 1];
                  final group = groupsById[expense.groupId];
                  final currency = group?.currency.trim().toUpperCase();
                  final hasCurrency = currency != null && currency.isNotEmpty;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child:
                            const Icon(Icons.receipt, color: AppColors.primary),
                      ),
                      title: Text(expense.description,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([
                        group?.name ?? 'Group unavailable — refresh to retry',
                        DateFormat('MMM d, yyyy').format(expense.date),
                        'Paid by: ${expense.paidBy}',
                      ].join('\n')),
                      trailing: Text(
                        hasCurrency
                            ? '${expense.amount.toStringAsFixed(2)} $currency'
                            : 'Currency\nunavailable',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () =>
                          context.push(AppRoutes.expenseDetail(expense.id)),
                    ),
                  );
                },
              ),
            );
          }

          // Sort expenses by date (newest first)
          final sortedExpenses = [...expenses]
            ..sort((a, b) => b.date.compareTo(a.date));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allExpensesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedExpenses.length,
              itemBuilder: (context, index) {
                final expense = sortedExpenses[index];
                final formattedDate = DateFormat('MMM d, yyyy').format(expense.date);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.receipt,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      expense.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Paid by: ${expense.paidBy}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '\$${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
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
              Text(error is UnsupportedError
                  ? 'Expense activity is not connected yet.'
                  : 'Error loading activity'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allExpensesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => loadError('Error loading activity: $error'),
      ),
    );
  }
}
