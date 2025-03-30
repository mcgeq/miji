import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mcge_pisces/providers/todo_provider.dart';

class FilterButtons extends StatelessWidget {
  const FilterButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    final currentFilter = todoProvider.filter;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFilterButton(context, '昨', currentFilter),
          const SizedBox(width: 8),
          _buildFilterButton(context, '今', currentFilter),
          const SizedBox(width: 8),
          _buildFilterButton(context, '明', currentFilter),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    String filter,
    String currentFilter,
  ) {
    final theme = Theme.of(context);
    final isSelected = currentFilter == filter;
    return ElevatedButton(
      onPressed: () {
        Provider.of<TodoProvider>(context, listen: false).setFilter(filter);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected
                ? theme
                    .colorScheme
                    .primary // 选中的按钮使用主题色
                : theme.colorScheme.surfaceContainerHighest, // 未选中的按钮使用主题的次级颜色
        foregroundColor:
            isSelected
                ? theme
                    .colorScheme
                    .onPrimary // 选中文字颜色
                : theme.colorScheme.onSurfaceVariant,
      ),
      child: Text(filter),
    );
  }
}
