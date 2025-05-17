import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/features/home/bloc/home_bloc.dart';
import 'package:miji/features/home/bloc/home_state.dart';
import 'package:miji/features/home/view/widgets/todo_item.dart';
import 'package:miji/l10n/l10n.dart';
import 'package:miji/shared/error_message.dart';
import 'package:miji/shared/loading_indicator.dart';

class TodoList extends StatelessWidget {
  final ScrollController scrollController;

  const TodoList({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state.isLoading && state.todos.isEmpty) {
          return const Center(child: LoadingIndicator());
        }
        if (state.error != null) {
          return Center(child: ErrorMessage(message: l10n.error(state.error!)));
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: state.todos.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.todos.length && state.hasMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: LoadingIndicator()),
              );
            }
            return TodoItem(index: index, text: state.todos[index]);
          },
        );
      },
    );
  }
}