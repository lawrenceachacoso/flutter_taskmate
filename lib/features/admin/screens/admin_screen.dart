import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/profile.dart';
import '../controllers/admin_controller.dart';

String _adminError(Object error) {
  if (error is PostgrestException) return error.message;
  final detail = kDebugMode ? ' [$error]' : '';
  return 'Something went wrong. Please try again.$detail';
}

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingProfilesProvider);
    // Watched only to keep the controller alive while it signs the user out.
    ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending verifications'),
        actions: [
          IconButton(
            tooltip: 'Student requests',
            icon: const Icon(Icons.school_outlined),
            onPressed: () => context.push('/admin/students'),
          ),
          IconButton(
            tooltip: 'Jobs to review',
            icon: const Icon(Icons.work_outline),
            onPressed: () => context.push('/admin/jobs'),
          ),
          IconButton(
            tooltip: 'Payment disputes',
            icon: const Icon(Icons.gavel),
            onPressed: () => context.push('/admin/disputes'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pendingProfilesProvider),
          ),
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_adminError(error)),
              TextButton(
                onPressed: () => ref.invalidate(pendingProfilesProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (profiles) => profiles.isEmpty
            ? const Center(child: Text('No submissions waiting for review.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length,
                itemBuilder: (_, i) => _PendingCard(profile: profiles[i]),
              ),
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  final Profile profile;

  const _PendingCard({required this.profile});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _RejectDialog(),
      );
      if (reason == null) return; // cancelled
    }
    await ref.read(adminReviewControllerProvider.notifier).review(
          userId: profile.id,
          approve: approve,
          reason: reason,
        );
    if (!context.mounted) return;
    final state = ref.read(adminReviewControllerProvider);
    final message = state.hasError
        ? _adminError(state.error!)
        : (approve
            ? '${profile.fullName} was approved.'
            : '${profile.fullName} was rejected.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(adminReviewControllerProvider).isLoading;
    final photo = ref.watch(idPhotoBytesProvider(profile.idPhotoPath!));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.fullName,
                style: Theme.of(context).textTheme.titleMedium),
            Text('Role: ${profile.role}'),
            const SizedBox(height: 12),
            photo.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Could not load the photo. ${_adminError(error)}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (bytes) => ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed:
                      busy ? null : () => _decide(context, ref, approve: true),
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => _decide(context, ref, approve: false),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject this ID?'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Reason (shown to the user)',
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
