import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/supabase/supabase_init.dart';
import '../models/dispute.dart';

const maxProofImages = 5;

/// What the dialog returns: some text (may be empty) and the chosen pictures.
class ProofInput {
  final String text;
  final List<ProofImage> images;

  const ProofInput(this.text, this.images);
}

/// Asks for a short text and up to [maxProofImages] pictures. With
/// [requireEvidence] the user must give 5+ characters or at least 1 picture.
class ProofInputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmLabel;
  final bool requireEvidence;

  const ProofInputDialog({
    required this.title,
    required this.label,
    this.confirmLabel = 'OK',
    this.requireEvidence = false,
    super.key,
  });

  @override
  State<ProofInputDialog> createState() => _ProofInputDialogState();
}

class _ProofInputDialogState extends State<ProofInputDialog> {
  final _controller = TextEditingController();
  final _images = <ProofImage>[];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final room = maxProofImages - _images.length;
    if (room <= 0) return;
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    final added = <ProofImage>[];
    for (final file in files.take(room)) {
      added.add(ProofImage(bytes: await file.readAsBytes(), name: file.name));
    }
    if (!mounted) return;
    setState(() {
      _images.addAll(added);
      _error = null;
    });
  }

  void _confirm() {
    final text = _controller.text.trim();
    if (widget.requireEvidence && text.length < 5 && _images.isEmpty) {
      setState(() => _error = 'Write at least 5 characters or add a picture');
      return;
    }
    Navigator.pop(context, ProofInput(text, List.of(_images)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration:
                  InputDecoration(labelText: widget.label, errorText: _error),
              maxLines: 3,
              maxLength: 1000,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _images.length >= maxProofImages ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text('Add pictures (${_images.length}/$maxProofImages)'),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _images.length; i++)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _images[i].bytes,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: -8,
                          top: -8,
                          child: InkWell(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black87,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Temporary links (1 hour) to private proof pictures. Keyed by the paths
/// joined with '|' so the provider key compares equal between rebuilds.
final proofUrlsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, joined) {
  final bucket = supabase.storage.from('dispute-proof');
  return Future.wait(
    joined.split('|').map((path) => bucket.createSignedUrl(path, 3600)),
  );
});

/// Thumbnails of proof pictures; tap one to see it larger.
class ProofGallery extends ConsumerWidget {
  final List<String> paths;

  const ProofGallery({required this.paths, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final urls = ref.watch(proofUrlsProvider(paths.join('|')));

    return urls.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const Text('Could not load the pictures.'),
      data: (list) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final url in list)
              InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(child: Image.network(url)),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 88,
                      height: 88,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
