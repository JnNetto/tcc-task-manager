import 'package:flutter/material.dart';

class SyncStatusIndicator extends StatelessWidget {
  final int pendingCount;

  const SyncStatusIndicator({super.key, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0) {
      return const Icon(Icons.cloud_done, size: 20);
    }
    return Chip(
      avatar: const Icon(Icons.sync, size: 16),
      label: Text('$pendingCount pendentes'),
      visualDensity: VisualDensity.compact,
    );
  }
}
