import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A helper for creating a labeled TextFormField
Widget buildTextField({
  required String label,
  TextEditingController? controller,
  String? initialValue,
  String? hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  Function(String)? onChanged,
  List<TextInputFormatter>? inputFormatters,
  Widget? prefixIcon,
  bool enabled = true,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        initialValue: initialValue,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixIcon,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
      ),
    ],
  );
}

/// A helper for creating a labeled DropdownButtonFormField
Widget buildDropdown<T>({
  required String label,
  required T value,
  required List<T> items,
  required Function(T?) onChanged,
  String Function(T)? displayBuilder,
  double? menuMaxHeight,
  Offset? dropdownOffset,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        menuMaxHeight: menuMaxHeight,
        isExpanded: true,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              displayBuilder != null ? displayBuilder(item) : item.toString(),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

/// A helper widget to create a responsive grid (1 col on mobile, 3 on desktop)
class ResponsiveFieldGrid extends StatelessWidget {
  final List<Widget> children;
  const ResponsiveFieldGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          // Mobile: Single column
          return Column(
            children: children
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: w,
                  ),
                )
                .toList(),
          );
        } else {
          // Desktop: Row
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map(
                  (w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: w,
                    ),
                  ),
                )
                .toList(),
          );
        }
      },
    );
  }
}
