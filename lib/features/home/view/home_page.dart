import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/features/home/bloc/home_bloc.dart';
import 'package:miji/features/home/bloc/home_event.dart';
import 'package:miji/features/home/bloc/home_state.dart';
import 'package:miji/l10n/l10n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        final state = context.read<HomeBloc>().state;
        if (state.hasMore && !state.isLoading) {
          context.read<HomeBloc>().add(LoadTodos(page: state.currentPage + 1));
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.todoHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: AppColors.elevatedButtonStyle,
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        context.read<HomeBloc>().add(AddTodo(_controller.text));
                        _controller.clear();
                      }
                    },
                    child: Text(AppLocalizations.of(context)!.addTodo),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state.isLoading && state.todos.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.error != null) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.error(state.error!),
                        style: AppColors.bodyText,
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: state.todos.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.todos.length && state.hasMore) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Card(
                        child: ListTile(
                          title: Text(
                            state.todos[index],
                            style: AppColors.bodyText,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              context.read<HomeBloc>().add(DeleteTodo(index));
                            },
                            tooltip: AppLocalizations.of(context)!.deleteTodo,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}