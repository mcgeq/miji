import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_field_style.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class FormDropdown<T> extends StatefulWidget {
  const FormDropdown({
    super.key,
    required this.entries,
    required this.onSelected,
    this.initialSelection,
    this.label,
    this.leadingIcon,
    this.width,
    this.enabled = true,
    this.menuHeight,
    this.helperText,
    this.enableFilter = false,
    this.popupBorderRadius = 12,
    this.popupElevation = 4,
  });

  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?>? onSelected;
  final T? initialSelection;
  final String? label;
  final Widget? leadingIcon;
  final double? width;
  final bool enabled;
  final double? menuHeight;
  final String? helperText;
  final bool enableFilter;
  final double popupBorderRadius;
  final double popupElevation;

  @override
  State<FormDropdown<T>> createState() => _FormDropdownState<T>();
}

class _FormDropdownState<T> extends State<FormDropdown<T>> {
  static const double _defaultWidth = 180;

  final MenuController _menuController = MenuController();
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocusNode = FocusNode();

  T? _selectedValue;
  bool _isOpen = false;
  String _filterText = '';
  FocusNode? _focusToRestore;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialSelection;
    _filterController.addListener(_handleFilterChanged);
  }

  @override
  void didUpdateWidget(covariant FormDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelection != widget.initialSelection) {
      _selectedValue = widget.initialSelection;
    }
  }

  @override
  void dispose() {
    final restore = _focusToRestore;
    if (restore != null &&
        _filterFocusNode.hasFocus &&
        restore.canRequestFocus) {
      restore.requestFocus();
    }
    _filterController
      ..removeListener(_handleFilterChanged)
      ..dispose();
    _filterFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controls = theme.controlTokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final requestedWidth = widget.width;
        final resolvedWidth = requestedWidth != null && requestedWidth.isFinite
            ? requestedWidth
            : constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _defaultWidth;

        return SizedBox(
          width: resolvedWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: MenuAnchor(
                  controller: _menuController,
                  crossAxisUnconstrained: false,
                  onOpen: _handleMenuOpened,
                  onClose: _handleMenuClosed,
                  alignmentOffset: const Offset(0, 6),
                  style: MenuStyle(
                    minimumSize: WidgetStatePropertyAll(Size(resolvedWidth, 0)),
                    maximumSize: WidgetStatePropertyAll(
                      Size(resolvedWidth, widget.menuHeight ?? 280),
                    ),
                    padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
                    elevation: WidgetStatePropertyAll(widget.popupElevation),
                    backgroundColor: WidgetStatePropertyAll(
                      colorScheme.surfaceContainerLow,
                    ),
                    shadowColor: WidgetStatePropertyAll(
                      colorScheme.shadow.withValues(alpha: 0.14),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          widget.popupBorderRadius,
                        ),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.42,
                          ),
                        ),
                      ),
                    ),
                  ),
                  menuChildren: _menuChildren(context, resolvedWidth),
                  builder: (context, controller, child) {
                    return _DropdownTrigger(
                      label: _selectedEntry?.label ?? widget.label ?? '请选择',
                      leadingIcon: widget.leadingIcon,
                      enabled: widget.enabled,
                      isOpen: _isOpen,
                      isPlaceholder: _selectedEntry == null,
                      height: controls.compactFieldHeight,
                      onTap: () => _toggleMenu(controller),
                    );
                  },
                ),
              ),
              if (widget.helperText != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    widget.helperText!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  DropdownMenuEntry<T>? get _selectedEntry {
    for (final entry in widget.entries) {
      if (entry.value == _selectedValue) {
        return entry;
      }
    }
    return null;
  }

  List<Widget> _menuChildren(BuildContext context, double menuWidth) {
    final filteredEntries = _filteredEntries;
    final contentWidth = (menuWidth - 12).clamp(0, double.infinity).toDouble();
    final maxContentHeight = ((widget.menuHeight ?? 280) - 12)
        .clamp(44, double.infinity)
        .toDouble();
    final children = <Widget>[];

    if (widget.enableFilter) {
      final colorScheme = Theme.of(context).colorScheme;
      children.add(
        SizedBox(
          width: contentWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _filterController,
                focusNode: _filterFocusNode,
                textInputAction: TextInputAction.search,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(letterSpacing: 0),
                decoration: InputDecoration(
                  hintText: '搜索',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  filled: true,
                  fillColor: appFieldFillColor(colorScheme, enabled: true),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(
                      color: appFieldBorderColor(colorScheme, enabled: true),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(
                      color: appFieldBorderColor(colorScheme, enabled: true),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(
                      color: appFieldBorderColor(
                        colorScheme,
                        enabled: true,
                        focused: true,
                      ),
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (filteredEntries.isEmpty) {
      children.add(
        SizedBox(
          width: contentWidth,
          height: 44,
          child: Center(
            child: Text(
              '没有匹配项',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      );
      return [
        SizedBox(
          width: contentWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ];
    }

    children.addAll(
      filteredEntries.map(
        (entry) => SizedBox(
          width: contentWidth,
          child: _DropdownMenuRow<T>(
            entry: entry,
            selected: entry.value == _selectedValue,
            onPressed: entry.enabled ? () => _selectEntry(entry) : null,
          ),
        ),
      ),
    );
    return [
      SizedBox(
        width: contentWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              primary: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    ];
  }

  List<DropdownMenuEntry<T>> get _filteredEntries {
    final filterText = _filterText.trim().toLowerCase();
    if (!widget.enableFilter || filterText.isEmpty) {
      return widget.entries;
    }
    return widget.entries
        .where((entry) => entry.label.toLowerCase().contains(filterText))
        .toList();
  }

  void _toggleMenu(MenuController controller) {
    if (!widget.enabled) {
      return;
    }
    if (controller.isOpen) {
      controller.close();
      return;
    }
    controller.open();
  }

  void _selectEntry(DropdownMenuEntry<T> entry) {
    setState(() => _selectedValue = entry.value);
    widget.onSelected?.call(entry.value);
    _restoreMenuFocus();
    _menuController.close();
  }

  void _handleMenuOpened() {
    setState(() => _isOpen = true);
    if (widget.enableFilter) {
      _focusToRestore = FocusManager.instance.primaryFocus;
      _filterController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _filterFocusNode.requestFocus();
        }
      });
    }
  }

  void _handleMenuClosed() {
    setState(() => _isOpen = false);
    _filterFocusNode.unfocus();
    _restoreMenuFocus();
  }

  void _restoreMenuFocus() {
    final restore = _focusToRestore;
    _focusToRestore = null;
    if (restore == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final current = FocusManager.instance.primaryFocus;
      if (current != null && current != _filterFocusNode) {
        return;
      }
      if (restore.canRequestFocus) {
        restore.requestFocus();
      }
    });
  }

  void _handleFilterChanged() {
    setState(() => _filterText = _filterController.text);
  }
}

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.label,
    required this.leadingIcon,
    required this.enabled,
    required this.isOpen,
    required this.isPlaceholder,
    required this.height,
    required this.onTap,
  });

  final String label;
  final Widget? leadingIcon;
  final bool enabled;
  final bool isOpen;
  final bool isPlaceholder;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final borderColor = isOpen
        ? appFieldBorderColor(colorScheme, enabled: enabled, focused: true)
        : appFieldBorderColor(colorScheme, enabled: enabled);
    final foregroundColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final iconColor = isOpen
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(radius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: appFieldFillColor(colorScheme, enabled: enabled),
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(color: borderColor, width: isOpen ? 1.4 : 1),
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                IconTheme(
                  data: IconThemeData(size: 18, color: iconColor),
                  child: leadingIcon!,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isPlaceholder
                        ? colorScheme.onSurfaceVariant
                        : foregroundColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownMenuRow<T> extends StatelessWidget {
  const _DropdownMenuRow({
    required this.entry,
    required this.selected,
    required this.onPressed,
  });

  final DropdownMenuEntry<T> entry;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MenuItemButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(36)),
          maximumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (selected) {
              return colorScheme.primaryContainer.withValues(alpha: 0.56);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.surfaceContainerHighest;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStatePropertyAll(
            selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
          ),
        ),
        leadingIcon: entry.leadingIcon == null
            ? null
            : IconTheme(
                data: IconThemeData(size: 18, color: colorScheme.primary),
                child: entry.leadingIcon!,
              ),
        trailingIcon: selected
            ? Icon(Icons.check_rounded, size: 17, color: colorScheme.primary)
            : entry.trailingIcon,
        child: DefaultTextStyle.merge(
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: entry.labelWidget ?? Text(entry.label),
        ),
      ),
    );
  }
}
