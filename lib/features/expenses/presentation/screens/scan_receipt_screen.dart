import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

class ScanReceiptScreen extends StatelessWidget {
  final String? groupId;

  const ScanReceiptScreen({super.key, this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Scanning')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.document_scanner_outlined, size: 64),
              const SizedBox(height: 16),
              Text('Enter your receipt manually',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Automatic receipt scanning is not available in this version. '
                'No photo is captured or uploaded. You can still add the total '
                'and choose how to split it.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => groupId == null
                    ? context.go(AppRoutes.groups)
                    : context.push(AppRoutes.groupAddExpense(groupId!)),
                icon: const Icon(Icons.edit_outlined),
                label: Text(groupId == null ? 'Choose a Group' : 'Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
