import 'package:flutter/material.dart';

class ScanReceiptScreen extends StatelessWidget {
  final String? groupId;

  const ScanReceiptScreen({super.key, this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: Center(child: Text('Scan Receipt${groupId != null ? ' for $groupId' : ''}')),
    );
  }
}
