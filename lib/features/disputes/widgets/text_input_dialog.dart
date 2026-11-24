import 'package:flutter/material.dart';

/// A dialog that asks for a short piece of text. Returns the text (trimmed),
/// or null if cancelled. When [minLength] is 0 the text is optional.
class TextInputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmLabel;
  final int minLength;
  final int maxLength;

  const TextInputDialog({
    required this.title,
    required this.label,
    this.confirmLabel = 'OK',
    this.minLength = 0,
    this.maxLength = 1000,
    super.key,
  });

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _controller.text.trim();
    if (text.length < widget.minLength) {
      setState(() => _error = 'Write at least ${widget.minLength} characters');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
        maxLines: 3,
        maxLength: widget.maxLength,
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
