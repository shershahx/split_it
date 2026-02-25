import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/settlement.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../providers/settlements_provider.dart';

class SettleUpScreen extends ConsumerStatefulWidget {
  final String groupId;

  const SettleUpScreen({super.key, required this.groupId});

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  String? _selectedMember;
  final _amountController = TextEditingController();
  double _amount = 0.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final groupAsync = ref.watch(groupProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up'),
        elevation: 0,
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }
          // Exclude current user from the recipient list
          final otherMembers = group.memberIds
              .where((id) => id != currentUser?.uid)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Member selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Who are you settling with?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (otherMembers.isEmpty)
                        const Text(
                          'No other members in this group',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ...otherMembers.map((memberId) => RadioListTile<String>(
                              value: memberId,
                              groupValue: _selectedMember,
                              onChanged: (val) => setState(() => _selectedMember = val),
                              title: Text(memberId),
                              contentPadding: EdgeInsets.zero,
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settlement Amount',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          setState(() {
                            _amount = double.tryParse(value) ?? 0.0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoading || _selectedMember == null || _amount <= 0)
                      ? null
                      : _settleUp,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Record Settlement'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Select a member and enter the amount to settle',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _settleUp() async {
    if (_amount <= 0 || _selectedMember == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final settlement = Settlement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: widget.groupId,
        paidBy: user.uid,
        paidTo: _selectedMember!,
        amount: _amount,
        date: DateTime.now(),
        note: 'Settlement',
      );

      await ref.read(settlementsNotifierProvider.notifier).saveSettlement(settlement);

      // Invalidate settlements cache for this group
      ref.invalidate(settlementsProvider(widget.groupId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settlement of \$${_amount.toStringAsFixed(2)} recorded with $_selectedMember',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record settlement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
