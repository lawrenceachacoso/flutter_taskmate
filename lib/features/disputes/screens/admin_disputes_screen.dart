import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../jobs/models/job.dart';
import '../controllers/dispute_controller.dart';
import '../models/dispute.dart';
import '../widgets/dispute_section.dart';
import '../widgets/text_input_dialog.dart';

class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(unresolvedDisputesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('Payment disputes'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(unresolvedDisputesProvider),
          ),
        ],
      ),
      body: disputes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load disputes.${kDebugMode ? ' [$error]' : ''}'),
        ),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No unresolved disputes.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => _DisputeCard(dispute: list[i]),
              ),
      ),
    );
  }
}

class _DisputeCard extends ConsumerWidget {
  final Dispute dispute;

  const _DisputeCard({required this.dispute});

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref, {
    required bool paid,
  }) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => TextInputDialog(
        title: paid ? 'Mark as paid' : 'Uphold non-payment',
        label: paid
            ? 'Note (optional)'
            : 'Note (optional). The poster will be suspended.',
        confirmLabel: paid ? 'Mark paid' : 'Suspend poster',
      ),
    );
    if (note == null || !context.mounted) return;
    await ref
        .read(disputeControllerProvider.notifier)
        .resolve(dispute.id, paid: paid, note: note.isEmpty ? null : note);
    if (!context.mounted) return;
    final state = ref.read(disputeControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError
          ? disputeError(state.error!)
          : (paid ? 'Dispute resolved: paid.' : 'Poster suspended.')),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(disputeControllerProvider).isLoading;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dispute.jobTitle, style: text.titleMedium),
            Text('Amount: ₱${formatPeso(dispute.amount)}'),
            Text('Worker: ${dispute.workerName}'),
            Text('Poster: ${dispute.posterName}'),
            const SizedBox(height: 8),
            Text('Worker says: ${dispute.details ?? '(no details)'}'),
            Text('Poster proof: ${dispute.proof ?? 'none submitted'}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed:
                      busy ? null : () => _resolve(context, ref, paid: true),
                  child: const Text('Proof valid: paid'),
                ),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => _resolve(context, ref, paid: false),
                  child: const Text('No valid proof: suspend poster'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
