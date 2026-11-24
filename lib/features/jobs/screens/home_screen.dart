import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/profile_providers.dart';
import '../../ratings/widgets/rating_label.dart';
import '../controllers/job_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(openJobsProvider);
    // Posters (accounts without an @cmu.edu.ph email) can ask to become students.
    final isPoster = ref.watch(currentProfileProvider).value?.role == 'poster';
    // Watched only to keep the controller alive while it signs the user out.
    ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open jobs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(openJobsProvider),
          ),
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/post-job'),
        icon: const Icon(Icons.add),
        label: const Text('Post a job'),
      ),
      body: Column(
        children: [
          if (isPoster)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Are you a CMU student?'),
                subtitle: const Text(
                    'Send your school ID or Certificate of Registration to be verified as a student.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/student-request'),
              ),
            ),
          Expanded(
            child: jobs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load jobs.${kDebugMode ? ' [$error]' : ''}'),
                    TextButton(
                      onPressed: () => ref.invalidate(openJobsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('No open jobs yet. Be the first to post.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final job = list[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(job.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${job.category} · ${job.payLabel}'),
                                Text('${job.location} · by ${job.posterName}'),
                                RatingLabel(userId: job.posterId),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () => context.push('/jobs/${job.id}'),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
