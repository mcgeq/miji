import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/features/home/bloc/home_bloc.dart';
import 'package:miji/features/home/bloc/home_event.dart';
import 'package:miji/l10n/l10n.dart';

class TodoItem extends StatelessWidget {
  final int index;
  final String text;

  const TodoItem({super.key, required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: isDarkMode ? AppColors.darkCardColor : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isDarkMode ? 4.0 : 2.0,
        child: ListTile(
          leading: Checkbox(
            value: false,
            onChanged: (val) {},
            activeColor: AppColors.primaryColor,
          ),
          title: Text(
            text,
            style: isDarkMode ? AppColors.darkBodyText : AppColors.bodyText,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: AppColors.primaryColor),
            tooltip: l10n.deleteTodo,
            onPressed: () {
              context.read<HomeBloc>().add(DeleteTodo(index));
            },
          ),
        ),
      ),
    );
  }
}