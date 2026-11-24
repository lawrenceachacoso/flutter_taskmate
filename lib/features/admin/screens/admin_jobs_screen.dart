import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../disputes/widgets/text_input_dialog.dart';
import '../../jobs/models/job.dart';
import '../controllers/admin_controller.dart';

String _error(Object error) {
  if (error is PostgrestException) return error.message;
  return 'Something went wrong. Please try again.'
      '${kDebugMode ? ' [$error]' : ''}';
}

/// Jobs flagged by the risk scan (or from non-trusted posters) for review.
class AdminJobsScreen extends ConsumerWidget {
  const AdminJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(pendingJobsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('Jobs to review'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pendingJobsProvider),
          ),
        ],
      ),
      body: jobs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(_error(error))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No jobs waiting for review.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => _JobReviewCard(job: list[i]),
              ),
      ),
    );
  }
}

class _JobReviewCard extends ConsumerWidget {
  final Job job;

  const _JobReviewCard({required this.job});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    String? note;
    if (!approve) {
      note = await showDialog<String>(
        context: context,
        builder: (_) => const TextInputDialog(
          title: 'Block this job?',
          label: 'Reason (shown to the poster)',
          confirmLabel: 'Block',
          minLength: 3,
        ),
      );
      if (note == null) return;
    }
    await ref
        .read(adminReviewControllerProvider.notifier)
        .reviewJob(jobId: job.id, approve: approve, note: note);
    if (!context.mounted) return;
    final state = ref.read(adminReviewControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError
          ? _error(state.error!)
          : (approve ? 'Job approved and now open.' : 'Job blocked.')),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(adminReviewControllerProvider).isLoading;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title, style: text.titleMedium),
            Text('${job.category} · ${job.payLabel}'),
            Text('Location: ${job.location}'),
            Text('Poster: ${job.posterName}'),
            const SizedBox(height: 8),
            Text(job.description),
            const SizedBox(height: 8),
            Text(
              job.riskReasons.isEmpty
                  ? 'Risk: ${job.riskLevel}. No keyword flags (poster is not '
                      'trusted yet).'
                  : 'Risk: ${job.riskLevel}. ${job.riskReasons.join('; ')}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed:
                      busy ? null : () => _decide(context, ref, approve: true),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => _decide(context, ref, approve: false),
                  child: const Text('Block'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
