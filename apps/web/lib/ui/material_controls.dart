import 'package:flutter/material.dart';
import 'shared.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;
  final double? itemHeight;
  const AppDropdown({
    super.key,
    this.value,
    required this.items,
    required this.onChanged,
    this.isExpanded = false,
    this.itemHeight = kMinInteractiveDimension,
  });
  @override
  Widget build(BuildContext context) => !isMaterialDesign(context)
      ? DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: isExpanded,
          itemHeight: itemHeight,
        )
      : _MaterialSelector<T>(
          value: value,
          items: items ?? [],
          onChanged: onChanged,
          expanded: isExpanded,
        );
}

class AppDropdownFormField<T> extends StatelessWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;
  final double? itemHeight;
  final InputDecoration decoration;
  final Widget? hint;
  const AppDropdownFormField({
    super.key,
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.isExpanded = false,
    this.itemHeight = kMinInteractiveDimension,
    this.decoration = const InputDecoration(),
    this.hint,
  });
  @override
  Widget build(BuildContext context) => !isMaterialDesign(context)
      ? DropdownButtonFormField<T>(
          initialValue: initialValue,
          items: items,
          onChanged: onChanged,
          isExpanded: isExpanded,
          itemHeight: itemHeight,
          decoration: decoration,
          hint: hint,
        )
      : _MaterialSelector<T>(
          value: initialValue,
          items: items ?? [],
          onChanged: onChanged,
          expanded: isExpanded,
          label: decoration.labelText,
          leading: decoration.prefixIcon,
          hint: hint is Text ? (hint as Text).data : null,
        );
}

class _MaterialSelector<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool expanded;
  final String? label, hint;
  final Widget? leading;
  const _MaterialSelector({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.expanded,
    this.label,
    this.hint,
    this.leading,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: DropdownMenu<T>(
      key: ValueKey(value),
      width: expanded ? null : 220,
      expandedInsets: expanded ? EdgeInsets.zero : null,
      initialSelection: value,
      enabled: onChanged != null,
      requestFocusOnTap: false,
      enableSearch: false,
      menuHeight: 320,
      label: label == null ? null : Text(label!),
      hintText: hint,
      leadingIcon: leading,
      onSelected: onChanged,
      dropdownMenuEntries: [
        for (final item in items)
          DropdownMenuEntry<T>(
            value: item.value as T,
            enabled: item.enabled,
            label: item.child is Text
                ? (item.child as Text).data ?? ''
                : item.value.toString(),
            labelWidget: item.child,
          ),
      ],
    ),
  );
}
