import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/controllers/auth_providers.dart';
import '../../disputes/widgets/dispute_section.dart';
import '../../ratings/controllers/rating_controller.dart';
import '../../ratings/widgets/rating_label.dart';
import '../controllers/job_controller.dart';
import '../models/job.dart';

String _actionError(Object error) {
  if (error is PostgrestException) {
    // 23505 = unique violation: the user already applied to this job.
    if (error.code == '23505') return 'You already applied to this job.';
    return error.message;
  }
  return 'Something went wrong. Please try again.'
      '${kDebugMode ? ' [$error]' : ''}';
}

class JobDetailScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailScreen({required this.jobId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobProvider(jobId));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Job details'),
      ),
      body: job.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load this job.${kDebugMode ? ' [$error]' : ''}'),
        ),
        data: (j) {
          if (j == null) {
            return const Center(child: Text('This job is no longer available.'));
          }
          final userId = ref.read(authRepositoryProvider).currentUser?.id;
          final isOwner = j.posterId == userId;
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(j.title, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(j.payLabel, style: text.titleMedium),
              const SizedBox(height: 4),
              Text('Category: ${j.category}'),
              Text('Meetup location: ${j.location}'),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text('Posted by: ${j.posterName}'),
                  RatingLabel(userId: j.posterId),
                ],
              ),
              Text('Status: ${jobStatusLabel(j.status)}'),
              Text('Applicants: ${j.applicantCount}'),
              const Divider(height: 32),
              Text(j.description),
              const Divider(height: 32),
              if ((j.status == 'in_progress' || j.status == 'completed') &&
                  (isOwner || j.workerId == userId))
                _ContactSection(jobId: j.id, isOwner: isOwner),
              if ((j.status == 'in_progress' || j.status == 'completed') &&
                  (isOwner || j.workerId == userId))
                _AmountSection(job: j, isOwner: isOwner),
              if (j.status == 'completed') ...[
                const Text('This job is completed.'),
                if (isOwner || j.workerId == userId)
                  _RatingSection(job: j, isOwner: isOwner),
                if (isOwner || j.workerId == userId)
                  DisputeSection(job: j, isOwner: isOwner),
              ] else if (j.status == 'in_progress' &&
                  j.amountConfirmed &&
                  (isOwner || j.workerId == userId))
                _CompleteSection(job: j, isOwner: isOwner),
              if (isOwner && j.status == 'pending_review')
                const Text(
                    'Waiting for admin review. It will appear in Open jobs once approved.'),
              if (isOwner && j.status == 'blocked')
                Text('This job was blocked.'
                    '${j.riskReasons.isEmpty ? '' : ' ${j.riskReasons.join('; ')}.'}'
                    '${j.reviewNote == null ? '' : ' Admin: ${j.reviewNote}'}'),
              if (isOwner && j.status == 'cancelled')
                const Text('You cancelled this job.'),
              if (isOwner && j.status == 'open') _CancelButton(job: j),
              if (isOwner)
                _ApplicantsSection(job: j)
              else
                _ApplySection(job: j, userId: userId),
            ],
          );
        },
      ),
    );
  }
}

/// Asks for a peso amount that is at least the posted minimum.
class _AmountDialog extends StatefulWidget {
  final String title;
  final double minPay;
  final double initial;

  const _AmountDialog({
    required this.title,
    required this.minPay,
    required this.initial,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: formatPeso(widget.initial));
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ok() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null) {
      setState(() => _error = 'Enter a number');
    } else if (value < widget.minPay) {
      setState(() =>
          _error = 'Cannot be below the minimum (₱${formatPeso(widget.minPay)})');
    } else if (value > 99999999) {
      setState(() => _error = 'Amount is too large');
    } else {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Amount (₱)',
          helperText: 'Minimum: ₱${formatPeso(widget.minPay)}',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _ok, child: const Text('OK')),
      ],
    );
  }
}

/// The agreed amount: poster proposes, worker confirms, then it is locked.
class _AmountSection extends ConsumerWidget {
  final Job job;
  final bool isOwner;

