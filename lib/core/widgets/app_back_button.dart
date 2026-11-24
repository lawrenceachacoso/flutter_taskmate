import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back arrow for app bars. Goes back when there is a previous page; if the
/// page was opened directly (for example after a browser refresh) it goes to
/// [fallback] instead, so the user is never stuck.
class AppBackButton extends StatelessWidget {
  final String fallback;

  const AppBackButton({this.fallback = '/home', super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallback);
        }
      },
    );
  }
}
