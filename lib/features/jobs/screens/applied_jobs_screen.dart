import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/job_controller.dart';

/// Jobs the signed-in user has applied to, with the result of each.
class AppliedJobsScreen extends ConsumerWidget {
  const AppliedJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(myApplicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applied jobs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myApplicationsProvider),
          ),
        ],
      ),
      body: applications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
              'Could not load your applications.${kDebugMode ? ' [$error]' : ''}'),
        ),
        data: (list) => list.isEmpty
            ? const Center(
                child: Text('Jobs you apply to will show up here.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final a = list[i];
                  final accepted = a.status == 'accepted';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        accepted ? Icons.check_circle : Icons.assignment_outlined,
                        color: accepted ? grassGreen : null,
                      ),
                      title: Text(a.jobTitle.isEmpty ? 'Job' : a.jobTitle),
                      subtitle: Text('Application: ${a.statusLabel}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/jobs/${a.jobId}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
