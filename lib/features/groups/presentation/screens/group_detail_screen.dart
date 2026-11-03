import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../friends/providers/friends_provider.dart';
import '../../../settle/providers/settlements_provider.dart';
import '../../data/groups_repository.dart';
import '../../providers/groups_provider.dart';
import '../widgets/group_finances_section.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

<<<<<<< HEAD
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref.invalidate(groupProvider(groupId));
    ref.invalidate(expensesProvider(groupId));
    ref.invalidate(settlementsProvider(groupId));
    try {
      await Future.wait<Object?>([
        ref.read(groupProvider(groupId).future),
        ref.read(expensesProvider(groupId).future),
        ref.read(settlementsProvider(groupId).future),
      ]);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh group: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final currentUserId = ref.watch(currentUserProvider)?.uid;
=======
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

    return Scaffold(
      appBar: AppBar(title: const Text('Group')),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
<<<<<<< HEAD
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Group not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.groups);
                      }
                    },
                    child: const Text('Go Back'),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(groupProvider(groupId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refresh(context, ref),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  actions: [
                    IconButton(
                      tooltip: 'Refresh group',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _refresh(context, ref),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(group.name),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getAvatarColor(group.name),
                            AppColors.getAvatarColor(group.name)
                                .withValues(alpha: 0.7)
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.group,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.3),
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
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.pushNamed('group-settle',
                                pathParameters: {'groupId': groupId}),
                            icon: const Icon(Icons.handshake_outlined),
                            label: const Text('Settle Up'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Group currency: ${group.currency}'),
                        const SizedBox(height: 16),
                        if (group.description != null) ...[
                          Text(
                            'Description',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        ...group.memberIds.map((memberId) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.getAvatarColor(memberId),
                                child: Text(
                                  memberId.isEmpty
                                      ? '?'
                                      : memberId[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(memberId == currentUserId
                                  ? (memberId == group.createdBy
                                      ? 'You (Creator)'
                                      : 'You')
                                  : (memberId == group.createdBy
                                      ? 'Creator'
                                      : 'Member')),
                              subtitle: Text(memberId),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        _BalancesSection(
                            groupId: groupId,
                            memberIds: group.memberIds,
                            currency: group.currency),
                        const SizedBox(height: 24),
                        Text(
                          'Recent Expenses',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _ExpensesSection(
                            groupId: groupId, currency: group.currency),
                        const SizedBox(height: 24),
                        _SettlementHistory(
                            groupId: groupId, currency: group.currency),
                        const SizedBox(height: 24),
                        Text(
                          'Quick Actions',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
                              // Roles are not exposed by Group; SQL remains authoritative.
                              if (currentUserId == group.createdBy) ...[
                                const Divider(height: 1),
                                ListTile(
                                  leading:
                                      const Icon(Icons.person_add_outlined),
                                  title: const Text('Add Member'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) =>
                                        _AddMemberDialog(groupId: groupId),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
=======
            return const Center(
              child: Text('Group unavailable. You may no longer be a member.'),
            );
          }
          final canInvite = group.members.any(
            (member) => member.userId == userId && member.canInvite,
          );
          return RefreshIndicator(
            onRefresh: () async {
              invalidateGroupFinances(ref, groupId);
              ref.invalidate(groupProvider(groupId));
              await Future.wait([
                ref.read(groupProvider(groupId).future),
                ref.read(expensePageProvider(groupId).future),
                ref.read(settlementPageProvider(groupId).future),
                ref.read(groupBalancesProvider(groupId).future),
              ]).then<void>((_) {}, onError: (Object _, StackTrace __) {});
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(children: [
                    Text(group.name,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text('${group.memberCount} members · ${group.currency}'),
                    if (group.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 12),
                      Text(group.description!),
                    ],
                    const SizedBox(height: 16),
                    GroupFinancesSection(group: group),
                    if (canInvite)
                      FilledButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => _InviteMemberDialog(groupId: groupId),
                        ),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Invite by email'),
                      ),
                    const SizedBox(height: 24),
                    Text('Members',
                        style: Theme.of(context).textTheme.titleLarge),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: group.members.length,
                    itemBuilder: (context, index) {
                      final member = group.members[index];
                      final name = member.displayName;
                      final balances =
                          ref.watch(groupBalancesProvider(groupId));
                      final units = balances.asData?.value[member.userId];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.getAvatarColor(name),
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name.characters.first.toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          member.userId == userId ? '$name (You)' : name,
                        ),
                        subtitle: Text(units == null
                            ? member.role
                            : '${member.role} · ${units < 0 ? 'Owes' : 'Owed'} '
                                '${group.currency} ${Money.formatMinorUnits(units.abs())}'),
                      );
                    },
                  ),
                ),
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
<<<<<<< HEAD
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

class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog({required this.groupId});
  final String groupId;

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  String? _selectedId;
  bool _saving = false;
  String? _error;

  Future<void> _addMember() async {
    if (_saving || _selectedId == null) return;
    final group = ref.read(groupProvider(widget.groupId)).valueOrNull;
    final userId = ref.read(currentUserProvider)?.uid;
    final friends = ref.read(friendsProvider).valueOrNull;
    if (group == null ||
        userId != group.createdBy ||
        friends == null ||
        !friends.any((friend) => friend.id == _selectedId) ||
        group.memberIds.contains(_selectedId)) {
      setState(() =>
          _error = 'Choose an accepted friend who is not already a member.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(groupsNotifierProvider.notifier)
          .addMember(widget.groupId, _selectedId!);
      if (!mounted) return;
      ref.invalidate(groupProvider(widget.groupId));
      ref.invalidate(groupsProvider);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = 'Failed to add member: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final members =
        ref.watch(groupProvider(widget.groupId)).valueOrNull?.memberIds;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Add Member'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose an accepted friend to add to this group.'),
              const SizedBox(height: 16),
              friends.when(
                data: (friends) {
                  final eligible = friends
                      .where((friend) =>
                          friend.id != ref.watch(currentUserProvider)?.uid &&
                          members != null &&
                          !members.contains(friend.id))
                      .toList();
                  if (eligible.isEmpty) {
                    return const Text(
                        'No friends available. Add a friend and wait for acceptance first.');
                  }
                  return DropdownButtonFormField<String>(
                    initialValue:
                        eligible.any((friend) => friend.id == _selectedId)
                            ? _selectedId
                            : null,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Accepted friend'),
                    items: eligible
                        .map((friend) => DropdownMenuItem(
                              value: friend.id,
                              child: Text(friend.friendName,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _selectedId = value),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => _SectionError(
                  message: 'Could not load friends: $error',
                  onRetry: () => ref.invalidate(friendsProvider),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ||
                      _selectedId == null ||
                      friends.isLoading ||
                      friends.hasError
                  ? null
                  : _addMember,
              child: Text(_saving ? 'Adding…' : 'Add')),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(message,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}

class _SettlementHistory extends ConsumerWidget {
  const _SettlementHistory({required this.groupId, required this.currency});
  final String groupId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.uid;
    String label(String id) => id == userId ? 'You' : id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recorded Settlements',
            style: Theme.of(context).textTheme.titleMedium),
        const Text(
            'Payment records only; no money is transferred by this app.'),
        const SizedBox(height: 12),
        ref.watch(settlementsProvider(groupId)).when(
              data: (settlements) {
                if (settlements.isEmpty) {
                  return const Text('No settlements recorded yet');
                }
                final sorted = [...settlements]
                  ..sort((a, b) => b.date.compareTo(a.date));
                return Column(
                    children: sorted
                        .map((settlement) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.handshake_outlined),
                                title: Text(
                                    '${label(settlement.paidBy)} → ${label(settlement.paidTo)}'),
                                subtitle: Text([
                                  DateFormat('MMM d, yyyy')
                                      .format(settlement.date),
                                  if (settlement.note?.isNotEmpty == true)
                                    settlement.note!,
                                ].join(' • ')),
                                trailing: Text(
                                    '${settlement.amount.toStringAsFixed(2)} $currency'),
                              ),
                            ))
                        .toList());
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _SectionError(
                message: 'Could not load settlements: $error',
                onRetry: () => ref.invalidate(settlementsProvider(groupId)),
              ),
            ),
      ],
    );
  }
}

// Expenses section widget
class _ExpensesSection extends ConsumerWidget {
  final String groupId;

  final String currency;

  const _ExpensesSection({required this.groupId, required this.currency});

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
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: Colors.grey[400]),
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

        final recent = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
        return Column(
          children: recent.take(5).map((expense) {
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
                  '${expense.amount.toStringAsFixed(2)} $currency',
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
      error: (error, stack) => _SectionError(
        message: 'Failed to load expenses: $error',
        onRetry: () => ref.invalidate(expensesProvider(groupId)),
      ),
    );
  }
}

// Pairwise obligations preserve who owes whom, including former members.
class _BalancesSection extends ConsumerWidget {
  final String groupId;
  final List<String> memberIds;

  final String currency;

  const _BalancesSection(
      {required this.groupId, required this.memberIds, required this.currency});

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

            final participants = <String>{
              ...memberIds,
              for (final expense in expenses) ...[
                expense.paidBy,
                ...expense.split.keys,
              ],
              for (final settlement in settlements) ...[
                settlement.paidBy,
                settlement.paidTo,
              ],
            }.toList()
              ..sort();
            final debts = <({String from, String to, double amount})>[];
            for (final creditor in participants) {
              final balances = BalanceCalculator.calculateNetBalances(
                currentUserId: creditor,
                expenses: expenses,
                settlements: settlements,
              );
              final debtors = balances.keys.toList()..sort();
              for (final debtor in debtors) {
                final amount = balances[debtor]!;
                // Each pair appears once, from the creditor's perspective.
                if (amount > 0) {
                  debts.add((from: debtor, to: creditor, amount: amount));
                }
              }
            }

            if (debts.isEmpty) {
              return Card(
                color: AppColors.positiveBalance.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: AppColors.positiveBalance),
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
=======
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
              children: [
                Text(groupErrorMessage(error)),
                TextButton(
                  onPressed: () => ref.invalidate(groupProvider(groupId)),
                  child: const Text('Retry'),
                ),
<<<<<<< HEAD
                const Text(
                  'Pairwise balances from expenses and recorded payments. '
                  'Debts are not reassigned to other members.',
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
                        '${debt.amount.toStringAsFixed(2)} $currency',
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
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _SectionError(
            message: 'Could not load balances: $error',
            onRetry: () => ref.invalidate(settlementsProvider(groupId)),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => _SectionError(
        message: 'Could not load balances: $error',
        onRetry: () => ref.invalidate(expensesProvider(groupId)),
=======
              ],
            ),
          ),
        ),
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
      ),
    );
  }
}

class _InviteMemberDialog extends ConsumerStatefulWidget {
  final String groupId;
  const _InviteMemberDialog({required this.groupId});

  @override
  ConsumerState<_InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(groupsRepositoryProvider).inviteMember(
            widget.groupId,
            _controller.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Invitation saved. They can sign in with this email and open '
          'Groups → Group invitations to join. No email is sent.',
        ),
      ));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = groupErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Invite to group'),
          content: TextField(
            controller: _controller,
            enabled: !_busy,
            autofocus: true,
            maxLength: 254,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Email address',
              helperText: 'Use the email they sign in with.',
              errorText: _error,
              errorMaxLines: 4,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Sending…' : 'Save invitation'),
            ),
          ],
        ),
      );
}
