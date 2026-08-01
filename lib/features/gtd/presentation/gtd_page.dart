import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';

class GtdPage extends StatelessWidget {
  const GtdPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppPageFrame(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppPlainPanel(
            child: Text(
              '任务收集、整理、执行和复盘会放在这里。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
