import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/auth_errors.dart';
import '../../../core/widgets/auth_page.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/profile_providers.dart';
import '../../auth/models/profile.dart';
import '../controllers/id_photo_controller.dart';

/// Shown to users whose account is pending or rejected. It lets them upload
/// an ID photo and tells them where their review stands.
class VerificationStatusScreen extends ConsumerWidget {
  const VerificationStatusScreen({super.key});

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await ref
        .read(idPhotoControllerProvider.notifier)
        .submit(bytes: bytes, fileName: file.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final upload = ref.watch(idPhotoControllerProvider);
    // Watched only to keep the controller alive while it signs the user out.
    ref.watch(authControllerProvider);

    return AuthPage(
      title: 'Account verification',
      actions: [
        TextButton(
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Log out'),
        ),
      ],
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Could not load your account.'),
            TextButton(
              onPressed: () => ref.invalidate(currentProfileProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
        data: (profile) {
          if (profile == null) {
            return const Text('Account not found.');
          }
          return _Content(
            profile: profile,
            upload: upload,
            onPick: () => _pickAndUpload(ref),
            onRefresh: () => ref.invalidate(currentProfileProvider),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final Profile profile;
  final AsyncValue<void> upload;
  final VoidCallback onPick;
  final VoidCallback onRefresh;

  const _Content({
    required this.profile,
    required this.upload,
    required this.onPick,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final rejected = profile.status == 'rejected';
    final needsUpload = rejected || profile.idPhotoPath == null;
    final error = upload.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hi, ${profile.fullName}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (rejected) ...[
          const Text('Your verification was rejected.'),
          if (profile.rejectionReason != null)
            Text('Reason: ${profile.rejectionReason}'),
          const SizedBox(height: 16),
        ],
        if (needsUpload) ...[
          const Text(
            'Upload a clear photo of a valid ID (your school ID if you are '
            'a student). JPG or PNG, up to 5 MB. An administrator will '
            'compare it with your registration details.',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: upload.isLoading ? null : onPick,
            child: upload.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(rejected ? 'Upload a new photo' : 'Choose ID photo'),
          ),
        ] else ...[
          const Text(
            'Your ID photo was submitted. An administrator will review it. '
            'You can use TaskMate once you are verified.',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRefresh,
            child: const Text('Refresh status'),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error is IdPhotoException
                ? error.message
                : friendlyAuthError(error),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
