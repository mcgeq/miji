import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/features/home/bloc/home_bloc.dart';
import 'package:miji/features/home/bloc/home_event.dart';
import 'package:miji/features/home/bloc/home_state.dart';
import 'package:miji/l10n/l10n.dart';
import 'package:miji/shared/widgets/clock/index.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearchVisible = false; // Track search box visibility
  final FocusNode _focusNode = FocusNode();

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

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          _isSearchVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode
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
                gradient:
                    !isDarkMode
                        ? LinearGradient(
                          colors: [
                            AppColors.primaryColor.withAlpha(
                              (0.1 * 255).toInt(),
                            ),
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
                  _isSearchVisible
                      ? Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isDarkMode
                                        ? Colors.grey[700]
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        isDarkMode
                                            ? Colors.black.withAlpha(
                                              (0.2 * 255).toInt(),
                                            )
                                            : Colors.grey.withAlpha(
                                              (0.3 * 255).toInt(),
                                            ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                focusNode: _focusNode,
                                controller: _controller,
                                style: TextStyle(
                                  color:
                                      isDarkMode
                                          ? AppColors.darkTextColor
                                          : AppColors.lightTextColor,
                                ),
                                decoration: AppColors.inputDecoration.copyWith(
                                  fillColor:
                                      isDarkMode
                                          ? Colors.grey[700]
                                          : Colors.white,
                                  hintText: l10n.todoHint,
                                  hintStyle: AppColors.bodyText.copyWith(
                                    color:
                                        isDarkMode
                                            ? AppColors.darkTextColor.withAlpha(
                                              (0.7 * 255).toInt(),
                                            )
                                            : AppColors.lightTextColor
                                                .withAlpha((0.7 * 255).toInt()),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.add_task,
                                    color:
                                        isDarkMode
                                            ? AppColors.darkTextColor.withAlpha(
                                              (0.7 * 255).toInt(),
                                            )
                                            : AppColors.primaryColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color:
                                          isDarkMode
                                              ? Colors.grey[600]!
                                              : Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
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
                              gradient:
                                  !isDarkMode
                                      ? LinearGradient(
                                        colors: [
                                          AppColors.primaryColor,
                                          AppColors.primaryColor.withAlpha(
                                            (0.8 * 255).toInt(),
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                      : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      isDarkMode
                                          ? Colors.black.withAlpha(
                                            (0.2 * 255).toInt(),
                                          )
                                          : AppColors.primaryColor.withAlpha(
                                            (0.3 * 255).toInt(),
                                          ),
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
                                shadowColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              onPressed: () {
                                if (_controller.text.isNotEmpty) {
                                  context.read<HomeBloc>().add(
                                    AddTodo(_controller.text),
                                  );
                                  _controller.clear();
                                  setState(() {
                                    _isSearchVisible = false;
                                  });
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
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.add,
                              color:
                                  isDarkMode
                                      ? AppColors.darkTextColor
                                      : AppColors.primaryColor,
                              size: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearchVisible = true; // Show search box
                              });
                              FocusScope.of(context).requestFocus(_focusNode);
                            },
                            tooltip: l10n.addTodo,
                          ),
                          Expanded(
                            child: Center(
                              child: CustomClock(
                                format: 'yyyy年MM月dd日 HH时mm分ss秒',
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                borderRadius: 20,
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white),
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
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
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
                              backgroundColor:
                                  isDarkMode
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
                          const Icon(
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
                              backgroundColor:
                                  isDarkMode
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
                            color: isDarkMode ? AppColors.darkCardColor : null,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  AppColors.cardDecoration.borderRadius!,
                            ),
                            elevation: isDarkMode ? 4.0 : 2.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient:
                                    !isDarkMode
                                        ? const LinearGradient(
                                          colors: [
                                            Colors.white,
                                            AppColors.lightCardColor,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                        : null,
                                borderRadius:
                                    AppColors.cardDecoration.borderRadius!
                                        as BorderRadius,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius:
                                      AppColors.cardDecoration.borderRadius!
                                          as BorderRadius,
                                  splashColor: AppColors.primaryColor.withAlpha(
                                    (0.2 * 255).toInt(),
                                  ),
                                  onTap: () {},
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Checkbox(
                                      value: false,
                                      onChanged: (value) {},
                                      activeColor: AppColors.primaryColor,
                                      checkColor: Colors.white,
                                    ),
                                    title: Text(
                                      state.todos[index],
                                      style:
                                          isDarkMode
                                              ? AppColors.darkBodyText
                                              : AppColors.bodyText,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: AppColors.primaryColor,
                                      ),
                                      onPressed: () {
                                        context.read<HomeBloc>().add(
                                          DeleteTodo(index),
                                        );
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