import 'package:flutter/material.dart';

/// Simulate Send button widget
class SimulateSendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool enabled;

  const SimulateSendButton({Key? key, this.onPressed, this.enabled = true})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.send_rounded),
      label: const Text('Simulate Send'),
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? Colors.green[600] : Colors.grey[400],
      ),
    );
  }
}
