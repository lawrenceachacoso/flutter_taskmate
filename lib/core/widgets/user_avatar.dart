import 'package:flutter/material.dart';
import '../supabase/supabase_init.dart';
import '../theme/app_theme.dart';

/// A round profile picture. Shows the uploaded picture when there is one and
/// the first letter of the name otherwise (also while the picture loads).
class UserAvatar extends StatelessWidget {
  final String name;
  final String? avatarPath;
  final double radius;

  const UserAvatar({
    required this.name,
    this.avatarPath,
    this.radius = 20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final path = avatarPath;
    final url =
        path == null ? null : supabase.storage.from('avatars').getPublicUrl(path);
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: sunYellow,
      foregroundImage: url == null ? null : NetworkImage(url),
      child: Text(
        initial,
        style: TextStyle(
          color: deepGreen,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
