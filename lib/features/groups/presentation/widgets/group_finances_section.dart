import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/financial_error.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/models/group.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../settle/providers/settlements_provider.dart';

void invalidateGroupFinances(WidgetRef ref, String groupId,
    {bool resetPages = false}) {
  if (resetPages) {
    ref.read(expensePageIndexProvider(groupId).notifier).state = 0;
    ref.read(settlementsPageIndexProvider(groupId).notifier).state = 0;
  }
  ref.invalidate(expensePageProvider(groupId));
  ref.invalidate(settlementPageProvider(groupId));
  ref.invalidate(groupBalancesProvider(groupId));
}

class GroupFinancesSection extends ConsumerWidget {
  final Group group;
  const GroupFinancesSection({super.key, required this.group});

  Future<void> _open(BuildContext context, WidgetRef ref, String route) async {
    final changed = await context.push<bool>(route);
    if (changed == true && context.mounted) {
      invalidateGroupFinances(ref, group.id, resetPages: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
    final balances = ref.watch(groupBalancesProvider(group.id));
    final expenses = ref.watch(expensePageProvider(group.id));
    final settlements = ref.watch(settlementPageProvider(group.id));
    final names = {
      for (final member in group.members) member.userId: member.displayName
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        balances.when(
          data: (net) {
            final units = net[userId] ?? 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(units > 0
                        ? 'You are owed'
                        : units < 0
                            ? 'You owe'
                            : 'Your net balance'),
                    Text(
                        '${group.currency} ${Money.formatMinorUnits(units.abs())}',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const Text(
                        'Across all saved group records, not just this page. '
                        'Payments are made outside the app.'),
                  ],
                ),
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _LoadError(
            error: error,
            retry: () => ref.invalidate(groupBalancesProvider(group.id)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  _open(context, ref, AppRoutes.groupAddExpense(group.id)),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
            OutlinedButton.icon(
              onPressed: group.memberCount < 2
                  ? null
                  : () => _open(context, ref, AppRoutes.groupSettle(group.id)),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record payment'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Expenses', style: Theme.of(context).textTheme.titleLarge),
        expenses.when(
          data: (page) => Column(children: [
            if (page.expenses.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No expenses on this page.')),
            ...page.expenses.map((expense) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expense.description),
                  subtitle: Text('${DateFormat.yMMMd().format(expense.date)} · '
                      'Paid by ${names[expense.paidBy] ?? 'Member'}'),
                  trailing: Text(
                      '${expense.currency} ${Money.formatMinorUnits(Money.toMinorUnits(expense.amount))}'),
                  onTap: () =>
                      _open(context, ref, AppRoutes.expenseDetail(expense.id)),
                )),
            _PageControls(
              page: ref.watch(expensePageIndexProvider(group.id)),
              hasNext: page.hasNext,
              label: 'expenses',
              change: (value) => ref
                  .read(expensePageIndexProvider(group.id).notifier)
                  .state = value,
            ),
          ]),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _LoadError(
            error: error,
            retry: () => ref.invalidate(expensePageProvider(group.id)),
          ),
        ),
        const SizedBox(height: 24),
        Text('Recorded payments',
            style: Theme.of(context).textTheme.titleLarge),
        settlements.when(
          data: (page) => Column(children: [
            if (page.settlements.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No payments on this page.')),
            ...page.settlements.map((payment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${names[payment.paidBy] ?? 'Member'} → ${names[payment.paidTo] ?? 'Member'}'),
                  subtitle: Text('${DateFormat.yMMMd().format(payment.date)}'
                      '${payment.note?.isNotEmpty == true ? ' · ${payment.note}' : ''}'),
                  trailing: Text(
                      '${group.currency} ${Money.formatMinorUnits(Money.toMinorUnits(payment.amount))}'),
                )),
            _PageControls(
              page: ref.watch(settlementsPageIndexProvider(group.id)),
              hasNext: page.hasNext,
              label: 'payments',
              change: (value) => ref
                  .read(settlementsPageIndexProvider(group.id).notifier)
                  .state = value,
            ),
          ]),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _LoadError(
            error: error,
            retry: () => ref.invalidate(settlementPageProvider(group.id)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const _LoadError({required this.error, required this.retry});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(financialErrorMessage(error)),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      );
}

class _PageControls extends StatelessWidget {
  final int page;
  final bool hasNext;
  final String label;
  final ValueChanged<int> change;
  const _PageControls(
      {required this.page,
      required this.hasNext,
      required this.label,
      required this.change});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous $label page',
            onPressed: page == 0 ? null : () => change(page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${page + 1}'),
          IconButton(
            tooltip: 'Next $label page',
            onPressed: hasNext ? () => change(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
}
