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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
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
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.darkBackgroundColor
          : AppColors.lightBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Gradient Background
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              decoration: BoxDecoration(
                gradient: !isDarkMode
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryColor.withOpacity(0.1),
                          AppColors.lightBackgroundColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDarkMode ? AppColors.darkBackgroundColor : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? Colors.black.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.darkTextColor
                                  : AppColors.lightTextColor,
                            ),
                            decoration: AppColors.inputDecoration.copyWith(
                              fillColor: isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.white,
                              hintText: l10n.todoHint,
                              hintStyle: AppColors.bodyText.copyWith(
                                color: isDarkMode
                                    ? AppColors.darkTextColor.withOpacity(0.7)
                                    : AppColors.lightTextColor.withOpacity(0.7),
                              ),
                              prefixIcon: Icon(
                                Icons.add_task,
                                color: isDarkMode
                                    ? AppColors.darkTextColor.withOpacity(0.7)
                                    : AppColors.primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: !isDarkMode
                              ? LinearGradient(
                                  colors: [
                                    AppColors.primaryColor,
                                    AppColors.primaryColor.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode
                                  ? Colors.black.withOpacity(0.2)
                                  : AppColors.primaryColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: AppColors.elevatedButtonStyle.copyWith(
                            backgroundColor: WidgetStateProperty.all(
                              isDarkMode
                                  ? AppColors.primaryColor
                                  : Colors.transparent,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              Colors.white,
                            ),
                            shadowColor: WidgetStateProperty.all(Colors.transparent),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          onPressed: () {
                            if (_controller.text.isNotEmpty) {
                              context.read<HomeBloc>().add(AddTodo(_controller.text));
                              _controller.clear();
                            }
                          },
                          child: Text(
                            l10n.addTodo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Divider for Visual Separation
            Container(
              height: 1,
              color: isDarkMode
                  ? Colors.grey[700]
                  : Colors.grey[200],
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            // Todo List Section
            Expanded(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state.isLoading && state.todos.isEmpty) {
                    return Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: AppColors.primaryColor,
                              backgroundColor: isDarkMode
                                  ? Colors.grey[600]
                                  : Colors.grey[200],
                              strokeWidth: 4,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state.error != null) {
                    return Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.errorColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.error(state.error!),
                            style: (isDarkMode
                                    ? AppColors.darkBodyText
                                    : AppColors.bodyText)
                                .copyWith(
                              color: AppColors.errorColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.todos.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.todos.length && state.hasMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryColor,
                              backgroundColor: isDarkMode
                                  ? Colors.grey[600]
                                  : Colors.grey[200],
                              strokeWidth: 4,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Card(
                            color: isDarkMode
                                ? AppColors.darkCardColor
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppColors.cardDecoration.borderRadius!,
                            ),
                            elevation: isDarkMode ? 4.0 : 2.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: !isDarkMode
                                    ? LinearGradient(
                                        colors: [
                                          Colors.white,
                                          AppColors.lightCardColor,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                borderRadius: AppColors.cardDecoration.borderRadius! as BorderRadius, // Fixed: Cast to BorderRadius
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: AppColors.cardDecoration.borderRadius! as BorderRadius, // Fixed: Cast to BorderRadius
                                  splashColor: AppColors.primaryColor.withOpacity(0.2),
                                  onTap: () {
                                    // Placeholder for future functionality (e.g., toggle todo)
                                  },
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Checkbox(
                                      value: false, // Placeholder: Assumes HomeState tracks completion
                                      onChanged: (value) {
                                        // Placeholder: Add ToggleTodo event in HomeBloc
                                      },
                                      activeColor: AppColors.primaryColor,
                                      checkColor: Colors.white,
                                    ),
                                    title: Text(
                                      state.todos[index],
                                      style: isDarkMode
                                          ? AppColors.darkBodyText
                                          : AppColors.bodyText,
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: AppColors.primaryColor,
                                      ),
                                      onPressed: () {
                                        context.read<HomeBloc>().add(DeleteTodo(index));
                                      },
                                      tooltip: l10n.deleteTodo,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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