  const _AmountSection({required this.job, required this.isOwner});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    await action();
    if (!context.mounted) return;
    final state = ref.read(jobActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError ? _actionError(state.error!) : done),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(jobActionControllerProvider).isLoading;
    final notifier = ref.read(jobActionControllerProvider.notifier);
    final text = Theme.of(context).textTheme;

    final children = <Widget>[
      Text('Agreed amount: ${job.agreedLabel}', style: text.titleMedium),
    ];

    if (job.amountConfirmed) {
      children.add(const Text('Locked: both sides agreed to this amount.'));
    } else if (isOwner) {
      children.add(const Text('Waiting for the worker to confirm.'));
      children.add(TextButton(
        onPressed: busy
            ? null
            : () async {
                final amount = await showDialog<double>(
                  context: context,
                  builder: (_) => _AmountDialog(
                    title: 'Change amount',
                    minPay: job.minPay,
                    initial: job.agreedAmount ?? job.minPay,
                  ),
                );
                if (amount == null || !context.mounted) return;
                await _run(context, ref,
                    () => notifier.setAmount(job.id, amount), 'Amount updated.');
              },
        child: const Text('Change amount'),
      ));
    } else {
      children.add(const Text(
          'Confirm this amount to start. It cannot be changed after you confirm.'));
      children.add(ElevatedButton(
        onPressed: busy
            ? null
            : () => _run(context, ref, () => notifier.confirmAmount(job.id),
                'Amount confirmed and locked.'),
        child: const Text('Confirm amount'),
      ));
    }
    children.add(const SizedBox(height: 16));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Lets the poster cancel an open job, after a confirmation.
class _CancelButton extends ConsumerWidget {
  final Job job;

  const _CancelButton({required this.job});

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this job?'),
        content: const Text(
            'It will be removed from the open jobs list and all pending '
            'applicants will be rejected. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep job'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel job'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(jobActionControllerProvider.notifier).cancel(job.id);
    if (!context.mounted) return;
    final state = ref.read(jobActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          state.hasError ? _actionError(state.error!) : 'Job cancelled.'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(jobActionControllerProvider).isLoading;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: busy ? null : () => _cancel(context, ref),
          child: const Text('Cancel this job'),
        ),
      ),
    );
  }
}

/// After completion: rate the other person once, within 7 days.
class _RatingSection extends ConsumerStatefulWidget {
  final Job job;
  final bool isOwner;

  const _RatingSection({required this.job, required this.isOwner});

  @override
  ConsumerState<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends ConsumerState<_RatingSection> {
  final _comment = TextEditingController();
  int _stars = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap a star to choose your rating.')),
      );
      return;
    }
    final job = widget.job;
    final rateeId = widget.isOwner ? job.workerId! : job.posterId;
    await ref.read(ratingControllerProvider.notifier).submit(
          jobId: job.id,
          rateeId: rateeId,
          stars: _stars,
          comment: _comment.text,
        );
    if (!mounted) return;
    final state = ref.read(ratingControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError
          ? _actionError(state.error!)
          : 'Thanks! Your rating was saved.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final mine = ref.watch(myRatingProvider(job.id));
    final busy = ref.watch(ratingControllerProvider).isLoading;
    final who = widget.isOwner ? 'the worker' : 'the poster';

    return mine.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(_actionError(error)),
      data: (r) {
        if (r != null) {
          return Text('You rated $who ${'★' * r.stars} (${r.stars}/5).');
        }
        final done = job.completedAt;
        final deadline = done?.add(const Duration(days: 7));
        if (deadline == null || DateTime.now().isAfter(deadline)) {
          return const Text('The 7-day rating window has closed.');
        }
        final daysLeft = deadline.difference(DateTime.now()).inDays + 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text('Rate $who ($daysLeft day(s) left)',
                style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star(s)',
                    icon: Icon(i <= _stars ? Icons.star : Icons.star_border),
                    onPressed: () => setState(() => _stars = i),
                  ),
              ],
            ),
            TextField(
              controller: _comment,
              decoration:
                  const InputDecoration(labelText: 'Comment (optional)'),
              maxLines: 2,
              maxLength: 500,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: busy ? null : _submit,
              child: const Text('Submit rating'),
            ),
          ],
        );
      },
    );
  }
}

