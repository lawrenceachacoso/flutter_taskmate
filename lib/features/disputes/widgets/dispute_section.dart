import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../jobs/models/job.dart';
import '../controllers/dispute_controller.dart';
import '../models/dispute.dart';
import 'text_input_dialog.dart';

/// How long after completion a worker may report non-payment.
const reportWindowDays = 14;

String disputeError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '23505') return 'You already reported this job.';
    return error.message;
  }
  return 'Something went wrong. Please try again.'
      '${kDebugMode ? ' [$error]' : ''}';
}

String disputeStatusLabel(String status) {
  switch (status) {
    case 'open':
      return 'Reported. Waiting for the poster\'s proof or an admin decision.';
    case 'proof_submitted':
      return 'The poster submitted proof. An admin will decide.';
    case 'resolved_paid':
      return 'Resolved: payment was confirmed by an admin.';
    case 'resolved_unpaid':
      return 'Resolved: non-payment was upheld by an admin.';
    default:
      return status;
  }
}

/// Non-payment report on a completed job. Shown to the poster and the worker.
class DisputeSection extends ConsumerWidget {
  final Job job;
  final bool isOwner;

  const DisputeSection({required this.job, required this.isOwner, super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    await action();
    if (!context.mounted) return;
    final state = ref.read(disputeControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError ? disputeError(state.error!) : done),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispute = ref.watch(jobDisputeProvider(job.id));
    final busy = ref.watch(disputeControllerProvider).isLoading;
    final notifier = ref.read(disputeControllerProvider.notifier);

    return dispute.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Text(disputeError(error)),
      data: (d) {
        if (d == null) return _noDispute(context, ref, busy, notifier);
        return _existing(context, ref, d, busy, notifier);
      },
    );
  }

  Widget _noDispute(BuildContext context, WidgetRef ref, bool busy,
      DisputeController notifier) {
    final done = job.completedAt;
    final open = done != null &&
        DateTime.now().isBefore(done.add(const Duration(days: reportWindowDays)));
    // Only the worker can report, and only within the window.
    if (isOwner || !open) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton(
        onPressed: busy
            ? null
            : () async {
                final details = await showDialog<String>(
                  context: context,
                  builder: (_) => const TextInputDialog(
                    title: 'Report non-payment',
                    label: 'What happened? (optional)',
                    confirmLabel: 'Send report',
                  ),
                );
                if (details == null || !context.mounted) return;
                await _run(
                  context,
                  ref,
                  () => notifier.report(job.id, details.isEmpty ? null : details),
                  'Report sent. An admin will review it.',
                );
              },
        child: const Text('I was not paid in full: report'),
      ),
    );
  }

  Widget _existing(BuildContext context, WidgetRef ref, Dispute d, bool busy,
      DisputeController notifier) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Non-payment report', style: text.titleMedium),
          Text(disputeStatusLabel(d.status)),
          if (d.details != null) Text('Worker: ${d.details}'),
          if (d.proof != null) Text('Poster proof: ${d.proof}'),
          if (d.adminNote != null) Text('Admin note: ${d.adminNote}'),
          if (isOwner && d.status == 'open')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final proof = await showDialog<String>(
                          context: context,
                          builder: (_) => const TextInputDialog(
                            title: 'Submit proof of payment',
                            label: 'Receipt reference or what you can show',
                            confirmLabel: 'Submit proof',
                            minLength: 5,
                          ),
                        );
                        if (proof == null || !context.mounted) return;
                        await _run(
                          context,
                          ref,
                          () => notifier.submitProof(job.id, d.id, proof),
                          'Proof submitted.',
                        );
                      },
                child: const Text('Submit proof of payment'),
              ),
            ),
        ],
      ),
    );
  }
}
