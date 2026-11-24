import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared layout for the pages shown before a user is verified: log in,
/// sign up, email code, ID upload, and problem screens.
///
/// Wide screens: a green brand panel on the left, the form card on the right.
/// Narrow screens: a green header band above the form card.
class AuthPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  /// Small buttons shown above the card, right-aligned (for example Log out).
  final List<Widget> actions;

  const AuthPage({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _FormArea(
      title: title,
      subtitle: subtitle,
      actions: actions,
      child: child,
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(flex: 6, child: form),
              ],
            )
          : SafeArea(
              child: Column(
                children: [
                  const _BrandBar(),
                  Expanded(child: form),
                ],
              ),
            ),
    );
  }
}

class _Logo extends StatelessWidget {
  final double radius;

  const _Logo({required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: sunYellow,
      child: Icon(Icons.school, color: deepGreen, size: radius),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: grassGreen,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Logo(radius: 40),
          const SizedBox(height: 24),
          const Text(
            'TaskMate',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Central Mindanao University',
            style: TextStyle(color: sunYellow, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Container(width: 64, height: 4, color: sunYellow),
          const SizedBox(height: 16),
          Text(
            'A campus task marketplace. Find side jobs, post tasks, and '
            'work with verified people.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: grassGreen,
        border: Border(bottom: BorderSide(color: sunYellow, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          _Logo(radius: 18),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TaskMate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Central Mindanao University',
                style: TextStyle(color: sunYellow, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormArea extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const _FormArea({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (actions.isNotEmpty)
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: text.headlineSmall?.copyWith(
                          color: deepGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!),
                      ],
                      const SizedBox(height: 20),
                      child,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
