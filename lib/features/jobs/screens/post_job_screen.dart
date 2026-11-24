import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/validators.dart';
import '../controllers/job_controller.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _pay = TextEditingController();
  final _location = TextEditingController();
  String? _category;
  bool _negotiable = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _pay.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final job = await ref.read(postJobControllerProvider.notifier).post(
          title: _title.text,
          description: _description.text,
          category: _category!,
          minPay: double.parse(_pay.text.trim()),
          negotiable: _negotiable,
          location: _location.text,
        );
    if (!mounted) return;
    if (job != null) {
      final message = switch (job.status) {
        'open' => 'Your job was posted.',
        'pending_review' =>
          'Your job was saved and is waiting for admin review. It will '
              'appear in Open jobs once approved.',
        'blocked' =>
          'Your job was blocked: ${job.riskReasons.join('; ')}. See My jobs.',
        _ => 'Your job was saved.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.pop();
    }
  }

  String _errorText(Object error) {
    if (error is PostgrestException) {
      return 'Could not post: ${error.message}';
    }
    return 'Could not post. Check your connection and try again.'
        '${kDebugMode ? ' [$error]' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postJobControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Post a job'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                maxLength: 100,
                validator: validateJobTitle,
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                maxLength: 2000,
                validator: validateJobDescription,
              ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in jobCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (value) => setState(() => _category = value),
                validator: (v) => v == null ? 'Choose a category' : null,
              ),
              TextFormField(
                controller: _pay,
                decoration: const InputDecoration(
                  labelText: 'Minimum pay (₱)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: validateMinPay,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Negotiable'),
                subtitle: const Text('I am willing to negotiate the price'),
                value: _negotiable,
                onChanged: (v) => setState(() => _negotiable = v),
              ),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Meetup location'),
                maxLength: 150,
                validator: validateJobLocation,
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _errorText(state.error!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Post job'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
