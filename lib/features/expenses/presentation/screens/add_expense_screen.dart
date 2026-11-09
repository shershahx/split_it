import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/financial_error.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/models/group.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../groups/data/groups_repository.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../data/expenses_repository.dart';
import '../../providers/expenses_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String? _payer;
  bool _busy = false;
  String? _error;
  Expense? _draft;
  String? _fingerprint;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(Group group) async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final units = Money.parseAmount(_amount.text);
      final payer = group.memberIds.contains(_payer) ? _payer! : userId;
      if (!group.memberIds.contains(payer) ||
          !group.memberIds.contains(userId)) {
        throw const FinancialFailure(
            'Group membership changed. Please refresh.');
      }
      final ids = Money.sortedMemberIds(group.memberIds);
      final fingerprint = jsonEncode([
        userId,
        group.id,
        _description.text.trim(),
        units,
        payer,
        ids,
        group.currency,
      ]);
      if (_draft == null || fingerprint != _fingerprint) {
        final amount = Money.fromMinorUnits(units);
        _draft = Expense(
          id: const Uuid().v4(),
          groupId: group.id,
          description: _description.text.trim(),
          amount: amount,
          paidBy: payer,
          date: DateTime.now().toUtc(),
          split: Expense.splitEqually(amount: amount, memberIds: ids),
          createdBy: userId,
          currency: group.currency,
        );
        _fingerprint = fingerprint;
      }
      await ref.read(expensesRepositoryProvider).saveExpense(_draft!);
      if (!mounted || ref.read(currentUserProvider)?.uid != userId) return;
      ref.read(expensePageIndexProvider(group.id).notifier).state = 0;
      ref.invalidate(expensePageProvider(group.id));
      ref.invalidate(groupBalancesProvider(group.id));
      setState(() => _busy = false);
      // Update PopScope before attempting to leave the completed form.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = financialErrorMessage(error));
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Add Expense')),
        body: group.when(
          data: (group) {
            if (group == null || !group.memberIds.contains(userId)) {
              return const Center(
                  child: Text('Group unavailable. Refresh and try again.'));
            }
            if (!supportedCurrencies.contains(group.currency)) {
              return const Center(
                  child: Text('This currency is not supported yet.'));
            }
            Map<String, double>? shares;
            try {
              shares = Expense.splitEqually(
                amount: Money.fromMinorUnits(Money.parseAmount(_amount.text)),
                memberIds: group.memberIds,
              );
            } on ArgumentError {
              // Incomplete input has no preview; the form explains validation.
            }
            final names = {
              for (final member in group.members)
                member.userId: member.displayName
            };
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _description,
                    enabled: !_busy,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter a description'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    enabled: !_busy,
                    maxLength: 18,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (${group.currency})',
                      hintText: '0.00',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      try {
                        if (Money.parseAmount(value ?? '') > 0) return null;
                      } on ArgumentError {
                        return 'Enter a valid amount with at most two decimal places';
                      }
                      return 'Enter an amount greater than zero';
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                        '$userId:${group.memberIds.join(',')}:$_payer'),
                    value:
                        group.memberIds.contains(_payer) ? _payer : userId,
                    decoration: const InputDecoration(labelText: 'Paid by'),
                    items: group.members
                        .map((member) => DropdownMenuItem(
                              value: member.userId,
                              child: Text(member.userId == userId
                                  ? '${member.displayName} (You)'
                                  : member.displayName),
                            ))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _payer = value),
                  ),
                  const SizedBox(height: 24),
                  Text(
                      'Split equally among all ${group.memberIds.length} members',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text(
                    'Remainder cents are assigned consistently by member ID. '
                    'Custom splits are not available yet.',
                  ),
                  if (shares != null)
                    ...shares.entries.take(10).map((share) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(names[share.key] ?? 'Member'),
                          trailing: Text(
                              '${group.currency} ${Money.formatMinorUnits(Money.toMinorUnits(share.value))}'),
                        )),
                  if (group.memberIds.length > 10)
                    Text('And ${group.memberIds.length - 10} other members. '
                        'The saved expense shows the complete split.'),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => _save(group),
                    child: Text(_busy ? 'Saving…' : 'Save expense'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(financialErrorMessage(error)),
          )),
        ),
      ),
    );
  }
}
