import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../disputes/widgets/text_input_dialog.dart';
import '../controllers/student_request_controller.dart';
import '../models/student_request.dart';

String _error(Object error) {
  if (error is PostgrestException) return error.message;
  return 'Something went wrong. Please try again.'
      '${kDebugMode ? ' [$error]' : ''}';
}

/// Admin queue of posters asking to be recognised as students.
class AdminStudentRequestsScreen extends ConsumerWidget {
  const AdminStudentRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingStudentRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('Student requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pendingStudentRequestsProvider),
          ),
        ],
      ),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(_error(error))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No student requests waiting.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => _RequestCard(request: list[i]),
              ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final StudentRequest request;

  const _RequestCard({required this.request});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const TextInputDialog(
          title: 'Reject this request?',
          label: 'Reason (shown to the user)',
          confirmLabel: 'Reject',
          minLength: 3,
        ),
      );
      if (reason == null) return;
    }
    await ref
        .read(studentRequestControllerProvider.notifier)
        .review(requestId: request.id, approve: approve, reason: reason);
    if (!context.mounted) return;
    final state = ref.read(studentRequestControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError
          ? _error(state.error!)
          : (approve
              ? '${request.userName} is now a student.'
              : 'Request rejected.')),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(studentRequestControllerProvider).isLoading;
    final doc = ref.watch(studentDocumentProvider(request.documentPath));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.userName,
                style: Theme.of(context).textTheme.titleMedium),
            const Text('Asks to be verified as a student'),
            const SizedBox(height: 12),
            doc.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Could not load the document. ${_error(error)}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (bytes) => ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed:
                      busy ? null : () => _decide(context, ref, approve: true),
                  child: const Text('Approve as student'),
                ),
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
