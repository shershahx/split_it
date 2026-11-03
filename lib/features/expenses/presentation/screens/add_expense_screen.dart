import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

<<<<<<< HEAD
=======
import '../../../../core/services/financial_error.dart';
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
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
<<<<<<< HEAD
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _shares = <String, String>{};
  // A retry after a lost response must address the same backend record.
  final _draftId = const Uuid().v4();
  late final String? _draftUserId;
  late final String _draftGroupId;
  bool _draftStale = false;
  bool _isLoading = false;
  bool _saved = false;
  String? _selectedPayer;
  String _splitType = 'equal';

  @override
  void initState() {
    super.initState();
    _draftUserId = ref.read(currentUserProvider)?.uid;
    _draftGroupId = widget.groupId;
    ref.listenManual(currentUserProvider.select((user) => user?.uid), (_, uid) {
      if (uid != _draftUserId && !_draftStale) {
        setState(() => _draftStale = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AddExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupId != _draftGroupId) _draftStale = true;
  }

  bool get _isCurrentDraft =>
      !_draftStale &&
      widget.groupId == _draftGroupId &&
      ref.read(currentUserProvider)?.uid == _draftUserId;
=======
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String? _payer;
  bool _busy = false;
  String? _error;
  Expense? _draft;
  String? _fingerprint;
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

<<<<<<< HEAD
  String? _validateAmount(String? value, {bool allowZero = false}) {
    final minor = Money.tryParseMinor(value ?? '');
    if (minor == null || minor < 0 || (!allowZero && minor == 0)) {
      return allowZero
          ? 'Enter a non-negative amount with at most 2 decimals'
          : 'Enter a positive amount with at most 2 decimals';
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addExpense() async {
    if (_isLoading || _saved || !_isCurrentDraft) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(currentUserProvider);
    final groupAsync = ref.read(groupProvider(widget.groupId));
    final group = groupAsync.asData?.value;
    if (user == null || groupAsync.isLoading || group == null) {
      _showMessage('Sign in and wait for the group to load before saving');
      return;
    }
    if (!group.memberIds.contains(user.uid)) {
      _showMessage('You must be a group member to add an expense');
      return;
    }

    try {
      final amount = Money.parseMinor(_amountController.text);
      final paidBy = _selectedPayer ?? user.uid;
      if (!group.memberIds.contains(paidBy)) {
        throw ArgumentError('Select a current group member as payer');
      }
      final split = _splitType == 'equal'
          ? Money.equalSplitMinor(amount, group.memberIds)
          : {
              for (final id in group.memberIds)
                id: Money.parseMinor(_shares[id] ?? ''),
            };
      Money.validateSplitMinor(
        total: amount,
        split: split,
        memberIds: group.memberIds,
      );
      final expense = Expense(
        id: _draftId,
        groupId: widget.groupId,
        description: _descriptionController.text.trim(),
        amount: Money.toMajor(amount),
        paidBy: paidBy,
        date: DateTime.now(),
        split: split.map((id, cents) => MapEntry(id, Money.toMajor(cents))),
        createdBy: user.uid,
      );
      setState(() => _isLoading = true);
      await ref.read(expensesNotifierProvider.notifier).saveExpense(expense);
      if (!mounted || !_isCurrentDraft) return;
      _saved = true;
      ref.invalidate(expensesProvider(widget.groupId));
      ref.invalidate(allUserExpensesProvider);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupProvider(widget.groupId));
      if (ref.read(currentUserProvider)?.uid != user.uid) return;
      _showMessage('Expense added successfully');
      if (context.canPop()) context.pop();
    } catch (error) {
      if (mounted && _isCurrentDraft) {
        _showMessage('Failed to add expense: $error');
=======
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
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
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
<<<<<<< HEAD
      if (mounted) setState(() => _isLoading = false);
=======
      if (mounted && _busy) setState(() => _busy = false);
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider);

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Add Expense')),
        body: !_isCurrentDraft
            ? const Center(
                child: Text(
                    'Account or group changed. Reopen this form to start a new draft.'))
            : currentUser == null
                ? const Center(child: Text('Sign in to add an expense'))
                : groupAsync.when(
                    skipLoadingOnRefresh: false,
                    data: (group) {
                      if (group == null) {
                        return const Center(child: Text('Group not found'));
                      }
                      final members = group.memberIds;
                      if (members.isEmpty ||
                          members.any((id) => id.trim().isEmpty) ||
                          members.toSet().length != members.length ||
                          !members.contains(currentUser.uid)) {
                        return const Center(
                          child: Text('A valid group membership is required'),
                        );
                      }
                      final payer = _selectedPayer ?? currentUser.uid;
                      final amount =
                          Money.tryParseMinor(_amountController.text);
                      final preview = amount != null && amount >= 0
                          ? Money.equalSplitMinor(amount, members)
                          : <String, int>{};
                      return AbsorbPointer(
                        absorbing: _isLoading || _saved,
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Please enter a description'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _amountController,
                                  decoration: InputDecoration(
                                    labelText: 'Amount',
                                    hintText: '0.00',
                                    suffixText: group.currency,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) => _validateAmount(value),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      members.contains(payer) ? payer : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Paid By',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: members
                                      .map((id) => DropdownMenuItem(
                                            value: id,
                                            child: Text(id == currentUser.uid
                                                ? 'You'
                                                : id),
                                          ))
                                      .toList(),
                                  validator: (value) => members.contains(value)
                                      ? null
                                      : 'Select a current group member',
                                  onChanged: (value) =>
                                      setState(() => _selectedPayer = value),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _splitType,
                                  decoration: const InputDecoration(
                                      labelText: 'Split Type'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'equal',
                                        child: Text('Split Equally')),
                                    DropdownMenuItem(
                                        value: 'custom',
                                        child: Text('Custom Amounts')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      if (value == 'custom') {
                                        for (final id in members) {
                                          _shares.putIfAbsent(
                                              id,
                                              () => Money.formatMinor(
                                                  preview[id] ?? 0));
                                        }
                                      }
                                      _splitType = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                for (final id in members)
                                  if (_splitType == 'equal')
                                    ListTile(
                                      title: Text(
                                          id == currentUser.uid ? 'You' : id),
                                      trailing: Text(
                                          '${Money.formatMinor(preview[id] ?? 0)} ${group.currency}'),
                                    )
                                  else
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: TextFormField(
                                        key: ValueKey('share-$id'),
                                        initialValue: _shares[id] ?? '',
                                        decoration: InputDecoration(
                                          labelText:
                                              'Share: ${id == currentUser.uid ? 'You' : id}',
                                          suffixText: group.currency,
                                          border: const OutlineInputBorder(),
                                        ),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        onChanged: (value) =>
                                            _shares[id] = value,
                                        validator: (value) => _validateAmount(
                                            value,
                                            allowZero: true),
                                      ),
                                    ),
                                if (_splitType == 'custom')
                                  const Text(
                                      'Shares must add up exactly to the expense amount. Enter 0 for members not participating.'),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed:
                                      _isLoading || _saved ? null : _addExpense,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Text('Add Expense'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Unable to load group: $error'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(groupProvider(widget.groupId)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
=======
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
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
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
<<<<<<< HEAD
=======
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                        '$userId:${group.memberIds.join(',')}:$_payer'),
                    initialValue:
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
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
      ),
    );
  }
}
