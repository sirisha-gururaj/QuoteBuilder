import 'package:flutter/material.dart';

/// Save Draft button widget
class SaveDraftButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool enabled;

  const SaveDraftButton({Key? key, this.onPressed, this.enabled = true})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.save_alt_rounded),
      label: const Text('Save Draft'),
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
    );
  }
}
