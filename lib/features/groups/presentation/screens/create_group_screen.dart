import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/models/group.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/groups_repository.dart';
import '../../providers/groups_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');
  bool _isLoading = false;
  String _currency = 'USD';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final group = Group(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        createdBy: user.uid,
        createdAt: DateTime.now(),
        memberIds: [user.uid],
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        currency: _currency,
      );

      await ref.read(groupsRepositoryProvider).createGroup(group);

      if (mounted) {
        if (ref.read(currentUserProvider)?.uid != user.uid) return;
        ref.read(groupsPageProvider.notifier).state = 0;
        ref.invalidate(groupsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully')),
        );
        context.pushReplacement(AppRoutes.groupDetail(group.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(groupErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Group'),
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g., Roommates, Trip to Paris',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isLoading,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'What is this group for?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(
                  labelText: 'Group currency',
                  helperText:
                      'All expenses in this group will use this currency.',
                  border: OutlineInputBorder(),
                ),
                items: supportedCurrencies.map((currency) {
                  return DropdownMenuItem(
                      value: currency, child: Text(currency));
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() => _currency = value!),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
