import 'package:flutter/material.dart';

/// Print / PDF button widget. Wraps the button with a Tooltip when provided.
class PrintPdfButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool enabled;
  final String? tooltip;

  const PrintPdfButton({
    Key? key,
    this.onPressed,
    this.enabled = true,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      icon: const Icon(Icons.print_rounded),
      label: const Text('Print / PDF'),
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? Colors.blueGrey[600] : Colors.grey[400],
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, preferBelow: false, child: button);
  }
}
