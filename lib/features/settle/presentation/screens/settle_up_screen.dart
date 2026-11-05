import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/financial_error.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/models/group.dart';
import '../../../../shared/models/settlement.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../groups/data/groups_repository.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../providers/settlements_provider.dart';

class SettleUpScreen extends ConsumerStatefulWidget {
  final String groupId;

  const SettleUpScreen({super.key, required this.groupId});

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedMember;
  bool _busy = false;
  Settlement? _pending;
  String? _pendingCurrency;

  // Retain the entire immutable request, including timestamp, after an
  // uncertain response. Editing any input deliberately starts a new operation.
  void _edited() {
    _pending = null;
    _pendingCurrency = null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _amountError(String? value) {
    try {
      if (Money.parseAmount(value?.trim() ?? '') <= 0) {
        return 'Enter an amount greater than zero.';
      }
      return null;
    } on ArgumentError {
      return 'Enter a valid amount with at most two decimal places.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // Keep the auto-disposed mutation notifier alive until the request ends.
    ref.watch(settlementsNotifierProvider);
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Record repayment'),
          automaticallyImplyLeading: !_busy,
        ),
        body: user == null
            ? const Center(child: Text('Please sign in to record a payment.'))
            : groupAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text(financialErrorMessage(error))),
                data: (group) {
                  if (group == null) {
                    return const Center(child: Text('Group not found.'));
                  }
                  if (!group.memberIds.contains(user.uid)) {
                    return const Center(
                        child: Text('You are no longer a group member.'));
                  }
                  if (!supportedCurrencies.contains(group.currency)) {
                    return const Center(
                        child: Text('This currency is not supported yet.'));
                  }
                  final members = group.members
                      .where((member) => member.userId != user.uid)
                      .toList();
                  final selected =
                      members.any((member) => member.userId == _selectedMember)
                          ? _selectedMember
                          : null;
                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(group.name,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        const Text(
                          'This records a payment made outside the app. '
                          'It does not transfer money.',
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          key: ValueKey('${user.uid}:$selected'),
                          initialValue: selected,
                          decoration:
                              const InputDecoration(labelText: 'Paid to'),
                          items: members
                              .map((member) => DropdownMenuItem(
                                    value: member.userId,
                                    child: Text(member.displayName),
                                  ))
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) {
                                  setState(() => _selectedMember = value);
                                  _edited();
                                },
                          validator: (value) => value == null
                              ? 'Select another group member.'
                              : null,
                        ),
                        if (members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('No other members in this group.'),
                          ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _amountController,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: 'Amount (${group.currency})',
                            hintText: '0.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _amountError,
                          onChanged: (_) => _edited(),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _noteController,
                          enabled: !_busy,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Note (optional)'),
                          validator: (value) => (value?.runes.length ?? 0) > 300
                              ? 'Keep the note to 300 characters or fewer.'
                              : null,
                          onChanged: (_) => _edited(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy || members.isEmpty
                              ? null
                              : () => _save(group),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Record payment'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _save(Group group) async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(currentUserProvider);
    if (user == null ||
        !group.memberIds.contains(user.uid) ||
        !group.members.any((member) =>
            member.userId == _selectedMember && member.userId != user.uid)) {
      return;
    }
    // Never retry a draft belonging to another account or currency.
    if (_pending?.paidBy != user.uid || _pendingCurrency != group.currency) {
      _edited();
    }
    final note = _noteController.text.trim();
    final settlement = _pending ??= Settlement(
      id: const Uuid().v4(),
      groupId: widget.groupId,
      paidBy: user.uid,
      paidTo: _selectedMember!,
      amount: Money.fromMinorUnits(
          Money.parseAmount(_amountController.text.trim())),
      date: DateTime.now().toUtc(),
      note: note.isEmpty ? null : note,
    );
    _pendingCurrency = group.currency;
    setState(() => _busy = true);
    try {
      await ref
          .read(settlementsNotifierProvider.notifier)
          .saveSettlement(settlement);
      if (!mounted) return;
      if (ref.read(currentUserProvider)?.uid != settlement.paidBy) {
        throw const FinancialFailure('Your account changed. Please try again.');
      }
      // Enable pop before navigating; the busy PopScope blocks system back.
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(financialErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final groupAsync = ref.watch(groupProvider(widget.groupId));

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Settle Up')),
        body: !_isCurrentDraft
            ? const Center(
                child: Text(
                    'Account or group changed. Reopen this form to start a new draft.'))
            : currentUser == null
                ? const Center(child: Text('Sign in to record a payment'))
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
                            child:
                                Text('A valid group membership is required'));
                      }
                      final recipients =
                          members.where((id) => id != currentUser.uid).toList();
                      if (recipients.isEmpty) {
                        return const Center(
                            child: Text('No other members in this group'));
                      }
                      return AbsorbPointer(
                        absorbing: _isLoading || _saved,
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                    'Record a payment you have already made to another group member. This does not transfer money.'),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      recipients.contains(_selectedMember)
                                          ? _selectedMember
                                          : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Paid To',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: recipients
                                      .map((id) => DropdownMenuItem(
                                          value: id, child: Text(id)))
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _selectedMember = value),
                                  validator: (value) => recipients
                                          .contains(value)
                                      ? null
                                      : 'Select another current group member',
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
                                  validator: (value) {
                                    final amount =
                                        Money.tryParseMinor(value ?? '');
                                    return amount == null || amount <= 0
                                        ? 'Enter a positive amount with at most 2 decimals'
                                        : null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed:
                                      _isLoading || _saved ? null : _settleUp,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Text('Record Settlement'),
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
                    ),
                  ),
      ),
    );
  }
}
