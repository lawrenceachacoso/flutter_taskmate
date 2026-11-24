import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/controllers/auth_providers.dart';
import '../controllers/job_controller.dart';
import '../models/job.dart';

/// Statuses that count as finished work.
const _finishedStatuses = {'completed', 'cancelled', 'blocked'};

/// Jobs the user posted or was accepted for.
/// [history] false = still active; true = finished (completed, cancelled, blocked).
class MyJobsScreen extends ConsumerWidget {
  final bool history;

  const MyJobsScreen({required this.history, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myJobsProvider);
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    final title = history ? 'History' : 'Jobs';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myJobsProvider),
          ),
        ],
      ),
      floatingActionButton: history
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/post-job'),
              icon: const Icon(Icons.add),
              label: const Text('Post a job'),
            ),
      body: jobs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load your jobs.${kDebugMode ? ' [$error]' : ''}'),
        ),
        data: (all) {
          final list = all
              .where((j) => _finishedStatuses.contains(j.status) == history)
              .toList();
          if (list.isEmpty) {
            return Center(
              child: Text(history
                  ? 'Finished jobs show up here.'
                  : 'Jobs you post or get accepted for show up here.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final job = list[i];
              final role =
                  job.posterId == userId ? 'You posted' : 'You are the worker';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(job.title),
                  subtitle: Text(
                      '$role · ${jobStatusLabel(job.status)} · ${job.payLabel}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/jobs/${job.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
