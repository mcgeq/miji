import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mcge_pisces/providers/todo_provider.dart';

class Pagination extends StatelessWidget {
  const Pagination({super.key});

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    final currentPage = todoProvider.currentPage;
    final totalPages = todoProvider.totalPages;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          context,
          label: '首页',
          onPressed: currentPage > 1 ? () => todoProvider.setPage(1) : null,
        ),
        _buildPageButton(
          context,
          label: '上一页',
          onPressed:
              currentPage > 1
                  ? () => todoProvider.setPage(currentPage - 1)
                  : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$currentPage / $totalPages 页'),
        ),
        _buildPageButton(
          context,
          label: '下一页',
          onPressed:
              currentPage < totalPages
                  ? () => todoProvider.setPage(currentPage + 1)
                  : null,
        ),
        _buildPageButton(
          context,
          label: '末页',
          onPressed:
              currentPage < totalPages
                  ? () => todoProvider.setPage(totalPages)
                  : null,
        ),
      ],
    );
  }

  Widget _buildPageButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        width: 80.0, // 固定宽度
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor:
                onPressed == null
                    ? Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ) // 禁用时颜色变浅
                    : Theme.of(context).colorScheme.primary, // 启用时使用主题色
            backgroundColor:
                onPressed == null
                    ? Theme.of(context).colorScheme.surface.withValues(
                      alpha: 0.5,
                    ) // 禁用时背景色
                    : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1), // 启用时按钮背景色
            padding: const EdgeInsets.symmetric(vertical: 12.0), // 增加按钮内边距
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0), // 设置圆角
            ),
            side: BorderSide(
              color:
                  onPressed == null
                      ? Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.primary,
              width: 2.0,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold, // 加粗字体
            ),
          ),
        ),
      ),
    );
  }
}