/// The other person's contact details, shown after a job is accepted.
class _ContactSection extends ConsumerWidget {
  final String jobId;
  final bool isOwner;

  const _ContactSection({required this.jobId, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(jobContactProvider(jobId));
    final who = isOwner ? 'worker' : 'poster';

    return contact.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Text(_actionError(error)),
      data: (c) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact the $who',
                style: Theme.of(context).textTheme.titleMedium),
            Text(c.fullName),
            SelectableText('Facebook: ${c.facebookUrl ?? 'not provided'}'),
            SelectableText('Phone: ${c.phone ?? 'not provided'}'),
          ],
        ),
      ),
    );
  }
}

/// Shown to the poster and the accepted worker while the job is in progress.
class _CompleteSection extends ConsumerWidget {
  final Job job;
  final bool isOwner;

  const _CompleteSection({required this.job, required this.isOwner});

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    await ref.read(jobActionControllerProvider.notifier).complete(job.id);
    if (!context.mounted) return;
    final state = ref.read(jobActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError
          ? _actionError(state.error!)
          : 'Marked as complete.'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(jobActionControllerProvider).isLoading;
    final mineDone = isOwner ? job.posterDone : job.workerDone;
    final otherDone = isOwner ? job.workerDone : job.posterDone;
    final other = isOwner ? 'the worker' : 'the poster';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (otherDone) Text('Waiting on you: $other already marked it complete.'),
        if (mineDone)
          Text('You marked this complete. Waiting for $other to confirm.')
        else
          ElevatedButton(
            onPressed: busy ? null : () => _complete(context, ref),
            child: const Text('Mark as complete'),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Shown to everyone except the poster.
class _ApplySection extends ConsumerWidget {
  final Job job;
  final String? userId;

  const _ApplySection({required this.job, required this.userId});

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    await ref.read(jobActionControllerProvider.notifier).apply(job.id);
    if (!context.mounted) return;
    final state = ref.read(jobActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError
          ? _actionError(state.error!)
          : 'Application sent. The poster will review it.'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (job.workerId != null && job.workerId == userId) {
      return const Text('You were accepted for this job.');
    }
    final mine = ref.watch(myApplicationProvider(job.id));
    final busy = ref.watch(jobActionControllerProvider).isLoading;

    return mine.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(_actionError(error)),
      data: (app) {
        if (app != null) return Text('Your application: ${app.status}');
        if (job.status != 'open') {
          return const Text('This job is no longer taking applications.');
        }
        return ElevatedButton(
          onPressed: busy ? null : () => _apply(context, ref),
          child: busy
              ? const CircularProgressIndicator()
              : const Text('Apply for this job'),
        );
      },
    );
  }
}

/// Shown only to the poster: who applied, and an Accept button.
class _ApplicantsSection extends ConsumerWidget {
  final Job job;

  const _ApplicantsSection({required this.job});

  Future<void> _accept(
      BuildContext context, WidgetRef ref, String applicationId) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(
        title: 'Agreed amount',
        minPay: job.minPay,
        initial: job.minPay,
      ),
    );
    if (amount == null || !context.mounted) return;
    await ref
        .read(jobActionControllerProvider.notifier)
        .accept(applicationId: applicationId, jobId: job.id, amount: amount);
    if (!context.mounted) return;
    final state = ref.read(jobActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.hasError
          ? _actionError(state.error!)
          : 'Applicant accepted. The job is now in progress.'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(jobApplicationsProvider(job.id));
    final busy = ref.watch(jobActionControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Applicants', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        apps.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(_actionError(error)),
          data: (list) {
            if (list.isEmpty) return const Text('No applicants yet.');
            return Column(
              children: [
                for (final a in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.applicantName),
                    subtitle: Wrap(
                      spacing: 8,
                      children: [
                        Text(a.status),
                        RatingLabel(userId: a.applicantId),
                      ],
                    ),
                    trailing: (job.status == 'open' && a.status == 'pending')
                        ? ElevatedButton(
                            onPressed:
                                busy ? null : () => _accept(context, ref, a.id),
                            child: const Text('Accept'),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
