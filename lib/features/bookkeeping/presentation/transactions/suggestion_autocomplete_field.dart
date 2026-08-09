import 'package:flutter/material.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 带历史建议自动完成的输入框：聚焦或输入时展示匹配的历史值，
/// 点击建议项直接填入。无建议时退化为普通 [AppTextField]。
class SuggestionAutocompleteField extends StatelessWidget {
  const SuggestionAutocompleteField({
    super.key,
    required this.controller,
    required this.suggestions,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
    this.textInputAction,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final bool enabled;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return AppTextField(
        controller: controller,
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        enabled: enabled,
        textInputAction: textInputAction,
      );
    }

    return RawAutocomplete<String>(
      textEditingController: controller,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return suggestions;
        }
        return suggestions
            .where((option) => option.toLowerCase().contains(query))
            .toList(growable: false);
      },
      onSelected: (selection) {
        controller.text = selection;
        controller.selection = TextSelection.collapsed(
          offset: selection.length,
        );
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return AppTextField(
              controller: textEditingController,
              focusNode: focusNode,
              labelText: labelText,
              hintText: hintText,
              prefixIcon: prefixIcon,
              enabled: enabled,
              textInputAction: textInputAction,
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 420),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      option,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
