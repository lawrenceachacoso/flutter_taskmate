import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/controllers/profile_providers.dart';
import '../../verification/controllers/id_photo_controller.dart'
    show IdPhotoException;
import '../controllers/student_request_controller.dart';

String _message(Object error) {
  if (error is IdPhotoException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '23505') return 'You already have a pending request.';
    return error.message;
  }
  return 'Something went wrong. Please try again.'
      '${kDebugMode ? ' [$error]' : ''}';
}

/// A poster asks to be recognised as a CMU student by sending a school ID or
/// a Certificate of Registration.
class StudentRequestScreen extends ConsumerWidget {
  const StudentRequestScreen({super.key});

  Future<void> _pickAndSubmit(WidgetRef ref) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await ref
        .read(studentRequestControllerProvider.notifier)
        .submit(bytes: bytes, fileName: file.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final latest = ref.watch(myStudentRequestProvider);
    final action = ref.watch(studentRequestControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/account'),
        title: const Text('Verify as a student'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(myStudentRequestProvider);
              ref.invalidate(currentProfileProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile != null && profile.role == 'student')
              const Text('Your account is verified as a student.')
            else if (profile != null && profile.role != 'poster')
              const Text('This is only for poster accounts.')
            else
              latest.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(_message(error)),
                data: (r) {
                  if (r != null && r.status == 'pending') {
                    return const Text(
                      'Your request was submitted. An administrator will '
                      'review it. Press refresh to see the result.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r != null && r.status == 'rejected') ...[
                        const Text('Your last request was rejected.'),
                        if (r.rejectionReason != null)
                          Text('Reason: ${r.rejectionReason}'),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        'If you are a CMU student but did not use an '
                        '@cmu.edu.ph email, upload a clear photo of your '
                        'school ID or your Certificate of Registration. '
                        'JPG or PNG, up to 5 MB. An administrator will review '
                        'it and, if approved, your account becomes a student '
                        'account.',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: action.isLoading
                            ? null
                            : () => _pickAndSubmit(ref),
                        child: action.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Choose ID or certificate photo'),
                      ),
                    ],
                  );
                },
              ),
            if (action.hasError) ...[
              const SizedBox(height: 16),
              Text(
                _message(action.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
